# ADR-002: Outbox transacional e publicação assíncrona

- **Status:** Proposto
- **Data:** 2026-10-13
- **Contexto:** Pedido e evento são publicados sem garantia transacional; notificações externas não devem bloquear criação nem ser perdidas silenciosamente.
- **Decisão:** Gravar mudança do agregado e mensagem de outbox na mesma transação local. Worker publica no Azure Service Bus com identificador estável e atualiza o estado. Assumir entrega at-least-once; consumidores aplicam idempotência/inbox. Usar DLQ, métricas de idade/backlog e reconciliação. Sessões só se ordenação por pedido for necessária e aprovada.
- **Alternativas:** (1) Dual-write banco + broker no request: janela de perda/duplicata; (2) transação distribuída: acoplamento/complexidade operacional; (3) polling de parceiro: latência e carga não controladas pelo produtor.
- **Consequências positivas:** Estado de negócio e intenção de publicar são atômicos; desacopla disponibilidade do parceiro.
- **Consequências negativas:** Consistência eventual, operação de worker/outbox, armazenamento/retention e necessidade de consumidor idempotente.
- **Operação:** Backoff com jitter e limites, poison message em DLQ, replay auditado; Service Bus duplicate detection é defesa adicional dentro de janela, não garantia de negócio.
- **Validação:** Falhas entre commit/envio/ack, duplicatas, reinício do worker, backlog e DLQ.
- **Revisitar quando:** Throughput/ordenação, banco/CDC ou plataforma corporativa indicar broker/padrão diferente.
