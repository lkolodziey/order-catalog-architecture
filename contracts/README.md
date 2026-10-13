# Índice de contratos

Contratos versionados para a proposta. Endpoints, identidade, ambientes e detalhes de implantação ainda dependem das validações descritas no documento de premissas.

- [OpenAPI — Orders API v1](openapi/orders-v1.yaml): criação idempotente e consulta de pedidos.
- [AsyncAPI — Order Status v1](asyncapi/order-status-v1.yaml): evento assíncrono de mudança de status.

O contrato OpenAPI documenta bearer authentication para produção. A prova local é sintética e não implementa autenticação; consulte [limites da prova](../proof/README.md).
