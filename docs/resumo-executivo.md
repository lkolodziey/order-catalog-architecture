# Resumo executivo — Evolução da Plataforma de Pedidos e Catálogo

## Recomendação

Evoluir a plataforma em fatias compatíveis, sem interrupção do canal atual. A primeira mudança deve proteger a criação de pedidos com idempotência persistida e registrar a intenção de publicar eventos na mesma transação que confirma o pedido. Depois, reduzir as chamadas N+1 ao Catálogo por meio de cotação em lote e gravar snapshot imutável de preço, descrição e moeda aceitos. Notificações a parceiros devem ser assíncronas, versionadas, monitoradas e tolerantes a repetição.

Como referência tecnológica, propõe-se Azure com APIs e workers em .NET, API Management na borda, Azure Container Apps como opção inicial de hospedagem, banco relacional gerenciado para Pedidos e Service Bus para eventos. São hipóteses de desenho: seleção final de serviços, região, banco e capacidade depende da landing zone, requisitos de residência, volumetria e modelo operacional do cliente.

## Valor e evolução

O desenho endereça os alvos do desafio — tráfego projetado 10×, disponibilidade mensal de 99,9%, p95 de criação até 500 ms, novos canais/parceiros e segundo país em 90 dias — por meio de chamada de cotação em lote, fluxo síncrono curto de aceite, isolamento das notificações e rollout progressivo. Contratos existentes permanecem compatíveis por ao menos seis meses, com telemetria por consumidor, versões explícitas, feature flags/canary e rollback ensaiado.

A primeira fase de 30 dias concentra-se em discovery e baseline, idempotência transacional, publicação confiável via outbox, contratos, testes automatizados, observabilidade e liberação gradual. A prova local em .NET demonstra repetição da mesma chave sem gerar novo pedido, conflito para payload divergente, persistência do snapshot e leitura v1 compatível. Ela é uma fatia executável, não uma medição de escala de produção nem uma integração provisionada com Azure Service Bus.

## Investimento indicativo

Estimativa inicial de 24–28 pessoa-semanas nominais (aproximadamente 5–6 FTE combinados durante quatro semanas), com faixa de planejamento de 30–39 pessoa-semanas incluindo reserva para integração, aprovações e estabilização. Papéis centrais: arquitetura/liderança, dois desenvolvedores .NET, QA/automação, DevOps Azure e participação parcial de segurança, produto, domínio e operações. Refinar após inventário do legado, disponibilidade dos especialistas e validação da landing zone.

Não é responsável fechar custo monetário Azure sem região, SKU, tráfego absoluto, retenção, alta disponibilidade e topologia de rede. Principais vetores são API Management, compute/revisões mínimas, banco/backup, Service Bus, logs/traços e tráfego de rede. A proposta final deve comparar custo por 1.000 pedidos e dimensionar o cenário de pico.

## Riscos e decisões para validação

Os principais riscos são desconhecer o contrato e os consumidores atuais, ausência de cotação em lote no Catálogo, volume absoluto não informado, país/regras de residência ainda não definidos e dependências de rede/segurança da landing zone. Antes do tráfego do segundo país, validar residência, transferência internacional, retenção e recuperação com Segurança, Privacidade e Jurídico. Definir também semântica de preço/impostos, identidade B2B, RTO/RPO, janela de retenção de idempotência e SLO da entrega de eventos.

Próxima decisão recomendada: aprovar o discovery e a primeira fatia de 30 dias, nomear donos dos consumidores e do Catálogo e disponibilizar ambiente/pipeline Azure para spike de identidade, rede, latência e custo. Os critérios de saída, riscos e rollback estão detalhados no plano 30/60/90 dias.
