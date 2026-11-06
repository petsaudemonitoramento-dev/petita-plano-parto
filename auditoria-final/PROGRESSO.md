# Progresso auditável — Petita / Codex

**Status global:** JANELA A — diagnóstico dirigido concluído em 2026-11-06; 61 verificações focalizadas, patch mínimo SEC-01 e ranking para B. Isolamento remoto NÃO VERIFICADO. HANDOFF mais recente ao final; seções anteriores são histórico.
**Data da preparação:** 2026-11-04.
**Repositório:** `petsaudemonitoramento-dev/petita-plano-parto`.
**Branch inicial:** `audit/codex-final-petita-20261104` (isolada de `main`).
**Base de release:** `0.3.0+21` no `pubspec.yaml`.
**Painéis:** #21 central; #22 janela A; #23 janela B.

## Quadro resumido

| Marco | Estado | Última evidência | Próxima ação |
|---|---|---|---|
| A0 — baseline/ambiente | PARCIAL (relato Codex) | Main `5ec0a70`, versão `0.3.0+21`, matriz de PRs em `MATRIZ_CONVERGENCIA_2026-11-05.md`; hash original alegado, sem log novo | Reconfirmar HEAD/hash/comandos no próximo ambiente utilizável |
| A1 — segurança/ameaças | INICIADO — inspeção estática | Supabase inicializa; RAG por chave publicável; storage SharedPreferences; Neon Auth e isolamento remoto sem teste | Reproduzir hipóteses em fixture sintética, classificar severidades com evidência |
| A2 — dados/privacidade | PENDENTE | SharedPreferences identificado no código | Mapear dados sensíveis, retenção, consentimento e exclusão |
| A3 — testes adversariais | PENDENTE | Suite Flutter existente, novos testes ainda não executados pelo Codex | Rodar testes e criar fixtures de UBS distintas |
| A4 — relatório riscos | PENDENTE | Documento inicial de riscos em `ACHADOS.md` | Classificar P0/P1/P2 somente após provas |
| B0 — retomada | AGUARDANDO A | — | Ler HANDOFF |
| B1 — correções | AGUARDANDO A | — | Priorizar P0/P1 |
| B2 — benchmarks | AGUARDANDO A | — | Baseline PDF/APK/startup |
| B3 — hardening/CI | AGUARDANDO A | — | Validar patches |
| B4 — parecer/congelamento | AGUARDANDO A | — | Redigir relatório final |

## Pontos de inspeção levantados na preparação (NÃO equivalem a vulnerabilidade confirmada)
- **INSP-01:** cliente `lib/main.dart` inicializa Supabase legado; projeto Neon/Auth existe separadamente. Confirmar o estado efetivo da migração sem chamar serviços reais.
- **INSP-02:** `lib/services/storage_service.dart` usa SharedPreferences com dados de gestação e consultas; verificar modelo de ameaças/criptografia/backup.
- **INSP-03:** `supabase/config.toml` marca `ask-petita-rag` com `verify_jwt=false`; verificar controle complementar, rate limiting, autorização e custo.
- **INSP-04:** telas admin/UBS, SQL/RPCs e Edge Functions ainda dependem de serviço remoto; isolamento de UBS e anonimato só podem ser confirmados por testes de autorização.
- **INSP-05:** `README.md` e `lib/config/app_info.dart` citam versão anterior; analisar inconsistência de documentação.
- **INSP-06:** APKs anteriores tinham assinaturas temporárias; verificar estratégia de update e origem/proteção da chave futura, inclusive potenciais exposições históricas.
- **INSP-07:** CI valida Flutter e APK debug; avaliar cobertura real de segurança, builds de release e revisão dos scripts de publicação.

## Modelo de atualização — completar imediatamente após marco
```text
[2026-.. ..:.. BRT] MARCO A1 — EM ANDAMENTO / CONCLUÍDO / BLOQUEADO
Branch / commit:
O que foi feito:
Arquivos:linhas:
Comando e resultado (sem segredos):
P0/P1 descobertos:
Próximo passo exato:
Possível bloqueio/manual:
Comentário postado em #21: [link/ID ou "sem permissão"]
```

## Checkpoint recebido em 2026-11-05 — relato do Codex e persistência externa

**Origem:** resumo fornecido pelo usuário de uma execução Codex Cloud. O Codex informou que o proxy bloqueou `git fetch` e que a gravação por conector foi interrompida. **Não há commit comprovadamente feito pelo Codex nesta execução.** Esta nota e a matriz foram salvas depois pela integração GitHub deste chat.

