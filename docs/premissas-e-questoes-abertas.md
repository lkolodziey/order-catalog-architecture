# Premissas e questões abertas

## Fatos fornecidos

| ID | Fato do desafio | Consequência arquitetural |
|---|---|---|
| F1 | Hoje atende o canal web nacional; em 90 dias deve atender mobile, marketplaces e um segundo país. | Interfaces devem suportar clientes distintos; internacionalização e residência devem ser tratadas como decisões, não suposições. |
| F2 | Volume projetado é 10×. | A solução precisa medir e escalar os gargalos; o fator não define volume absoluto nem distribuição de picos. |
| F3 | Disponibilidade mensal esperada 99,9%. | Orçamento teórico de indisponibilidade de aproximadamente 43,8 min em mês de 30,4 dias; SLO e medição precisam ser acordados. |
| F4 | p95 de criação ≤ 500 ms. | Definir início/fim da medição, inclusão de APIM/rede e mix de payload; manter criação independente de notificação assíncrona. |
| F5 | Pedidos consultam Catálogo sincronamente por item e pedidos grandes sofrem N+1. | Consulta em lote ou preço cotado/validado em uma operação, com limite de itens e timeout explícitos. |
| F6 | Pedido não guarda snapshot de preço/descrição. | Armazenar no pedido os valores aceitos no instante da compra e a moeda/origem da cotação. |
| F7 | Retries sem idempotency key e publicação de eventos sem garantia transacional. | Persistência de chave/resultado e padrão outbox no limite transacional de Pedidos. |
| F8 | Parceiros pedem API pública versionada e notificações assíncronas de status. | Contratos públicos estáveis, autenticação/autorização/quotas e entrega assíncrona com repetição e replay controlados. |
| F9 | LGPD e residência do segundo país. | Minimização, classificação, retenção e localização de dados dependem de país, base legal e análise jurídica. |
| F10 | Contratos atuais compatíveis por ≥ 6 meses; primeira melhoria em produção em 30 dias sem parada. | Strangler/expand-contract, implantação paralela, métricas de adoção e rollback por rota/tráfego. |

## Premissas de trabalho (não são fatos)

1. Azure é a nuvem de referência e .NET/ASP.NET Core a tecnologia da prova, conforme alinhamento com o candidato.
2. Azure Container Apps é a hipótese inicial de hospedagem por simplicidade operacional; comparar com AKS e App Service na descoberta e estimativa.
3. Pedidos requer consistência transacional relacional para o agregado do pedido, chave idempotente e outbox. Banco e região ainda não estão decididos.
4. Service Bus será o broker gerenciado de referência; status pode ser entregue ao parceiro por webhook com assinatura, retentativas limitadas e fila de falhas, ou por mecanismo alternativo definido com consumidores.
5. Há capacidade para implantar uma camada compatível diante do backend atual e coletar métricas/logs sem alteração disruptiva nos clientes.
6. A prova local usa dados sintéticos e SQLite para exercitar restrição única e transação; isso não representa escolha de banco para produção.
7. A estimativa considera uma equipe dedicada e acesso rápido a stakeholders, ambientes, pipelines e credenciais; custos Azure dependem de região, SKU, tráfego e retenção.

## Questões de descoberta prioritárias

### Bloqueadoras para desenho detalhado / produção

- Qual é a arquitetura e o contrato atual (rotas, payloads, semântica de erro, autenticação, consumidores conhecidos)? Há especificação ou tráfego capturado?
- Qual país será atendido, quais regras de residência/localização e quais dados podem cruzar fronteiras? Jurídico/privacidade aprovou bases legais, retenção e transferência?
- Qual é o volume absoluto: pedidos/s médio e pico, itens/pedido, tamanho do payload, sazonalidade, taxa de retry e crescimento esperado por canal?
- Quais são as dependências e garantias do Catálogo: cotação em lote, validade de preço, disponibilidade, estoque, moeda, impostos e SLAs?
- Quais são as metas de recuperação (RTO/RPO), regiões de contingência e tolerância a perda/atraso de notificações?
- Qual mecanismo de identidade usam web, mobile e parceiros? Como emitir, rotacionar e revogar credenciais e assinar webhooks?

### Importantes para custo e operação

- Qual assinatura Azure, landing zone, regiões aprovadas, conectividade privada, políticas de rede e pipeline corporativo estão disponíveis?
- Há preferência por SQL Server/Azure SQL, PostgreSQL ou outra tecnologia? Qual capacidade de suporte e licenciamento existe?
- Quais são as janelas de manutenção, requisitos de observabilidade, retenção, auditoria e plantão?
- Parceiros exigem ordenação por pedido, replay, confirmação, SLA de entrega ou portal de desenvolvedor?
- Quais são as equipes disponíveis, competências, restrições de contratação e modelo de governança do COE/Client Face?

## Como validar sem paralisar

Registrar decisões reversíveis como hipótese, instrumentar o comportamento atual, iniciar contrato e prova isolados e conduzir discovery em paralelo. Decisões de residência, identidade, região e recuperação devem ser aprovadas antes do tráfego de produção do segundo país.
