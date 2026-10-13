# Evolução da Plataforma de Pedidos e Catálogo

Proposta de arquitetura para o desafio técnico de COE Sênior — Arquitetura de Soluções.

> **Status:** proposta de referência e prova técnica local. O estado atual foi inferido exclusivamente do enunciado; decisões de produção dependem das validações listadas em `docs/premissas-e-questoes-abertas.md`.

## Recomendação em uma frase

Evoluir por fatias compatíveis, proteger a criação de pedidos com idempotência persistida no mesmo limite transacional do pedido, registrar eventos em uma outbox e publicar mudanças de status de forma assíncrona, expondo contratos públicos versionados por uma camada de gestão de APIs.

## Como navegar

| Artefato | Conteúdo |
|---|---|
| [Resumo executivo](docs/resumo-executivo.md) | Recomendação, investimento, riscos e decisões para validação (formato conciso, até duas páginas em renderização comum). |
| [Premissas e questões abertas](docs/premissas-e-questoes-abertas.md) | Fatos, hipóteses e perguntas que precisam de descoberta. |
| [Arquitetura atual](docs/arquitetura-atual.md) | Modelo inferido, problemas e falhas relevantes. |
| [Arquitetura-alvo](docs/arquitetura-alvo.md) | Componentes Azure, fronteiras de confiança e fluxos. |
| [Domínios e dados](docs/dominios-e-dados.md) | Bounded contexts, ownership, consistência, idempotência e eventos. |
| [Migração 30/60/90](docs/migracao-30-60-90.md) | Incrementos, convivência, observabilidade, rollback e encerramento. |
| [Qualidade e operação](docs/qualidade-e-operacao.md) | Cenários mensuráveis, resiliência, observabilidade e critérios de aceite. |
| [Threat model](docs/threat-model.md) | Ameaças, controles, riscos residuais e resposta. |
| [Estimativa](docs/estimativa-equipe-custos-riscos.md) | Time, esforço, custos e riscos com premissas explícitas. |
| [Uso de IA](docs/uso-de-ia.md) | Ferramenta, escopo, validação, prompts de trabalho e proteção de dados. |
| [ADRs](adrs/README.md) | Índice das decisões arquiteturais e alternativas consideradas. |
| [Diagramas](diagrams/README.md) | Índice dos C4 atual/alvo e diagramas de sequência em Mermaid. |
| [Contratos](contracts/README.md) | Índice das especificações OpenAPI e AsyncAPI. |
| [Prova executável](proof/README.md) | Implementação .NET, dados sintéticos e um comando de execução. |
| [Pipeline](.github/workflows/verify.yml) | Build e execução automatizada dos cenários da prova em push e pull request. |

## Requisitos-chave do enunciado

- Crescimento projetado de tráfego de 10×; disponibilidade mensal esperada de 99,9%; p95 de criação de pedido ≤ 500 ms.
- Aplicativo móvel, parceiros de marketplace e segundo país em 90 dias; consumidor atual sem interrupção.
- Primeira melhoria segura em produção em 30 dias e compatibilidade de contratos existentes por ao menos seis meses.
- Corrigir duplicidade por retry, publicação não transacional, N+1 de consulta ao Catálogo e ausência de snapshot de preço/descrição.
- Preservar privacidade e avaliar residência de dados conforme LGPD e requisitos do país ainda não informado.

## Executar a prova

Na pasta `proof`, com .NET SDK instalado, use `./run-proof.ps1` no Windows ou `./run-proof.sh` em Linux/macOS:

```powershell
./run-proof.ps1
```

O script inicia a API, envia chamadas de demonstração, valida resultados positivos e negativos, verifica a compatibilidade do consumidor legado e encerra o processo. Os dados são sintéticos e persistidos em um arquivo SQLite temporário/local. A prova não provisiona recursos Azure.

## Decisões de plataforma (hipóteses para validar)

- ASP.NET Core/.NET para APIs e workers.
- Azure API Management para gestão dos contratos de parceiros e aplicação de políticas; autenticação de produção por Microsoft Entra ID/OAuth 2.0 ou federação B2B a selecionar após definir os consumidores.
- Azure Container Apps como ponto de partida para serviços conteinerizados, sujeito à validação de rede, escala, operação e custo contra AKS/App Service.
- Banco relacional gerenciado como hipótese para Pedidos, com outbox na mesma transação; Azure Service Bus para comunicação assíncrona.
- Identidade gerenciada, Key Vault, Application Insights/Azure Monitor, Log Analytics e infraestrutura como código deverão fazer parte da implementação de produção.

Consulte os ADRs para consequências, alternativas e gatilhos de revisão. Nenhum recurso Azure foi provisionado.