- Main comparada: `5ec0a70`, versão `0.3.0+21` (precisa reconfirmação antes de alterações).
- Matriz salva em `auditoria-final/MATRIZ_CONVERGENCIA_2026-11-05.md`.
- PRs #15/#17: aproveitar fundação e operações SQL em ordem de dependência, sem merge automático. PR #16: adaptar Android à main com voz e versão atuais. PR #19: reaproveitar contratos HTTP/JWT selecionados, rejeitando unificação ingênua dos dois esquemas Neon.
- Possíveis riscos para investigação: inicialização Supabase, RAG baseado em chave publicável, persistência de dados sensíveis em SharedPreferences. Neon Auth/Google integrado ao Flutter, isolamento de UBS e autorização remota **NÃO COMPROVADOS**.
- **Testes/builds novos:** não executados pelo Codex conforme relato; hash do questionário alegadamente corresponde ao original, mas sem log novo anexado.
- **Funcionalidades, banco ou produção:** inalterados nesta execução; nenhum merge/deploy/registro.
- **Bloqueio Codex:** proxy em `git fetch` e conector de escrita interrompido. No reinício, não gastar a janela insistindo indefinidamente: ler este commit pela interface/API do GitHub; documentar bloqueio e seguir análise de código ou testes com `tool/run_bounded_audit.sh`.
- **Próxima ação exata:** confirmar baseline e hash do questionário, consultar matriz, executar teste sintético de maior impacto (autorização/isolamento UBS ou acesso RAG) com timeout, e registrar resultado em `ACHADOS.md`.
- **Segunda janela:** só deve começar depois de classificar riscos com evidência; a análise estática não autoriza declarar GO ou vulnerabilidades P0 definitivas.

## HANDOFF anterior — atualizado em 2026-11-05 (histórico)

- **Janela:** A (inspeção estática parcialmente relatada; testes ainda pendentes).
- **Último commit feito pelo Codex nesta rodada:** NÃO CONFIRMADO; `git fetch` e escrita de conector falharam conforme relato.
- **Checkpoint GitHub deste chat:** arquivo `MATRIZ_CONVERGENCIA_2026-11-05.md` adicionado na branch de auditoria; as instruções do agente continuam na PR #24.
- **Último marco concluído pelo Codex:** nenhum marco totalmente comprovado; mapa de convergência relatado e persistido posteriormente; A0 parcial e A1 iniciada.
- **Working tree no Cloud:** desconhecida; não presumir mudanças locais persistentes.
- **Testes/builds da rodada:** nenhum executado conforme relato. Testes de PRs antigas não equivalem à validação da main atual.
- **Riscos P0/P1 confirmados:** nenhum confirmado; hipóteses INSP-01/02/03/04 exigem provas.
- **Primeira ação exata:** conferir commit HEAD/branch e hash canônico, ler `MATRIZ_CONVERGENCIA_2026-11-05.md`, então executar o primeiro teste sintético focalizado com prazo (`tool/run_bounded_audit.sh`) ou usar GitHub Actions sem publicação. Não repetir a comparação das quatro PRs salvo mudança na base.
- **Bloqueio:** proxy no git fetch e conector na sessão anterior; usar checkout disponível, API GitHub ou análise estática, com uma tentativa justificada por bloqueio.

## 2026-11-06 UTC — A0 concluído / A1–A2 em investigação
- HANDOFF e matriz persistidos foram lidos, sem repetir comparação das PRs.
- HEAD remoto inicial confirmado pela API: fed565e7062b03ba70345ee5fe8570c9b6ec1564; árvore d9b6b02535037c76dd4532ab9bfa096086f97637. Compare por SHA comprova somente documentação e wrapper além de main 5ec0a70. Código Cloud equivale à base auditada.
- Flutter 3.44.0 / Dart 3.12.0: wrapper sdk, status 0, 1s.
- SHA-256 inicial confirmado: 9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd; 31 perguntas sem alterações.
- Comando: bash tool/run_bounded_audit.sh storage-baseline 180 flutter test --no-pub test/storage_service_test.dart test/storage_recovery_test.dart test/consent_gate_test.dart. Bloqueado em 3s pelo sandbox (socket loopback errno 1), nenhum teste executado.
- Única retentativa justificada: mesmo comando com permissão adicional de rede do sandbox, label storage-baseline-retry, status 0, 4s, **22 testes aprovados**. Fixtures SharedPreferences; nenhuma chamada produtiva.
- git fetch limitado a 30s falhou em menos de 1s por proxy:8080; sem retentativa. API GitHub usada para leitura e commits remotos, sem push na main.
- Próximos marcos: teste dinâmico dos handlers Edge com SDK/fetch falsos; testes adversariais locais e fronteira Flutter/UBS. Serviços e políticas implantadas continuam NÃO VERIFICADOS.

