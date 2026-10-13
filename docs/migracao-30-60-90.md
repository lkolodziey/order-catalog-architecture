# Plano incremental de 30/60/90 dias

## Princípios de execução

- Proteger o canal atual com compatibilidade observável e rollout gradual; sem janela de parada.
- Entregar a primeira melhoria em 30 dias com escopo controlado: idempotência e gravação confiável do evento na fronteira de Pedidos, com rollback testado.
- Adotar expand/contract e evitar dual-write independente. Toda etapa tem critério de saída, evidência e responsável.
- Descoberta de país, residência, identidade e volume acontece desde o início; o segundo país só recebe tráfego quando seus controles estiverem aprovados.

| Período | Entregas | Estratégia de convivência e observabilidade | Critério de saída |
|---|---|---|---|
| Dias 0–10 | Discovery de contrato/consumidores; baseline de latência/erros/itens por pedido; ADRs; schema; pipeline; ambiente e threat model. | Captura de métricas sem PII; testes de contrato da API existente; feature flag/rota de shadow sem efeitos colaterais. | Contratos e consumidores críticos inventariados; SLO e fronteiras confirmados; rollback técnico ensaiado em ambiente. |
| Dias 11–30 | Endpoint compatível com idempotência persistida; pedido + outbox atômicos; testes de falha/retry; dashboard e alertas mínimos. | Canary por cliente/percentual; comparar status/campos/latência com baseline; manter rota antiga para rollback; evitar dupla criação por dual-write. | Critério crítico comprovado; sem duplicidade em retry; erro/latência dentro de limites acordados; suporte e runbook preparados; primeira melhoria liberada sem indisponibilidade. |
| Dias 31–60 | Bulk quote / redução de N+1; snapshot de preço e descrição; worker e Service Bus; notificações piloto a parceiros; API v1 documentada. | Migrar por consumidor; backfill somente após política de dados; outbox lag, DLQ e callback monitorados; reconciliation job e replay com autorização. | SLO de criação e entrega assíncrona atendidos sob carga representativa; parceiros piloto confirmam contrato; rollback sem perda de estado. |
| Dias 61–90 | Expansão para mobile e demais parceiros; preparação do segundo país; testes de failover/residência; escala/custo; automatização de governança. | Expandir por região/tenant com política explícita; testar recuperação e restauração; medir adoção de versões; nenhuma remoção antes do sunset acordado. | Critérios legais/segurança/residência aprovados; capacidade 10× demonstrada em teste; runbooks/plantão/prontidão operacional aprovados. |
| ≥ 6 meses de convivência | Descontinuar contrato antigo apenas após migração, comunicação, aceite de negócio e ausência de tráfego confirmado. | Plano de sunset, telemetria, contingência e congelamento de novas dependências antigas. | Donos dos consumidores aprovam; rollback/snapshot de configuração guardado; audit trail completo. |

## Rollback e reversibilidade

- Tráfego roteável por versão/consumidor via APIM e revisão da aplicação; manter release anterior implantado durante janela acordada.
- Feature flags para usar caminho novo de cotação/publicação por coorte; desligar o caminho novo não apaga pedidos já aceitos.
- Mudanças de schema são aditivas primeiro; não renomear/remover colunas ou campos até todos consumidores e deploys terem migrado.
- Migração de dados com checkpoint, idempotência e reconciliação. Restauração de backup só após avaliar RPO e impacto de perder operações recentes.
- DLQ nunca é descartada no rollback; interromper consumo, corrigir e reprocessar com deduplicação.
- Critérios para rollback: violação persistente do SLO, crescimento de erro/duplicidade, divergência de preço/total, aumento de backlog acima do limite acordado ou incidente de segurança.

## Dependências e governança

Sponsor de negócio define semântica de preço/status, dono de cada consumidor confirma compatibilidade, Segurança/Privacidade valida identidade e residência, plataforma disponibiliza landing zone/pipeline, operações aprova SLO e runbooks. Revisão semanal leve por arquitetura, produto, operações e segurança; exceções têm responsável, prazo e plano de saída.
