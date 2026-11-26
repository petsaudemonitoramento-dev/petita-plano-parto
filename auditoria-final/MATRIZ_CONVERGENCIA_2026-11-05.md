# Petita — mapa de convergência das PRs pendentes

**Data do registro:** 2026-11-05. **Natureza da evidência:** comparação relatada pela execução Codex, com estados das PRs conferidos pela integração GitHub. **Não equivale a testes, merge ou auditoria concluída.**

## Linha de base

- `main` na comparação relatada: `5ec0a70`, Petita `0.3.0+21` (confirmar se houver novos commits antes de integrar).
- Base atual do aplicativo a preservar: cards responsivos, scroll reiniciado por pergunta, feedback visual para resposta escrita, voz local opcional, Modo Consulta Pré-Natal offline, PDF e os 31 itens canônicos.
- `#24` é a PR de preparação/documentação da auditoria, ainda aberta. O código destas quatro PRs **não está integrado na main**.
- O Codex relatou que o hash do questionário confere com o original; **nenhum novo comando/teste com log foi registrado nessa execução**.
- O Codex relatou bloqueio de `git fetch` por proxy e impossibilidade de persistir arquivos pelo conector. Este documento foi salvo posteriormente pela integração GitHub deste chat, não pelo Codex Cloud.

## Matriz de decisões

| Origem | Estado conferido | Decisão proposta | Dependências / risco de integração | Próximo gate |
|---|---|---|---|---|
| [PR #15](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/pull/15) — identidade, RLS | Aberta, não integrada; `mergeable=false` no estado consultado | Aproveitar fundação de identidade, RLS e testes PostgreSQL isolados; adaptar à main atual | Esquema SQL e contexto transacional de autenticação; verificar conflito e governança de roles | Reconciliar arquivos e migrar/testar em PostgreSQL descartável; não aplicar em Neon produção |
| [PR #17](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/pull/17) — dúvidas e aprovação UBS | Aberta, base `infra/neon-identidade-rls` (#15) | Aproveitar após #15, preservando idempotência, locks, histórico e revogação | Não retarget/merge antes da base; avaliar consistência com backend escolhido | Testar isolamento UBS A/B, rollback e revogação, com fixtures sintéticas |
| [PR #16](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/pull/16) — Android permanente | Aberta, não integrada; `mergeable=false` na consulta | Adaptar scaffold Android, ícone, hardening e CI; manter TTS, versão e novos recursos da main | Regras de Android/Gradle, applicationId, assinatura, permissões, versionCode e bootstrap podem estar defasados | Reconciliar contra Flutter atual; build debug/release **não publicado** no CI |
| [PR #19](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/pull/19) — alternativa Neon/API | Aberta em rascunho, não integrada; `mergeable=false` na consulta | Reaproveitar seletivamente contratos HTTPS/JWT, validações e testes; não adotar esquema concorrente sem revisão | Duplicidade de tabelas/autorização diante das PRs #15/#17; diferenças de urgência e sincronização | Elaborar comparação de dados, endpoints e papéis, escolhendo **uma** fonte de verdade |
| `main` `0.3.0+21` | Base funcional existente | Preservar interfaces e fluxos aprovados | Regressões por incorporação de branches de outubro | Verificar questionário byte a byte, Flutter analyze/test, PDF offline e Android |

## Primeiras observações de segurança — apenas hipóteses

1. **INSP-01:** `lib/main.dart` ainda depende de inicialização Supabase. Diferenciar funcionamento offline de telas online que ainda não usam Neon Auth/Google.
2. **INSP-03:** RAG com chave publicável e indicação `verify_jwt=false` requer análise de autenticação efetiva, quotas, abuso, proteção de dados e eventuais controles adicionais; não declarar vulnerabilidade sem reproduzir.
3. **INSP-02:** `SharedPreferences` armazena dados locais do plano; avaliar confidencialidade, backup Android, exclusão, persistência e migração **sem conectar dados reais**.
4. **INSP-04:** isolamento remoto entre UBS não foi comprovado pela inspeção estática, nem por login Google/Neon no aplicativo; exigir teste negativo em ambiente isolado.
5. **INSP-06:** revisar procedimento de assinatura APK, certificados anteriores e risco de perda de dados em atualizações; nunca registrar chaves privadas em documentação.

## Ordem de trabalho que economiza franquia

1. Validar baseline e guardar este checkpoint; se `git fetch` continuar bloqueado no Codex Cloud, **não insistir indefinidamente** — consultar GitHub por API/connector, trabalhar sobre material já disponível ou seguir revisão estática.
2. Revisar superfícies **ativas na main** antes de discutir integrações futuras: inicialização Supabase, armazenamento, consentimento, RAG e gestão de autorização.
3. Executar testes de regressão e segurança **focados**, sintéticos e com timeout. Se travarem, registrar TIMEOUT e seguir; uma retentativa justificada no máximo.
4. Só propor patches de risco P0/P1 reprodutíveis, isolados em branch/PR; não integrar em bloco PRs #15/#16/#17/#19.
5. Deixar revisão de desempenho e pacote de registro para janela B, usando o HANDOFF; não assumir que o software está validado para uso clínico.

## Limites verificados do checkpoint

- Nenhuma nova suíte Flutter, PostgreSQL ou Android foi executada nesta rodada Codex, segundo o relato recebido.
- Nenhuma funcionalidade foi corrigida nesta rodada Codex.
- Nenhum merge/deploy/migração/produção foi autorizado.
- A documentação foi persistida pela integração GitHub deste chat. A autoria deste commit **não prova execução no ambiente Codex**.