## HANDOFF A0 — histórico
- Último commit remoto anterior ao marco: fed565e7062b03ba70345ee5fe8570c9b6ec1564; checkpoint A0 identificável pelo commit docs(audit): confirmar baseline Cloud e 22 testes offline.
- Local: branch de auditoria sobre main com documentos espelhados; não fazer push desse histórico divergente. Commits publicados pela API sobre HEAD remoto com lease.
- Testes: 22 aprovados (4s); hashes originais. Bloqueios resolvidos: socket por permissão; git pelo uso da API.
- Primeira tarefa: criar tool/test_edge_security.mjs para executar handlers reais com Deno.serve/env, createClient e fetch simulados; testar chave pública sem sessão, papéis paciente/equipe/admin inativo e efeitos privilegiados. Não acessar produção.

## 2026-11-06 UTC — A1a concluído: fronteira Edge / P0 mínimo
- SEC-01 comprovado: admin inativo recebia 200/202 e acionava service-role em remoção/processamento. Dois testes de autorização falharam antes (<1s); patch mínimo exige active===true. Depois: edge-after, 24 testes aprovados, 1s, deadline 60s.
- SEC-02/03 comprovados no handler, sem alegação sobre implantação: chave pública sem identidade aciona provedor; diagnóstico interno volta ao caller. Caracterizações reproduzíveis, correções remetidas à Janela B.
- SDK Deno não instalado: Node 24.19.0 executa handlers TS reais com stripTypeScriptTypes/VM, sem rede e sem secrets reais. Runner filho bloqueado; única retentativa justificada --test-isolation=none funciona.
- Documentação Supabase consultada pelo search_docs: API keys e Securing Edge Functions confirmam distinção chave pública/identidade. Changelog via curl bloqueado no proxy (<1s), sem repetição. Nenhuma assinatura/API de produto foi migrada.
- Próximo: armazenamento adversarial e fronteira Flutter/UBS. Código remoto/RLS continua não verificado; nenhum deploy.

## HANDOFF A1a — histórico
- Checkpoint anterior remoto: 7b0c3dcd785391ce3f5f6b488fbc92d07893a74e. Commit deste marco: fix(security): recusar administradores inativos nos handlers de documentos.
- Comandos/resultados: storage baseline 22/22 (4s); edge antes 2 falhas esperadas (<1s); edge depois 24/24 (1s). Logs em /tmp, fora do Git. SEC-01 corrigido na branch, SEC-02/03 abertos.
- Limite: nenhuma política implantada, autenticação JWT real ou isolamento remoto entre UBS foi exercitado. Sem produção, merge ou publicação.
- Primeira tarefa exata: criar test/security_storage_audit_test.dart e executar com wrapper 180s e permissão de rede do sandbox; verificar dados UBS legados após revogação, escrita recusada, concorrência de dúvidas para consulta e persistência legível.

## 2026-11-06 UTC — A1/A2/A3 concluídos no escopo dirigido
- Segurança: 24 testes Node de handlers; SEC-01 corrigido na branch; SEC-02/03 abertos. Checkpoint remoto 61c07fdc67d938c385c2e5249b14361265bb7896; comentário #21 ID 6674964673.
- Privacidade/storage: 5 caracterizações aprovadas em 3s, wrapper 180s. SEC-04 legibilidade, SEC-05 falsa durabilidade, SEC-06 corrida de pendências, SEC-07 resíduo legado. Dados e retenção mapeados em SEGURANCA_JANELA_A_2026-11-06.md.
- Fronteira de auth: 5 testes aprovados em 5s, wrapper 180s. Perfil local adulterado sem sessão não abre admin/UBS; histórico exige sessão; fila depende do servidor (SEC-09 não verificado). SEC-08 comprovado: FAQ bundled espera HTTP parado.
- Única retentativa do arquivo auth-boundary (inicial 7s, 2 falhas de fixture): rootBundle.clear para cache da fake-zone e HTTP response.request explícito corrigiram o harness. Não foram falhas de produto escondidas nem remoção de testes.
- Consulta/FAQ offline existentes: 5 aprovados em 5s, wrapper 180s; adiar não inventa resposta. Sem repetir 22 testes já válidos de storage/consentimento.
- Analyzer dos dois testes novos: inicial 12s detectou anonKey obsoleto no fixture; corrigido para publishableKey; única retentativa 10s sem apontamentos (prazo120s).
- Total distinto: **37 Flutter + 24 Node = 61**. Caracterizações verdes comprovam riscos ainda abertos. Não confundir com regressão completa ou homologação real.
- Hash final do questionário: 9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd (inalterado). Sem mudanças em assets, textos clínicos, termos, PDFs ou telas de produto.

