# Progresso auditável — Petita / Codex

**Status global:** JANELA A EM ANDAMENTO — retomada Cloud em 2026-11-06, A0 confirmado e 22 testes focalizados aprovados. Histórico anterior abaixo; resultados novos ao final.
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

## HANDOFF atual — A0
- Último commit remoto anterior ao marco: fed565e7062b03ba70345ee5fe8570c9b6ec1564; checkpoint A0 identificável pelo commit docs(audit): confirmar baseline Cloud e 22 testes offline.
- Local: branch de auditoria sobre main com documentos espelhados; não fazer push desse histórico divergente. Commits publicados pela API sobre HEAD remoto com lease.
- Testes: 22 aprovados (4s); hashes originais. Bloqueios resolvidos: socket por permissão; git pelo uso da API.
- Primeira tarefa: criar tool/test_edge_security.mjs para executar handlers reais com Deno.serve/env, createClient e fetch simulados; testar chave pública sem sessão, papéis paciente/equipe/admin inativo e efeitos privilegiados. Não acessar produção.

