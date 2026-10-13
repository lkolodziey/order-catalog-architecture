# Estimativa da primeira fase (30 dias)

## Faixa de esforço

Estimativa base de **24–28 pessoa-semanas** (soma das alocações nominais abaixo) para uma primeira fase que inclui descoberta, desenho, incremento de idempotência/outbox, contratos, pipeline, observabilidade e rollout controlado. Com uma reserva de 25–40% para integração, aprovações e estabilização, a faixa inicial de planejamento é **30–39 pessoa-semanas**. A faixa não é orçamento comercial final; assume acesso tempestivo aos sistemas e stakeholders e exclui migração completa do legado e implantação do segundo país.

| Papel | Alocação indicativa | Esforço em 4 semanas |
|---|---:|---:|
| Arquiteto de soluções / liderança técnica | 1,0 FTE | 4 pessoa-semanas |
| Desenvolvedor .NET backend | 2,0 FTE | 8 pessoa-semanas |
| QA/automação/contract testing | 1,0 FTE | 4 pessoa-semanas |
| DevOps/plataforma Azure | 0,75–1,0 FTE | 3–4 pessoa-semanas |
| Segurança/privacidade | 0,25–0,5 FTE | 1–2 pessoa-semanas |
| Product owner/analista de domínio | 0,5 FTE | 2 pessoa-semanas |
| Especialistas existentes de Pedidos/Catálogo e operações | 0,5–1,0 FTE compartilhado | 2–4 pessoa-semanas |
| **Total nominal da equipe** | **5,0–6,0 FTE combinados** | **24–28 pessoa-semanas** |

Se discovery revelar contratos inexistentes, mudanças no Catálogo ou restrições de landing zone, reestimar acima da faixa antes de assumir compromisso comercial. Contingência não é capacidade produtiva prometida.

## Marcos de trabalho

| Semana | Foco | Evidência |
|---|---|---|
| 1 | Discovery, contrato, SLO e baseline; decisões de identidade, dados e ambiente. | Mapa de consumidores, ADRs iniciais, riscos e plano de rollout. |
| 2 | Persistência da chave e transação pedido/outbox; API compatível. | Testes de concorrência, retry e payload conflitante. |
| 3 | Publicador/consumidor, telemetria, contract tests, pipeline. | Demonstração de reprocessamento e contrato legado. |
| 4 | Carga, segurança, runbooks, canary e estabilização. | Critérios de aceite, rollback ensaiado e release aprovado. |

## Custos Azure

Não informar valor monetário como se fosse confiável sem região, SKU, throughput, retenção, arquitetura de rede e suporte contratual. A estimativa comercial deve usar a calculadora Azure após esses dados. Principais vetores: APIM (tier/capacidade), compute e réplicas mínimas, banco (HA/armazenamento/backup), Service Bus (tier/volume), logs/traços (ingestão e retenção), rede/egress, Key Vault e ambientes não produtivos. Medir custo por 1.000 pedidos e incluir retenção e picos de carga.

## Riscos à estimativa

- Falta de testes/contratos existentes ou comportamento legado não documentado: amplia descoberta e adaptação.
- Catálogo sem endpoint bulk/quote: requer evolução coordenada e negociação de semântica de preço.
- Landing zone, rede privada, segurança ou compra de SKU indisponíveis no início: pode ameaçar o marco de 30 dias.
- Requisitos do segundo país desconhecidos: inviabilizam fechar residência e recuperação dentro da estimativa.
- Mudança simultânea de contrato ou dados sem donos de consumidores: aumenta risco de regressão.

## Dimensionamento e governança comercial

Planejar por capacidade e entregas, confirmar senioridade/composição com o Client Face, separar esforço de build de custos recorrentes Azure, licenças e suporte. Estimativa final exige backlog refinado, dependências confirmadas, disponibilidade dos especialistas e premissas contratuais registradas.
