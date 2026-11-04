# Achados técnicos — auditoria final Petita

**Estado:** sem vulnerabilidades confirmadas por esta preparação. As notas abaixo são hipóteses de trabalho, a serem testadas pelo Codex.

## Severidade e evidência
- **P0:** exposição de dados/credenciais, acesso indevido, privilégio indevido, quebra de isolamento entre UBS, perda irrecuperável de dados, orientação clínica perigosa.
- **P1:** falha funcional importante, regressão offline, PDF inválido ou lento em nível impeditivo, upgrade com perda de dados.
- **P2:** manutenção, documentação, UX/acessibilidade ou desempenho sem dano imediato comprovado.
- **OBS/UNKNOWN:** hipótese ainda não confirmada, não deve receber selo "corrigido".

| ID | Severidade | Status | Evidência `arquivo:linha` | Como reproduzir | Impacto | Correção proposta | Teste antes/depois | Risco residual |
|---|---|---|---|---|---|---|---|---|
| INSP-01 | UNKNOWN | A INVESTIGAR | `lib/main.dart`; `lib/config/supabase_config.dart` | Revisar caminho de inicialização e autenticação contra arquitetura Neon planejada | Possível divergência funcional/backend | Documentar e propor migração segura somente em ambiente de teste | Pendente | Pendente |
| INSP-02 | UNKNOWN | A INVESTIGAR | `lib/services/storage_service.dart` | Localizar dados de saúde persistidos e mecanismo do SO/backup | Confidencialidade e persistência | Modelo de ameaças e avaliação de storage mais adequado | Pendente | Pendente |
| INSP-03 | UNKNOWN | A INVESTIGAR | `supabase/config.toml` e `supabase/functions/ask-petita-rag/index.ts` | Checar autenticação efetiva, abusos e limites | Custo e uso indevido | Endurecimento condicionado a evidências | Pendente | Pendente |
| INSP-04 | UNKNOWN | A INVESTIGAR | `lib/screens/admin/`; `lib/screens/ubs/`; SQL/RPCs | Acesso por perfis fictícios A/B/gestante/admin | Privacidade/segregação | Padrões de autorização no servidor e testes negativos | Pendente | Pendente |
| INSP-05 | P2 potencial | A INVESTIGAR | `README.md`; `lib/config/app_info.dart` | Comparar versão exibida com pubspec | Documentação equivocada | Atualizar apenas após confirmação | Pendente | Pendente |
| INSP-06 | UNKNOWN | A INVESTIGAR | `.github/workflows/publicar_apk_petita_v030.yml` | Revisar certificados, segredos e upgrade sem acessar valores | Distribuição segura e continuidade | Processo de assinatura reproduzível com chave protegida/rotacionada | Pendente | Pendente |

## Regras para editar este relatório
1. Adicionar linha por achado confirmado; não misturar múltiplos riscos em um único ID.
2. Evitar copiar PII, tokens, chaves privadas, sessões ou respostas reais. Para exemplo, dados fictícios.
3. Toda falha confirmada deve ter caso mínimo reprodutível, impacto e fix localizado ou bloqueio explícito.
4. Um CI verde não prova segurança de backend real. Separar inspeção estática de teste com permissão controlada.
5. Não classificar como P0 por ansiedade: demonstrar cenário plausível de dano e as condições necessárias.
6. Registrar quando um risco não pode ser testado na nuvem ou sem Android real: `NÃO VERIFICADO` + teste manual sugerido.
