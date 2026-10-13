# Prova executável de idempotência e compatibilidade

## O que esta prova valida

- A mesma chave de idempotência e o mesmo payload retornam o mesmo `orderId`.
- A mesma chave com payload diferente recebe HTTP 409.
- Chave ausente e item inválido são rejeitados.
- Pedido, snapshot, registro idempotente e mensagem de outbox são gravados na mesma transação SQLite local.
- O endpoint de consulta `/v1/orders/{orderId}` permanece disponível para o consumidor de referência da API v1.
- O resultado é reproduzível com dados sintéticos em um único comando.

## Pré-requisitos e comando

- .NET SDK 10.x.
- Primeiro restore pode precisar de acesso ao feed NuGet para `Microsoft.Data.Sqlite`.
- PowerShell 7+ recomendado.
- Linux/macOS: Bash, `curl` e `python3`.

```powershell
./run-proof.ps1
```

Em Linux e macOS:

```bash
./run-proof.sh
```

O script Bash compila o projeto Release, inicia a API com banco temporário, executa os mesmos cenários HTTP do script PowerShell e limpa os arquivos temporários ao sair. Para escolher uma porta local, defina `ORDERS_PROOF_PORT` antes de executar.

O script inicia a API numa porta local, roda verificações positivas e negativas, encerra o processo e informa a localização do banco temporário usado. Para executar a API manualmente:

```powershell
$env:ORDERS_DB_PATH = "$PWD/orders-proof.db"
dotnet run --project ./OrdersProof.csproj --urls http://127.0.0.1:5080
```

Exemplo de criação:

```powershell
$body = @{ items = @(@{ productId='SKU-100'; description='Item sintético'; quantity=1; unitPrice=10.00; currency='BRL' }) } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:5080/v1/orders -Headers @{ 'Idempotency-Key'='minha-chave-000001' } -ContentType 'application/json' -Body $body
```

## Limites deliberados

- `X-Demo-Tenant`/tenant sintético não é autenticação; em produção o tenant deve derivar de identidade validada. A prova não habilita APIM, Entra ID, autorização, quotas ou rede privada.
- O endpoint aceita preço sintético recebido para tornar o snapshot demonstrável; produção deve obter preço autoritativo do Catálogo via cotação/validação em lote.
- A outbox é gravada atomicamente, mas esta prova não envia mensagens para Azure Service Bus nem implementa worker/DLQ.
- SQLite prova constraint e transação local; não implica seleção de banco para Azure nem demonstra alta disponibilidade, escala 10×, p95 ou residência.
- Não inclui autenticação, pagamentos, antifraude, estoque, impostos ou lógica multi-país.
- Não promete exatamente-uma-vez ponta a ponta: consumidores precisam de idempotência e reconciliação.

## Estrutura

- `Program.cs`: API mínima ASP.NET Core, tabelas e transação.
- `OrdersProof.csproj`: projeto .NET.
- `run-proof.ps1`: sobe serviço local e executa os cenários.
- `../contracts/`: OpenAPI e schema AsyncAPI fonte.
- `../.github/workflows/verify.yml`: build e execução automatizados no CI.
