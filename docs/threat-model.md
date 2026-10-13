# Threat model (primeira versão)

## Escopo e método

Escopo: clientes públicos, APIM, API/worker de Pedidos, Catálogo, banco, outbox, Service Bus, callbacks de parceiros, identidade/segredos e telemetria. Modelo inicial por fronteiras de confiança e STRIDE simplificado; validar ativos, agentes de ameaça e controles com Segurança/Privacidade antes de produção.

## Ativos e fronteiras

- Ativos: integridade do pedido/preço, identidade e referência do comprador, disponibilidade, credenciais/certificados, eventos e trilha de auditoria.
- Fronteiras: internet/APIM; gateway/workload; workload/banco e broker; worker/endpoint parceiro; produção/observabilidade; região/país.

## Ameaças e controles

| Ameaça | Vetor/impacto | Controles preventivos | Detecção/resposta / risco residual |
|---|---|---|---|
| Spoofing de cliente/parceiro | Token/credencial roubada cria pedidos ou lê pedidos alheios. | OAuth2/OIDC, validação issuer/audience, scopes por operação e tenant, Managed Identity serviço-a-serviço, rotação e revogação. | Alertas por anomalia/401/403, revogar credencial, trilha de acesso. Roubo de endpoint ainda possível. |
| BOLA/elevação de privilégio | Alterar `orderId`/tenant e acessar dados de outro cliente. | Autorização por objeto no domínio; tenant derivado da identidade; não confiar em tenant do corpo; testes negativos. | Auditoria de acesso e alertas; isolamento adicional a decidir. |
| Abuso/DoS | Flood de criação, payload grande ou pedido com milhares de itens. | APIM quotas/rate limits, limite de payload/itens, timeout, concorrência e autoscale controlado. | Métricas por consumidor, bloqueio/ajuste de quota, proteção de custo. Rate limit distribuído é aproximado conforme gateway. |
| Replay/duplicidade | Retry malicioso ou natural gera ordens extras. | Chave idempotente scoped e persistida, fingerprint, TLS; autorização e expiração explícitas. | Métrica de replay/conflito, investigação por traceId. Abuso com muitas chaves exige quota. |
| Tampering de preço/evento | Manipular preço enviado por cliente ou mensagem/evento. | Preço calculado/validado pelo Catálogo, snapshot server-side, RBAC no broker, TLS, schema validation e assinatura/verificação de webhook. | Auditoria de mudança, alertas de divergência e quarentena de mensagens inválidas. |
| Repúdio | Negar criação, transição ou entrega. | IDs de correlação/evento, timestamps UTC, trilha append-only protegida, autoria/principal e política de retenção. | Pesquisa/auditoria com acesso restrito e cadeia de retenção. |
| Exposição de PII | Logs, payloads, eventos ou replicação atravessam fronteira indevida. | Minimização, tokenização/referência, criptografia em trânsito/repouso, redaction, acesso mínimo, classificação e residência decidida antes do país. | DLP/alerta, resposta a incidente, retenção e eliminação; jurisdição/transferência requer validação legal. |
| SSRF em webhook | Parceiro fornece URL para alcançar metadata/rede interna. | Domínios aprovados, DNS/IP validation contra redes privadas/reservadas, egress controlado, redirects desabilitados ou revalidados, timeout e tamanho de resposta limitado. | Log de destino/resultado sanitizado e bloqueio por política. DNS rebinding ainda precisa ser considerado. |
| Secret leakage | Connection string/chave em configuração, pipeline ou log. | Managed Identity, Key Vault, certificados/segredos por parceiro, acesso mínimo, secret scanning e rotação. | Alertas de acesso, revogação e runbook. Prova local usa apenas segredos descartáveis. |
| Falha/replay de mensagem | Consumo duplicado, perda lógica, poison message ou adulteração. | Outbox, identidade de broker, schema/version, consumidor idempotente/inbox e DLQ. | Alarmes de idade/DLQ, reconciliação, replay aprovado e auditado. Entrega exatamente uma vez ponta a ponta não é assumida. |
| Supply chain/CI | Dependência/imagem alterada compromete workload. | Dependências fixadas, análise de vulnerabilidade/SBOM, imagem assinada e proveniência, revisão de pipeline e IaC. | Alertas CVE, rollback de release, política de patch. Baseline a alinhar com cliente. |

## Decisões e validações necessárias

Confirmar classificação e base legal de cada campo, localização/transferência de dados, retenção, requisitos de criptografia e auditoria, identidade B2B e gestão de certificados. Definir threat-model review antes do primeiro tráfego externo e repetir quando novo país, parceiro ou tipo de dado for introduzido.
