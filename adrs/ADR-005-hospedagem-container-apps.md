# ADR-005: Azure Container Apps como hipótese inicial de hospedagem

- **Status:** Proposto para comparação
- **Data:** 2026-10-13
- **Contexto:** A stack acordada é .NET e o prazo pede serviços/worker escaláveis com baixa carga operacional; requisitos reais de rede, compliance e equipe ainda não foram informados.
- **Decisão:** Usar Azure Container Apps como baseline de desenho para API e worker containerizados, sem declarar seleção final de produção. Fazer comparação documentada com AKS e App Service após validar landing zone, conectividade, escalabilidade mínima, custos, disponibilidade regional e suporte operacional.
- **Alternativas:** AKS oferece controle/orquestração mais amplo, com maior responsabilidade operacional; App Service pode simplificar hosting web e integração PaaS, mas pode não atender o mesmo modelo de worker/event scaling; Container Apps reduz gestão de cluster e permite escala baseada em eventos/HTTP, com limites e custos a validar.
- **Consequências:** Permite usar mesma imagem .NET para app/worker e revisar/canarizar implantação; exige revisar limites, VNet, zone redundancy, escala mínima, cold start e observabilidade para o SLO.
- **Validação:** Spike de rede privada/identidade, carga, escala e deploy reversível no ambiente de cliente.
- **Revisitar quando:** Requisito de controle de plano de dados, service mesh, política regional, perfil de carga ou competência operacional favorecer outra plataforma.
