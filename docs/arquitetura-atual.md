# Arquitetura atual (inferida do enunciado)

> O desafio descreve sintomas, não fornece inventário, código, diagrama nem contrato atual. Este documento representa apenas um modelo de trabalho a validar.

## Modelo inferido

O canal web chama a capacidade de Pedidos. Durante a criação, Pedidos consulta Catálogo sincronamente para cada item e persiste o pedido sem copiar preço/descrição. Retries do cliente não têm chave idempotente. A publicação de eventos de pedido ocorre separadamente da gravação; logo uma falha entre gravação e publicação pode perder a notificação, e uma repetição pode publicar duplicado. Consumidores atuais estão acoplados aos contratos existentes.

Ver [C4 de contexto](../diagrams/c4-contexto-atual.mmd) e [C4 de contêineres](../diagrams/c4-conteineres-atual.mmd).

## Sintomas, causa provável e efeito

| Sintoma | Causa indicada | Impacto potencial | Evidência a coletar |
|---|---|---|---|
| Latência cresce com itens | Uma chamada síncrona ao Catálogo por item (N+1). | Cauda de latência, dependência de disponibilidade do Catálogo, custo de conexão. | Traços distribuídos por pedido, quantidade de chamadas, latência por dependência, tamanho do pedido. |
| Auditoria não reproduz preço aceito | Pedido não guarda snapshot. | Contestação, reembolso e cálculo histórico ambíguos após alteração do catálogo. | Amostra de pedidos, política comercial, fonte de preço e moeda. |
| Pedido duplicado sob timeout/retry | Não há chave idempotente. | Cobrança/atendimento duplicado e inconsistência com sistemas downstream. | Logs de retries, IDs correlacionáveis e taxa de duplicidade. |
| Status ausente ou duplicado | Publicação não é transacional e consumidores podem repetir. | Parceiro exibe estado desatualizado; reconciliação manual. | Comparar gravações de status, mensagens e confirmação do consumidor. |
| Crescimento aumenta risco de indisponibilidade | Sincronismo e acoplamento ampliam propagação de falhas. | Saturação em cascata durante picos ou degradação do Catálogo. | Testes de carga, limites de pool, timeouts e circuitos existentes. |

## Pontos de falha do fluxo atual inferido

1. Canal ou rede expira depois do commit: sem idempotência, o retry pode duplicar.
2. Catálogo fica lento ou indisponível: requisições de criação acumulam ou falham.
3. Falha após salvar pedido e antes de publicar evento: o pedido existe sem evento.
4. Evento é enviado, mas o processo falha antes de registrar o envio: possível duplicata no retry.
5. Contrato muda sem inventário de consumidores: quebra silenciosa de canal ou parceiro.

## Ações de descoberta

Capturar contratos e exemplos anonimizados/sintéticos, traçar criação de ponta a ponta, medir distribuição de itens por pedido, estabelecer mapa de consumidores e confirmar semântica de preço/status. Nenhuma mudança de produção deve depender da hipótese de que esse modelo descreve todo o sistema.
