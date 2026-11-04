# Plano mestre — auditoria final da Petita antes do pacote de registro

**Data de preparação:** 04/11/2026. **Repositório:** `petsaudemonitoramento-dev/petita-plano-parto`. **Release de código:** `0.3.0+21` (ver `pubspec.yaml`); **APK novo:** não considerar publicado sem consultar Releases. **Controle:** issues #21 (geral), #22 (janela A), #23 (janela B). **Branch de preparação:** `audit/codex-final-petita-20261104`.

## O que queremos provar, não apenas supor
1. Nenhuma UBS vê dúvida de outra UBS nem identidade de gestante; gestante só acompanha suas próprias dúvidas; administração não é desbloqueada apenas por variável local/claim manipulável.
2. O app pode funcionar offline no percurso de perguntas, consulta presencial, resumo e PDF; não obriga conexão à nuvem para saúde materna. Não perde dados silenciosamente quando volta de background, gira a tela, recebe teclado, passa para próximo card ou atualiza o APK.
3. A explicação educacional não se apresenta como diagnóstico; perguntas urgentes mandam buscar atendimento presencial, sem promessa de resposta; mecanismo RAG respeita fontes e não inventa fatos.
4. Termos, consentimento e exclusão de dados funcionam com escopo claro. Dados sensíveis locais/remotos são minimizados e protegidos. Só alegar medidas comprovadas.
5. PDF mantém integridade sem cortes, nomes corretos e declaração no formato desejado; tempo e consumo de memória medidos antes/depois, não apenas "parece mais rápido".
6. Builds de Android/Web são reproduzíveis; distribuição e assinatura persistente são revisadas; update não destrói dados e difere de simples reinstalação; dependências/licenças e artefatos de registro são rastreáveis.

## Inventário técnico inicial a confirmar
- **Flutter:** `lib/main.dart`, `lib/app.dart`, `lib/screens/**`, `lib/services/**`, `lib/config/**`; questionário `assets/data/birth_plan_flow.json`, FAQ e UBSs locais.
- **Offline/PDF:** `StorageService` grava no `SharedPreferences` (verificar adequação para dados de saúde, persistência e criptografia); `PdfService`, `BirthPlanSummaryScreen`, `printing`; leitura TTS Android condicional.
- **Online legado:** `lib/main.dart` inicializa `Supabase.initialize`; `SupabaseService`, admin/UBS, `supabase/functions/**`, SQL `documentos/supabase_*.sql`. Não assumir que a migração Neon resolveu o cliente.
- **Neon/Auth:** projeto anteriormente provisionado no Neon, mas o código Flutter mostrado ainda usa Supabase. Investigar integração possível e plano de migração **sem conexão produtiva**. Auth Google APK ainda não comprovado.
- **Build e release:** `.github/workflows/**`, `tool/prepare_android_tts_manifest.py`, `scripts/**`, `pubspec.lock`, assinaturas/APKs com certificados distintos; nenhuma chave em código ou logs.
- **Documentação desatualizada:** `README.md` e `lib/config/app_info.dart` podem citar `0.2.0` e Supabase; comparar com realidade antes de corrigir.

## Execução em até duas janelas de franquia de cinco horas
Uma "janela de cinco horas" é **cota de uso**, não garantia de trabalho contínuo por cinco horas. Comece por ações baratas/mais críticas e grave o estado ao fim de cada marco. Se restar pouca franquia, encerre criando HANDOFF reprodutível, não inicie uma grande migração.

### Janela A (Issue #22) — mapear riscos e provas, com correções P0 mínimas
| Marco | Foco | Evidência mínima |
|---|---|---|
| A0 | Baseline, versões, hashes, git status, Flutter, árvore, fluxo de dados local/remoto | `PROGRESSO.md`, diagrama/mapa, comando e commit |
| A1 | Segurança do auth, admin/UBS, RLS, RPC, Edge Functions, storage, RAG, uploads, segredos | threat model + 5 principais fluxos de abuso e resultados |
| A2 | Privacidade/LGPD técnica: consentimento, anonimato, dados de gestação, persistência e exclusão | matriz dado × origem × destino × permissão × retenção |
| A3 | Bugs offline, 31 perguntas, cards responsivos, retorno scroll, seleção escrita, TTS, PDF | testes sintéticos que reproduzem casos, logs resumidos |
| A4 | Ranking P0/P1/P2 + plano cirúrgico para Janela B | `ACHADOS.md`, estado do CI, HANDOFF claro |