## 2026-11-06 UTC — A4 / transição planejada para B
- Ranking e plano reproduzível em ACHADOS.md e SEGURANCA_JANELA_A_2026-11-06.md; sem repetição das quatro PRs. Não emitir PARECER_FINAL antes de B.
- Gate remoto: não há prova de RLS, ACLs da visão, JWT, isolamento A/B, revogação concorrente nem vínculo real. Catálogo/migrations sanitizados de homologação necessários para teste fiel; não reconstruir SQL ausente para alegar segurança.
- Fora desta Janela A dirigida: segredo histórico/assinatura, parser/upload completo, PDF/TTS/acessibilidade nativa, dependências/licenças, suíte/builds e benchmarks. Não estão aprovados por estes testes; incluir no gate B.

## HANDOFF atual — iniciar B sem retrabalho
- Branch remota: audit/codex-final-petita-20261104. **Último commit de código, testes e diagnóstico: 476cada438754d302afd52dc94f04bad76a38d01**. Patch SEC-01: 61c07fdc67d938c385c2e5249b14361265bb7896. O commit seguinte atualiza somente este HANDOFF, sem invalidar testes.
- Local: histórico separado sobre main porque proxy bloqueia fetch. Não fazer push local. Conteúdos publicados via árvore/commit GitHub com expected_sha, preservando o histórico remoto.
- Testes e duração: tabela completa no relatório; 61 verificações distintas. Logs só em /tmp. Nenhuma instalação nova, produção, merge, deploy, APK/site ou dados reais.
- P0 condicional SEC-01 corrigido no fonte, mas não implantado/homologado. P1 SEC-02/03/04/05/08 abertos; P2 SEC-06/07; SEC-09 não verificado. Usar assistencialmente continua sem evidência suficiente.
- **Primeira tarefa exata de B:** conferir HEAD/working tree e ler ACHADOS SEC-05. Converter as duas caracterizações de escrita rejeitada em testes de contrato (erro explícito + preservação após reload), executar `bash tool/run_bounded_audit.sh storage-before 180 flutter test --no-pub test/security_storage_audit_test.dart`, aplicar patch mínimo de persistência e UX de erro e testar novamente. No Cloud, usar permissão adicional de rede do sandbox para socket local. Não repetir matriz/22 testes baseline enquanto não forem invalidados por patch.
- Depois: SEC-08 (orçamento de rede/fallback local), SEC-03 (erro público genérico) e política/quotas SEC-02; desenhar migração SEC-04 sem perda. Atualizar caracterizações para contratos de segurança quando corrigir, em commits pequenos. Regressão completa/builds/performance medida e parecer ficam em B.
- Se git falhar: não retentar sem causa nova; API GitHub já funcionou para commits 7b0c3dc/61c07fd e comentários #21 IDs 6673524855/6674964673. Não alterar produção para preencher a lacuna SEC-09.
- Acompanhamento A1–A4 publicado em #21, comentário 6675453775. Estado local antes deste HANDOFF: commit 103c730, sem mudanças pendentes de código; o ajuste deste arquivo será commitado separadamente. Histórico local difere do remoto por espelhamento inicial, não enviar com push.


## Janela B — B0 / SEC-05 (2026-11-06)
- Retomada exata e90bca6; fetch com permissão adicional de rede funcionou em <1s. Checkout alinhado ao histórico remoto; branch local anterior preservada em audit/local-janela-a-checkpoint. Hash inicial 9dbc0cee…4678dd, inalterado.
- SEC-05: três contratos negativos falharam antes (sec05-before, 3s); depois 3 aprovados (sec05-after, 2s). Escritas/remoções verificam bool e recarga do backend; falha recarrega o estado anterior e lança erro seguro. Isso não prova fsync/sobrevivência a perda de energia.
- UI não avança pergunta/confirmacão quando persistência falha; conserva texto digitado e mostra tentativa novamente. Notas, perfil, consentimento, preferências e exclusão usam tratamento explícito. Analyzer focal sem apontamentos (11s).
- Próximo: SEC-06/07 para serialização das operações e eliminação de resíduo legado, depois disponibilidade FAQ/RAG. Regressão final invalidada pelo patch de storage será executada no gate B3.

## B1 — SEC-06/07
- SEC-06/07: 2 contratos falharam antes (3s). Mutações compartilham fila por processo, inclusive clear/revogação e instâncias distintas; falha não contamina a fila. Revogação remove também ubs_questions, sem apagar catálogo/documentos.
- Teste UI SEC-05 passou (9s), mantendo edição e negando confirmação falsa. Próximo: FAQ com orçamento de rede e RAG com negação por padrão/erros públicos seguros.
- SEC-06/07 validação: primeira suíte atingiu TIMEOUT180s no widget por Future estática de outra zona de teste. Correção concreta: liberar cauda da fila quando ociosa antes de concluir ao chamador. Única retentativa sec0607-retry: 7 testes aprovados em4s, incluindo erro/recarga, concorrência, revogação e UI.
