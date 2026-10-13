# Uso de IA na elaboração do desafio

## Ferramenta e motivo

Este artefato foi elaborado com assistência de um modelo de linguagem para estruturar o enunciado, comparar padrões e acelerar rascunhos. A proposta e os trade-offs devem ser defendidos pelo candidato; IA não substitui validação técnica, jurídica, operacional ou consulta ao cliente.

## Dados e isolamento

- A análise usou apenas o PDF do desafio, que contém descrição genérica do cenário, sem credenciais, dados reais de clientes ou código proprietário.
- Para uso operacional futuro, não enviar PII, tokens, segredos, payloads reais ou diagramas restritos para serviço externo sem aprovação e controles contratuais.
- Preferir dados sintéticos/pseudonimizados, acesso mínimo, retenção aprovada e ambiente empresarial com política explícita de treinamento/armazenamento.
- RAG/assistente operacional futuro deve recuperar somente dados autorizados pelo mesmo principal; validar autorização no backend, minimizar resultados e registrar acesso sem vazar conteúdo.

## Prompts representativos

1. “Extraia do desafio os requisitos explícitos, restrições, métricas, critérios críticos e entregáveis; diferencie fato de inferência.”
2. “Proponha alternativas para idempotência e publicação transacional de eventos em .NET/Azure, com falhas, trade-offs e decisões ainda dependentes de validação.”
3. “Revise o fluxo de criação e a evolução de contrato buscando duplicidade, quebra de compatibilidade, exposição de PII e pontos de falha.”
4. “Verifique se cada requisito do enunciado tem artefato, mecanismo e evidência reproduzível associados.”

Os prompts são exemplos relevantes documentados para transparência; não são logs literais de sessões privadas com conteúdo do cliente.

## Validações humanas e automatizadas

- Comparar todos os requisitos com o PDF original; separar métricas explícitas de metas propostas.
- Revisar decisões contra documentação oficial do Azure e marcar SKU, região e capacidade como pendentes.
- Conferir consistência entre diagramas, ADRs, contratos e implementação; executar a prova e registrar limites.
- Revisão de segurança para autenticação, autorização, residência, logging e callbacks.
- Rejeitar recomendações de “exactly once” ponta a ponta sem prova; documentar at-least-once e idempotência.

## Decisões rejeitadas/evitadas

- Não afirmar que Azure Service Bus sozinho garante unicidade de negócio; sua detecção de duplicata não substitui idempotência persistida.
- Não propor reescrita big bang ou microsserviço por tabela, pois o prazo e compatibilidade pedem evolução incremental.
- Não fixar país/região, custo, banco, RTO/RPO nem requisitos legais ausentes.
- Não recomendar IA para decisão automática sobre pedidos ou dados pessoais sem isolamento, autorização e avaliação definidos.
