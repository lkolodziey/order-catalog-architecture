using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;

var builder = WebApplication.CreateBuilder(args);
var dbPath = Environment.GetEnvironmentVariable("ORDERS_DB_PATH")
    ?? Path.Combine(AppContext.BaseDirectory, "orders-proof.db");
var app = builder.Build();
var db = new OrderStore(dbPath);
await db.InitializeAsync();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapPost("/v1/orders", async (HttpRequest httpRequest, CreateOrderRequest? request) =>
{
    var key = httpRequest.Headers["Idempotency-Key"].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(key) || key.Length is < 8 or > 128)
        return Results.BadRequest(new { code = "invalid_idempotency_key", message = "Idempotency-Key must contain 8 to 128 characters." });
    if (request?.Items is null || request.Items.Count == 0 || request.Items.Count > 100)
        return Results.BadRequest(new { code = "invalid_items", message = "Provide between 1 and 100 items." });
    if (request.Items.Any(i => string.IsNullOrWhiteSpace(i.ProductId) || string.IsNullOrWhiteSpace(i.Description)
        || i.Quantity <= 0 || i.UnitPrice < 0 || !IsCurrency(i.Currency)))
        return Results.BadRequest(new { code = "invalid_item", message = "Each item requires product, description, positive quantity, non-negative price and ISO-like currency." });

    // Proof-only principal. Production derives this tenant from a validated identity claim.
    var tenantId = httpRequest.Headers["X-Demo-Tenant"].FirstOrDefault() ?? "synthetic-tenant";
    var result = await db.CreateAsync(tenantId, key, request);
    if (result.Kind == CreateKind.Conflict)
        return Results.Conflict(new { code = "idempotency_key_conflict", message = "The key was already used with a different request body." });

    httpRequest.HttpContext.Response.Headers["Location"] = $"/v1/orders/{result.Order!.OrderId}";
    if (result.Kind == CreateKind.Replay)
    {
        httpRequest.HttpContext.Response.Headers["Idempotent-Replay"] = "true";
        return Results.Ok(result.Order);
    }
    return Results.Created($"/v1/orders/{result.Order!.OrderId}", result.Order);
});

// Legacy-shaped lookup is deliberately kept stable for the compatibility demonstration.
app.MapGet("/v1/orders/{orderId:guid}", async (Guid orderId) =>
{
    var order = await db.GetAsync(orderId);
    return order is null ? Results.NotFound(new { code = "order_not_found" }) : Results.Ok(order);
});

app.Run();

static bool IsCurrency(string value) => value.Length == 3 && value.All(c => c is >= 'A' and <= 'Z');

public sealed record CreateOrderRequest(List<OrderItemInput> Items);
public sealed record OrderItemInput(string ProductId, string Description, int Quantity, decimal UnitPrice, string Currency);
public sealed record OrderItemSnapshot(string ProductId, string Description, int Quantity, decimal UnitPrice, string Currency, decimal LineTotal);
public sealed record OrderResponse(Guid OrderId, string Status, DateTimeOffset CreatedAtUtc, IReadOnlyList<OrderItemSnapshot> Items);
public enum CreateKind { Created, Replay, Conflict }
public sealed record CreateResult(CreateKind Kind, OrderResponse? Order);

