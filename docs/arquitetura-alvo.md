# Arquitetura-alvo

## Recomendação

Introduzir evolução compatível em torno do domínio de Pedidos. Manter um caminho síncrono curto para aceitar o pedido e retornar sua identidade; mover publicação de status e notificações de parceiros para processamento assíncrono. Persistir pedido, snapshot, registro idempotente e evento de outbox atomicamente. Consultar/validar itens no Catálogo por chamada em lote sempre que suportado; caso não exista esse contrato, introduzir uma operação bulk/quote sem impor dependência de chamada por item.

## Componentes de referência Azure/.NET

| Componente | Responsabilidade | Hipótese tecnológica | Alternativa/gatilho |
|---|---|---|---|
| Clientes web/mobile e parceiros | Consumir pedidos e notificações. | OIDC/OAuth2 para apps; credencial B2B e escopos por parceiro a validar. | B2B federation, mTLS e/ou assinatura de webhook conforme capacidades e política. |
| API Management | Entrada de API pública: roteamento, políticas, quotas, observabilidade e evolução de versões. | Azure API Management. | Comparar SKU, latência, disponibilidade regional, custos e política corporativa. |
| API de Pedidos | Validar requisição, chave, autorização, cotação e comandos de domínio. | ASP.NET Core em Azure Container Apps; escala por HTTP/CPU conforme medição. | AKS se houver requisitos de orquestração/rede/controle avançado; App Service se perfil operacional favorecer PaaS web. |
| Banco de Pedidos | Estado do agregado, snapshots, chaves idempotentes e outbox. | Banco relacional gerenciado; Azure SQL ou PostgreSQL ainda em avaliação. | Selecionar por compatibilidade, transação, residência, HA, operação e custo. |
| Worker de outbox | Publicar eventos de domínio gravados com o pedido; atualizar estado de entrega. | Worker .NET em Container Apps, lendo por lote. | Change feed ou mecanismo específico do banco se mais adequado. |
| Barramento | Distribuir status sem sincronizar criação com parceiros. | Azure Service Bus topic/subscriptions; DLQ e sessões apenas se ordenação por entidade for necessária. | Event Hubs para telemetria de alto volume; não indicado como padrão para comandos/notificações do caso sem evidência. |
| Entrega a parceiros | Notificar status, repetir com política e registrar resultado. | Worker por parceiro/webhook assinado ou adaptador por canal. | Polling/API de consulta ou fila privada quando parceiro suportar. |
| Identidade e segredos | Credenciais de workload, segredos e certificados. | Managed Identity, Microsoft Entra ID e Key Vault. | Aprovação e padrões da landing zone corporativa. |
| Observabilidade | SLO, rastreamento, logs, métricas e alertas. | Azure Monitor, Application Insights e Log Analytics, com OpenTelemetry no app. | Integração com plataforma corporativa existente. |
| CI/CD e IaC | Construir, verificar contratos e promover releases. | GitHub Actions ou Azure DevOps; Bicep/Terraform conforme padrão do cliente. | Selecionar por governança e reuso. |

## Fluxo de criação

1. Cliente autenticado envia `POST /v1/orders` com `Idempotency-Key` e identificador de correlação.
2. API Management aplica autenticação/políticas e encaminha ao adaptador compatível.
3. API valida escopo, formato, limites e chave. Se chave já existir com mesmo fingerprint, devolve o resultado original; se o conteúdo divergir, retorna conflito.
4. Serviço obtém uma cotação por lote no Catálogo, com timeout, limite de itens, versão/validade da cotação e snapshot de descrição, preço e moeda.
5. Em uma transação relacional, grava pedido e itens/snapshots, registro idempotente e evento `OrderCreated` na outbox.
6. Retorna `201` (ou resposta idempotente previamente acordada) com `Location` e `orderId`; a meta p95 ≤ 500 ms deve ser medida no limite definido para o SLO.
7. Worker lê a outbox e envia ao Service Bus com `MessageId` estável. Repetição é esperada; consumidores são idempotentes.

## Atualização de status e notificações

O domínio de Pedidos grava a transição e `OrderStatusChanged` na outbox na mesma transação. O publicador envia ao tópico. Uma assinatura separada controla fan-out/retry/DLQ; o adaptador de parceiro entrega webhook assinado e registra tentativas, próxima tentativa, resposta e correlação. Eventos incluem versão de schema, `eventId`, `orderId`, sequência/versão do agregado, instante UTC e estado, sem incluir PII desnecessária. Replay é auditado e limitado.

## Compatibilidade e transição

Colocar adaptadores/facade entre consumidores existentes e o novo domínio; preservar comportamento e payload por pelo menos seis meses, adicionar campos opcionais de forma compatível, medir uso por versão/consumidor e remover rota antiga somente após aprovação e janela acordada. Não fazer dual-write não coordenado entre dois sistemas de registro. Se houver replicação temporária, definir fonte de verdade, reconciliação e critério de convergência.

## Fronteiras de confiança e falhas

- Público → APIM: TLS, identidade forte, validação, proteção contra abuso e correlação.
- APIM → workloads: rede privada conforme landing zone, identidade de workload e autorização de serviço.
- Workload → banco/broker/Key Vault: Managed Identity e menor privilégio; segredos/certificados rotacionáveis.
- Eventos → consumidores: validação de schema, controle de replay, idempotência e DLQ protegida.
- Parceiro → webhook: destino allowlist/egress controlado, assinatura, segredo isolado por parceiro e proteção contra SSRF.
- Região/país: roteamento e armazenamento definidos após decisão legal e arquitetura de residência; não presumir replicação global de dados pessoais.

Ver diagramas-alvo e ADRs para decisões detalhadas.
