# Architecture Decision Records

Este diretório registra decisões propostas para a evolução da plataforma. Cada ADR inclui contexto, alternativas, decisão, consequências e pontos de revisão.

| ADR | Decisão | Estado |
|---|---|---|
| [ADR-001 — Idempotência na criação de pedidos](ADR-001-idempotencia-pedidos.md) | Persistir chave, fingerprint e resultado com constraint única no limite transacional de Pedidos. | Proposto |
| [ADR-002 — Outbox e Service Bus](ADR-002-outbox-e-service-bus.md) | Persistir evento na mesma transação do agregado e publicar de forma assíncrona, tolerando repetição. | Proposto |
| [ADR-003 — Cotação em lote e snapshot](ADR-003-cotacao-e-snapshot.md) | Reduzir N+1 por cotação bulk e guardar snapshot imutável dos valores aceitos. | Proposto |
| [ADR-004 — Versionamento de API pública](ADR-004-versionamento-publico.md) | Evoluir contratos com compatibilidade, telemetria de consumidores e sunset planejado. | Proposto |
| [ADR-005 — Hospedagem em Azure Container Apps](ADR-005-hospedagem-container-apps.md) | Usar Container Apps como baseline para comparação, sem fixar ainda a seleção de produção. | Proposto para comparação |

As decisões dependem das premissas e validações registradas em [premissas e questões abertas](../docs/premissas-e-questoes-abertas.md). “Proposto” indica que a decisão foi preparada para o desafio e ainda requer validação com os donos técnicos e de negócio.