public sealed class OrderStore(string path)
{
    private readonly string _connectionString = new SqliteConnectionStringBuilder { DataSource = path, Mode = SqliteOpenMode.ReadWriteCreate }.ToString();
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task InitializeAsync()
    {
        var parent = Path.GetDirectoryName(Path.GetFullPath(path));
        if (!string.IsNullOrEmpty(parent)) Directory.CreateDirectory(parent);
        await using var connection = await OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS orders (
                order_id TEXT PRIMARY KEY,
                response_json TEXT NOT NULL,
                created_at_utc TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS idempotency (
                tenant_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                key_hash TEXT NOT NULL,
                request_fingerprint TEXT NOT NULL,
                order_id TEXT NOT NULL,
                response_json TEXT NOT NULL,
                created_at_utc TEXT NOT NULL,
                PRIMARY KEY (tenant_id, operation, key_hash),
                FOREIGN KEY (order_id) REFERENCES orders(order_id)
            );
            CREATE TABLE IF NOT EXISTS outbox (
                event_id TEXT PRIMARY KEY,
                aggregate_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                schema_version TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at_utc TEXT NOT NULL,
                published_at_utc TEXT NULL
            );
            """;
        await command.ExecuteNonQueryAsync();
    }

    public async Task<CreateResult> CreateAsync(string tenant, string rawKey, CreateOrderRequest request)
    {
        var keyHash = Hash(rawKey);
        var fingerprint = Fingerprint(request);
        await using var connection = await OpenAsync();
        await using var transaction = connection.BeginTransaction(deferred: false);

        await using (var lookup = connection.CreateCommand())
        {
            lookup.Transaction = (SqliteTransaction)transaction;
            lookup.CommandText = "SELECT request_fingerprint, response_json FROM idempotency WHERE tenant_id=$tenant AND operation='create-order' AND key_hash=$key";
            lookup.Parameters.AddWithValue("$tenant", tenant);
            lookup.Parameters.AddWithValue("$key", keyHash);
            await using var reader = await lookup.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                var oldFingerprint = reader.GetString(0);
                var oldResponse = reader.GetString(1);
                await reader.DisposeAsync();
                await transaction.CommitAsync();
                return oldFingerprint == fingerprint
                    ? new CreateResult(CreateKind.Replay, JsonSerializer.Deserialize<OrderResponse>(oldResponse, JsonOptions))
                    : new CreateResult(CreateKind.Conflict, null);
            }
        }

        var now = DateTimeOffset.UtcNow;
        var snapshots = request.Items.Select(i => new OrderItemSnapshot(i.ProductId, i.Description.Trim(), i.Quantity,
            decimal.Round(i.UnitPrice, 2, MidpointRounding.ToEven), i.Currency,
            decimal.Round(i.UnitPrice * i.Quantity, 2, MidpointRounding.ToEven))).ToArray();
        var order = new OrderResponse(Guid.NewGuid(), "Accepted", now, snapshots);
        var json = JsonSerializer.Serialize(order, JsonOptions);
        var eventId = Guid.NewGuid();
        var eventJson = JsonSerializer.Serialize(new
        {
            eventId,
            schemaVersion = "1.0",
            orderId = order.OrderId,
            status = order.Status,
            occurredAtUtc = now,
            sequence = 1
        }, JsonOptions);

        await using (var insertOrder = connection.CreateCommand())
        {
            insertOrder.Transaction = (SqliteTransaction)transaction;
            insertOrder.CommandText = "INSERT INTO orders(order_id,response_json,created_at_utc) VALUES($id,$json,$created)";
            insertOrder.Parameters.AddWithValue("$id", order.OrderId.ToString());
            insertOrder.Parameters.AddWithValue("$json", json);
            insertOrder.Parameters.AddWithValue("$created", now.ToString("O"));
            await insertOrder.ExecuteNonQueryAsync();
        }
        await using (var insertKey = connection.CreateCommand())
        {
            insertKey.Transaction = (SqliteTransaction)transaction;
            insertKey.CommandText = "INSERT INTO idempotency(tenant_id,operation,key_hash,request_fingerprint,order_id,response_json,created_at_utc) VALUES($tenant,'create-order',$key,$fingerprint,$id,$json,$created)";
            insertKey.Parameters.AddWithValue("$tenant", tenant);
            insertKey.Parameters.AddWithValue("$key", keyHash);
            insertKey.Parameters.AddWithValue("$fingerprint", fingerprint);
            insertKey.Parameters.AddWithValue("$id", order.OrderId.ToString());
            insertKey.Parameters.AddWithValue("$json", json);
            insertKey.Parameters.AddWithValue("$created", now.ToString("O"));
            await insertKey.ExecuteNonQueryAsync();
        }
        await using (var insertEvent = connection.CreateCommand())
        {
            insertEvent.Transaction = (SqliteTransaction)transaction;
            insertEvent.CommandText = "INSERT INTO outbox(event_id,aggregate_id,event_type,schema_version,payload_json,created_at_utc) VALUES($event,$aggregate,'OrderCreated','1.0',$payload,$created)";
            insertEvent.Parameters.AddWithValue("$event", eventId.ToString());
            insertEvent.Parameters.AddWithValue("$aggregate", order.OrderId.ToString());
            insertEvent.Parameters.AddWithValue("$payload", eventJson);
            insertEvent.Parameters.AddWithValue("$created", now.ToString("O"));
            await insertEvent.ExecuteNonQueryAsync();
        }
        await transaction.CommitAsync();
        return new CreateResult(CreateKind.Created, order);
    }

    public async Task<OrderResponse?> GetAsync(Guid orderId)
    {
        await using var connection = await OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT response_json FROM orders WHERE order_id=$id";
        command.Parameters.AddWithValue("$id", orderId.ToString());
        var json = await command.ExecuteScalarAsync() as string;
        return json is null ? null : JsonSerializer.Deserialize<OrderResponse>(json, JsonOptions);
    }

    private async Task<SqliteConnection> OpenAsync()
    {
        var connection = new SqliteConnection(_connectionString);
        await connection.OpenAsync();
        return connection;
    }

    private static string Hash(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text)));

    private static string Fingerprint(CreateOrderRequest request)
    {
        var canonical = request.Items
            .Select(i => new { productId = i.ProductId.Trim(), description = i.Description.Trim(), quantity = i.Quantity,
                unitPrice = decimal.Round(i.UnitPrice, 2, MidpointRounding.ToEven), currency = i.Currency })
            .OrderBy(i => i.productId, StringComparer.Ordinal)
            .ThenBy(i => i.description, StringComparer.Ordinal)
            .ThenBy(i => i.quantity)
            .ToArray();
        return Hash(JsonSerializer.Serialize(canonical, JsonOptions));
    }
}
