$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'OrdersProof.csproj'
$runId = [Guid]::NewGuid().ToString('N')
$dbPath = Join-Path ([System.IO.Path]::GetTempPath()) "stefanini-orders-proof-$runId.db"
$port = Get-Random -Minimum 21000 -Maximum 49000
$baseUrl = "http://127.0.0.1:$port"
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) "stefanini-orders-proof-$runId.log"
$env:ORDERS_DB_PATH = $dbPath
Add-Type -AssemblyName System.Net.Http
$process = $null
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(10)

function Invoke-JsonRequest([string]$Method, [string]$Path, $Body = $null, [string]$Key = '') {
    $message = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), "$script:baseUrl$Path")
    if ($Key) { $message.Headers.Add('Idempotency-Key', $Key) }
    $message.Headers.Add('X-Demo-Tenant', 'synthetic-tenant')
    if ($null -ne $Body) {
        $json = ConvertTo-Json -InputObject $Body -Depth 20 -Compress
        $message.Content = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
    }
    $response = $script:client.SendAsync($message).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $parsed = $null
    if ($content) { $parsed = $content | ConvertFrom-Json }
    return [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $parsed; Headers = $response.Headers; Content = $content }
}

function Assert-That([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
    Write-Host "PASS  $Message" -ForegroundColor Green
}

try {
    & dotnet build $project --configuration Release
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with exit code $LASTEXITCODE" }
    $assemblyPath = Join-Path $PSScriptRoot 'bin\Release\net10.0\OrdersProof.dll'
    if (-not (Test-Path -LiteralPath $assemblyPath)) { throw "Built API assembly was not found: $assemblyPath" }

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'dotnet'
    $start.Arguments = "`"$assemblyPath`" --urls $baseUrl"
    $start.WorkingDirectory = $PSScriptRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        if ($process.HasExited) { throw "API exited early. $($stderrTask.Result) $($stdoutTask.Result)" }
        try {
            $health = Invoke-JsonRequest 'GET' '/health'
            if ($health.Status -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    Assert-That $ready 'API inicia e responde no health endpoint'

    $body = @{ items = @(@{ productId='SKU-100'; description='Teclado sintético'; quantity=2; unitPrice=125.50; currency='BRL' }) }
    $created = Invoke-JsonRequest 'POST' '/v1/orders' $body 'demo-key-00000001'
    Assert-That ($created.Status -eq 201) 'Primeira chamada cria e persiste o pedido'

    $replay = Invoke-JsonRequest 'POST' '/v1/orders' $body 'demo-key-00000001'
    Assert-That ($replay.Status -eq 200 -and $replay.Body.orderId -eq $created.Body.orderId) 'Retry com mesma chave e payload devolve o mesmo pedido'
    Assert-That ($replay.Headers.Contains('Idempotent-Replay')) 'Retry é identificado explicitamente na resposta'

    $changed = @{ items = @(@{ productId='SKU-100'; description='Teclado sintético'; quantity=3; unitPrice=125.50; currency='BRL' }) }
    $conflict = Invoke-JsonRequest 'POST' '/v1/orders' $changed 'demo-key-00000001'
    Assert-That ($conflict.Status -eq 409) 'Reuso da chave com payload diferente é recusado como conflito'

    $missingKey = Invoke-JsonRequest 'POST' '/v1/orders' $body
    Assert-That ($missingKey.Status -eq 400) 'Criação sem Idempotency-Key é recusada'

    $invalid = @{ items = @(@{ productId='SKU-200'; description='Item inválido'; quantity=0; unitPrice=9.99; currency='BRL' }) }
    $badRequest = Invoke-JsonRequest 'POST' '/v1/orders' $invalid 'demo-key-00000002'
    Assert-That ($badRequest.Status -eq 400) 'Quantidade inválida é recusada sem persistência'

    $legacyRead = Invoke-JsonRequest 'GET' "/v1/orders/$($created.Body.orderId)"
    Assert-That ($legacyRead.Status -eq 200 -and $legacyRead.Body.orderId -eq $created.Body.orderId -and $legacyRead.Body.status -eq 'Accepted') 'Consumidor legado continua lendo a forma compatível da API v1'
    Assert-That ($legacyRead.Body.items[0].unitPrice -eq 125.5 -and $legacyRead.Body.items[0].lineTotal -eq 251) 'Snapshot de preço e total fica persistido no pedido'

    Write-Host "`nProva concluída. Banco SQLite de execução: $dbPath"
    Write-Host 'A base é local e sintética; não representa provisionamento Azure nem avaliação de carga de produção.'
}
catch {
    Write-Error $_
    if ($process -and -not $process.HasExited) {
        $stdoutTask.Wait(1000) | Out-Null
        $stderrTask.Wait(1000) | Out-Null
        Write-Host $stdoutTask.Result
        Write-Host $stderrTask.Result
    }
    exit 1
}
finally {
    $client.Dispose()
    if ($process -and -not $process.HasExited) {
        # The script launches the built assembly directly, so this process is the API itself.
        $process.Kill()
        $process.WaitForExit()
    }
    Remove-Item Env:\ORDERS_DB_PATH -ErrorAction SilentlyContinue
}
