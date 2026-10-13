# Domínios, dados e integração

## Bounded contexts propostos

| Contexto | Responsabilidade e linguagem | Dados sob ownership | Integração |
|---|---|---|---|
| Pedidos | Receber intenção, validar cotação, aceitar pedido, acompanhar ciclo de vida. | Pedido, linhas, snapshot aceito, moeda, transições, chave idempotente e outbox. | API síncrona na criação/consulta; eventos assíncronos após transição. |
| Catálogo/Preço | Publicar produto e oferta/cotação vigente, regras de disponibilidade, moeda e preço. | Produto, descrição atual, preço/oferta e versão/validade da cotação. | API bulk/quote para criação; eventos de alteração se necessários para projeções. |
| Integração de parceiros | Adaptar contrato externo, credenciais, quotas e entrega/acknowledgement. | Registro de parceiro, endpoint e configuração de entrega, tentativa e resultado. | REST pública via APIM; webhook assíncrono; não é fonte do pedido. |
| Identidade/Cliente (a validar) | Identidade, consentimento e atributos mínimos do comprador. | Identificadores e PII conforme classificação e base legal. | Token/claims ou referência pseudonimizada; evitar copiar dados sem necessidade. |

São fronteiras candidatas. Evitar criar microsserviço por tabela: separar deployment quando ownership, escala, autonomia de release, segurança ou falha independente justificar seu custo.

## Modelo mínimo do agregado Pedido

- `OrderId`, `CustomerRef` minimizada, `PartnerId` quando aplicável, `Status`, `CreatedAtUtc`, `Currency`, `QuoteId/Version`.
- Linhas com `ProductId`, descrição aceita, quantidade, preço unitário, moeda e total/tributação conforme regra a validar.
- Snapshot é imutável para auditoria; correções posteriores geram evento/ajuste explícito, não reescrita silenciosa.
- `IdempotencyRecord`: escopo de cliente/parceiro, chave normalizada, fingerprint canônico do pedido, `OrderId`, resposta relevante e datas de criação/expiração.
- `OutboxMessage`: `EventId`, tipo, versão de schema, payload minimizado, agregado/versão, data de criação, tentativas e estado de publicação.
- `DeliveryAttempt` para callback do parceiro: id do evento, parceiro, tentativa, instante, resultado HTTP sanitizado e próxima tentativa.

Retenção de idempotência deve cobrir a maior janela realista de retry/replay e obrigações comerciais; a duração exata é decisão de produto/risco. Não expor chave idempotente em logs em claro.

## Consistência e integração

| Caso | Estilo | Consistência/justificativa | Falhas e controle |
|---|---|---|---|
| Cotar itens na criação | Síncrono inicialmente, uma chamada bulk/quote. | Pedido não deve aceitar preço sem cotação válida; uma resposta evita N+1. | Timeout/circuit breaker; falhar de forma explícita se não for seguro aceitar preço obsoleto. Cache só com validade e política comercial aprovadas. |
| Persistir pedido + snapshot + idempotência + evento | Transação local no banco de Pedidos. | Invariante de atomicidade; sem transação distribuída. | Constraint única para escopo+chave; retry transacional; outbox. |
| Publicar eventos de domínio | Assíncrono. | Desacopla disponibilidade de parceiros da criação; consistência eventual mensurável. | At-least-once, MessageId estável, consumidor idempotente, DLQ e reconciliação. |
| Notificar parceiros | Assíncrono por adaptador. | Parceiro lento/fora do ar não bloqueia pedido nem status interno. | Backoff com jitter, limite/expiração, circuit breaker por parceiro, DLQ e replay auditado. |
| Consultar pedido | Síncrono com paginação/escopo. | Cliente precisa de estado atual e autorização. | Cache opcional para projeções não críticas, nunca vazar entre tenants. |

## Idempotência

A chave pertence a uma operação e principal/tenant; impor unicidade no banco em `(tenantId, operation, keyHash)`. Guardar hash do payload normalizado para detectar reutilização incompatível. A criação e gravação do resultado acontecem na mesma transação. Concorrência por mesma chave é arbitrada pela constraint, e o processo que perde a corrida busca e devolve o resultado vencedor. Não confiar somente em cache distribuído ou memória da instância. Expiração deve ser explícita; não aceitar silenciosamente reutilização enquanto o registro ainda for válido.

## Publicação confiável, deduplicação e reconciliação

Salvar outbox junto com o pedido; worker publica com ID determinístico e marca como publicado depois da confirmação do broker. Se a confirmação se perder, o worker pode reenviar: o broker ajuda na detecção de duplicatas por janela, mas o consumidor deve manter inbox/controle de evento aplicado. A reconciliação compara pedidos/transições elegíveis, eventos pendentes/enviados, DLQ e estado de entrega do parceiro; alertas e replay exigem trilha auditável.

## Evolução de contrato

- APIs `/v1` preservam semântica e consumidores por seis meses ou prazo maior acordado; mudanças aditivas opcionais primeiro.
- Remoção/mudança semântica incompatível requer versão major separada, plano de migração, telemetria por consumidor, aviso e sunset aprovado.
- Webhooks identificam `eventId`, `schemaVersion`, `occurredAt`, `orderId` e sequência; consumidor deve ignorar evento já aplicado e tolerar campos adicionais.
- Schemas são validados no CI e têm testes de consumidor/provedor; não expor erro interno/PII em payload ou resposta.
