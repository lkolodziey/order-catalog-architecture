# ADR-004: Evolução compatível de API pública

- **Status:** Proposto
- **Data:** 2026-10-13
- **Contexto:** Parceiros necessitam API pública versionada; contratos atuais devem permanecer compatíveis durante pelo menos seis meses e consumidores não podem ser interrompidos.
- **Decisão:** Expor API via Azure API Management, publicar OpenAPI, iniciar `/v1`, adicionar mudanças compatíveis primeiro, medir consumo por client/versão e manter contrato legado no mínimo seis meses. Mudanças incompatíveis usam nova versão maior com plano de migração e sunset aprovado. Validar schemas/testes de contrato no CI. Autenticação, quotas e escopos por parceiro.
- **Alternativas:** (1) Alterar contrato in-place: risco de quebrar consumidores; (2) versão apenas por header sem política clara: descoberta e roteamento menos transparentes; (3) gateway sem contrato-fonte: drift entre implementação e documentação.
- **Consequências positivas:** Migração observável e governada; contrato auditável e verificável.
- **Consequências negativas:** Manutenção paralela, custo de APIM e necessidade de identificar consumidores reais.
- **Segurança:** OAuth/OIDC ou federação B2B a definir; quotas por consumidor; segredos nunca compartilhados; resposta sem detalhes internos.
- **Validação:** Teste de consumidor legado contra nova implementação e teste de evolução aditiva; telemetria por versão.
- **Revisitar quando:** Política corporativa de API, requisitos de parceiro, latência/custo ou estratégia de produto mudar.
