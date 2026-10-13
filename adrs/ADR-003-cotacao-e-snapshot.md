# ADR-003: Cotação em lote e snapshot no pedido

- **Status:** Proposto
- **Data:** 2026-10-13
- **Contexto:** O sistema consulta Catálogo sincronamente por item (N+1) e não guarda preço/descrição aceitos, prejudicando latência e auditoria.
- **Decisão:** Solicitar uma cotação/validação em lote por pedido, limitada por quantidade e deadline. O serviço de Pedidos não aceita preço autoritativo do cliente. Na transação de criação, guardar snapshot imutável do produto, descrição, preço e moeda retornados, identificador/versão e validade da cotação. Não degradar para preço desatualizado sem política de negócio aprovada.
- **Alternativas:** (1) Uma chamada por item: mantém N+1; (2) cache local sem versão/validade: risco de preço inconsistente; (3) preço assíncrono após aceitar pedido: altera semântica de aceite e pode criar compromisso sem preço.
- **Consequências positivas:** Menos round trips e auditoria do valor aceito; ponto de validação claro.
- **Consequências negativas:** Catálogo precisa oferecer bulk/quote; snapshot aumenta armazenamento; semântica de validade, imposto e moeda exige definição de negócio.
- **Falhas:** Timeout/circuit breaker; retornar erro transitório explícito se não houver cotação confiável; métricas por quantidade e latência.
- **Validação:** Carga com pedidos grandes, mudança posterior do catálogo, expiração/revogação de cotação e arredondamento monetário.
- **Revisitar quando:** Catálogo, preço, estoque ou regras do país alterarem semântica de quote.
