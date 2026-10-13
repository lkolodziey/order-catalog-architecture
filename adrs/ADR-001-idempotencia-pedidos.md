# ADR-001: Idempotência persistida na criação de pedidos

- **Status:** Proposto
- **Data:** 2026-10-13
- **Contexto:** O desafio informa retries sem chave e exige que chamadas repetidas com a mesma chave não criem pedidos duplicados. Timeout pode deixar o cliente sem saber se o commit ocorreu.
- **Decisão:** Exigir `Idempotency-Key` para a operação pública de criação. Armazenar hash da chave scoped por tenant/operação, fingerprint do payload canônico e referência/resultado do pedido no mesmo banco transacional. Criar constraint única. Repetição equivalente retorna o resultado original; mesma chave com payload diferente retorna conflito. Chave e dados sensíveis não aparecem em logs.
- **Alternativas:** (1) Cache distribuído: rejeitada como fonte de verdade por expiração/perda/concorrrência; (2) deduplicar apenas no broker: não protege POST antes da publicação; (3) confiar em UUID de pedido enviado pelo cliente: identidade não prova equivalência de operação.
- **Consequências positivas:** Protege contra retry após timeout e concorrência entre réplicas; decisão testável; evita exatamente-uma-vez ilusório.
- **Consequências negativas:** Retenção, limpeza e semântica de resposta precisam ser definidas; armazenamento adicional e caminho de leitura para replay.
- **Riscos/controles:** Guessing/replay mitigados por escopo, hash seguro, autenticação, quota e expiração; concorrência arbitrada pela constraint única e leitura do registro vencedor.
- **Validação:** Testes repetidos, concorrentes, mesmo payload e payload divergente; exercitar timeout pós-commit.
- **Revisitar quando:** Contrato de parceiros, janela máxima de retry, exigência regulatória de retenção ou volume alterar custo/semântica.
