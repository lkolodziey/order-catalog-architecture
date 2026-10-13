# Atributos de qualidade e operação

## SLOs propostos para validação

Valores provenientes do desafio são marcados como meta do enunciado; metas adicionais são propostas e dependem de acordo e baseline. A medição precisa definir janela, exclusões e ponto de observação.

| Atributo | Cenário / indicador | Meta ou critério de aceite | Mecanismo e evidência |
|---|---|---|---|
| Disponibilidade | Criação/consulta de pedido bem-sucedida para requisições válidas. | 99,9% mensal (meta do enunciado; definir se por endpoint/canal e exclusões). | Health/readiness, escala, HA de dependências, alarmes de orçamento de erro e teste de failover. |
| Performance | p95 de criação, do recebimento na borda até resposta aceita. | ≤ 500 ms (meta do enunciado); reportar também p50/p99 e separar tempo de Catálogo. | Bulk quote, chamada curta, pool/limites, traços distribuídos e carga com mix realista. |
| Escalabilidade | Tráfego de pico representativo 10× baseline. | Sem violar p95/SLO nem crescer erro/backlog sem recuperação; workload, ramp-up e duração a acordar. | Teste de carga, autoscaling, limites de conexão/concorrência, capacity plan e custo por 1.000 pedidos. |
| Integridade | Retry e concorrência na mesma chave. | Uma única ordem e mesmo resultado para payload igual; conflito para payload diferente; zero duplicidade na suíte. | Constraint única + transação; testes concorrentes, injeção de timeout e consulta persistida. |
| Auditabilidade | Preço e descrição aceitos permanecem verificáveis. | 100% dos novos pedidos guardam snapshot, moeda e referência de cotação válida conforme regra de negócio. | Snapshot imutável, trilha de transições, acesso auditado e teste de alteração posterior do Catálogo. |
| Entrega de eventos | Transição confirmada alcança broker e consumidores monitorados. | Sem perda lógica; atraso p95 e idade máxima da outbox/DLQ definidos com negócio antes do rollout. | Outbox, MessageId estável, consumidor idempotente, DLQ, replay e reconciliação. |
| Segurança | Acesso não autorizado, abuso de parceiro e exposição de PII. | 100% rotas protegidas e escopadas; zero segredo/PII sensível em logs; exceções aprovadas. | OAuth/OIDC, RBAC/scopes, quotas, validação, Managed Identity, Key Vault e threat modeling. |
| Recuperação | Falha regional ou corrupção de dados. | RTO/RPO a definir; restauração e failover demonstrados em exercício antes de produção multi-país. | Backups, geo estratégia sob análise legal, runbook e simulado. |

## Resiliência por dependência

- **Timeout:** deadline fim a fim e budgets por dependência; nunca esperar indefinidamente pelo Catálogo, broker ou parceiro.
- **Retry:** somente em falhas transitórias e operações idempotentes; exponential backoff com jitter, limite e deadline; não multiplicar retries em cliente, gateway e serviço sem orçamento coordenado.
- **Circuit breaker:** isolar falhas persistentes de Catálogo/parceiros; half-open gradual e métricas de transição.
- **Bulkhead:** limitar concorrência/pool por dependência/tenant para que um parceiro lento não consuma todos os recursos.
- **Degradação controlada:** notificações assíncronas ficam pendentes enquanto indisponíveis; criação de pedido só degrada Catálogo se política de preço/validade permitir explicitamente. Sem essa regra, falha fechada na cotação.
- **Fila/DLQ:** retries limitados e DLQ para mensagens não processadas; alertar idade/volume, runbook de inspeção e replay idempotente com autorização.

## Telemetria mínima

Métricas: taxa/erro/latência por endpoint e parceiro, 429/401/403, hits de idempotência/conflitos, duração da cotação e número de itens, conexão do banco, outbox pendente/idade, Service Bus active/dead-letter, taxa de entrega e respostas de webhook. Traços correlacionam `traceId`, `orderId` e `eventId`; não usar PII, token ou chave de idempotência como dimensão. Logs estruturados com classificação, retenção e redaction. Alertas devem ter severidade, owner, runbook e ação.

## Riscos, débitos aceitos e fora de escopo

- **Riscos:** sem país/volumes/SLOs detalhados, capacidade/custo e residência não podem ser fechados; contrato do Catálogo pode não suportar quote em lote; entrega externa não garante que parceiro processe exatamente uma vez.
- **Débitos temporários possíveis:** facade compatível e worker simples antes de particionar; revisão com prazo, métrica para identificar limite e plano de remoção.
- **Fora do escopo da prova:** cobrança/pagamento, antifraude, estoque, regras fiscais multi-país, UI/portal real, provisionamento Azure e certificação legal. Devem entrar em descoberta, não ser implicitamente resolvidos pelo desenho.