**Técnica:** priorizar primeiro superfícies com dados identificáveis, admin/UBS, upload/RAG e comunicação entre backend e APK. No mínimo, revisão estática com caminhos `arquivo:linha`; teste remoto só com fixture local, nenhum teste contra pacientes. Evitar tentar executar SQL de migração no Neon.

### Janela B (Issue #23) — corrigir problemas comprovados e melhorar desempenho
| Marco | Foco | Evidência mínima |
|---|---|---|
| B0 | Retomar HANDOFF, conferir diffs/CI e riscos remanescentes, escolher P0/P1 em ordem | plano curto de commits e testes |
| B1 | Corrigir P0/P1: autorização, dados, offline, regressões comprovadas | testes falham antes e passam depois; PRs pequenas |
| B2 | Performance: PDF, tamanho do APK, startup, transições de card, TTS e consultas remotas | medições com mesmo fixture antes/depois, mediana e limites |
| B3 | Hardening: deps e supply chain, permissões, logs sem PII, falhas de rede e UX acessível | checklist evidenciado + Android/Web build |
| B4 | Parecer final e pacote de congelamento de código para INPI/NITT | `PARECER_FINAL.md`, `PROGRESSO.md`, plano de rollback, hash representativo pós-freeze |

## Gates técnicos mínimos
- `flutter pub get --enforce-lockfile`, `flutter analyze --no-pub`, `flutter test --no-pub`.
- Testes das 31 perguntas e invariância SHA-256 dos assets canônicos.
- Compatibilidade com Android real, incl. API 24+, 320–600 px, fontes escaladas, teclado aberto, rotação, TalkBack (quando houver aparelho disponível; caso contrário marcar manual pendente).
- PDF: gerar com resposta curta/longa/acentos/nomes e validar bytes/páginas, retorno de compartilhamento, não mostrar conteúdo privado em logs.
- Offline/online: isolamento entre contas fictícias de UBS A e B com permissões distintas e nenhum vazamento; qualquer verificação que requeira serviço real vai para etapa manual controlada.
- Segurança: auth do lado servidor, nenhuma service-role/secret no app, verificação de RLS, endpoint público não baseado apenas em chave publicável, input com limites, sem logs sensíveis.
- Assinatura APK: certificado, package ID, versionCode, chave durável, estratégia de atualização a partir das versões de teste; não assinar/publicar durante auditoria.

## Política de decisão
- **NO-GO**: qualquer P0 aberto confirmado; rotas remotas de paciente/UBS/admin inseguras; dados reais usados em teste; perda de dados não resolvida; build não reproduzível.
- **GO-COM-RESSALVAS**: núcleo offline estável para testes fictícios com serviços online bloqueados/desligados e riscos explicitados; **não equivale à homologação para pacientes reais**.
- **GO**: P0 encerrados com evidência e riscos P1 avaliados; versão congelada, testes passam, revisão humana e clínica pendentes conforme escopo.
- Alterações de texto clínico/termos exigem revisão humana especializada, mesmo com CI verde.

## Uso eficiente da franquia
- Mantenha contexto em arquivos curtos, não despeje código inteiro a cada turno.
- Execute os testes de um módulo apenas ao mudá-lo; suite completa no gate.
- Compartilhe status ao concluir marcos e ao detectar P0, não acumule por horas.
- Se faltar tempo, prefira evidência de um P0 e checkpoint ao invés de 20 melhorias cosméticas.
- Nenhum benchmark sem baseline; registre hardware/ambiente, unidade e repetições.
