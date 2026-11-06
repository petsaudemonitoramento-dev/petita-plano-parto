# Parecer técnico final — Petita / Janela B, 2026-11-06 UTC

**Decisão para documentação representativa de software: GO COM RESSALVAS. Decisão para uso assistencial, dados reais e distribuição: NO-GO.** O núcleo offline e as correções podem compor documentação técnica de registro, explicitando limitações. Isso não autoriza uso clínico, publicação, integração das PRs ou envio ao NITT/INPI. Nenhuma submissão foi feita.

Fonte candidato: **d34f4a33e8e9e098ec87730a08feff28218661da**, branch audit/codex-final-petita-20261104, versão0.3.0+21. Relatórios posteriores a esse commit só registram evidências, sem mudar código do candidato. Issue#21 / PR#24 permanecem para revisão humana; sem merge/main/deploy. Execução somente Codex Cloud e GitHub Actions, dados fictícios/mocks.

## Correções e rastreabilidade

| Achado | Resultado no fonte / commit | Antes → depois |
|---|---|---|
| SEC-05, P1: falsa durabilidade |2638d67: retorno/recarga verificados; cache rejeitado recarregado; UI conserva edição, nega confirmação/avanço |3 contratos falharam(3s)→3 passaram(2s), widget de notas passou(9s) |
| SEC-06, P2: disputa de pendências |cc855f2 +9899fd4: fila por processo e liberação ociosa |contrato falha antes; suíte dirigida7/7 depois(4s). Primeira tentativa atingiu TIMEOUT180s; causa e retentativa registradas |
| SEC-07, P2: resíduo UBS legado |cc855f2: revogação remove ubs_questions sem apagar catálogos |contrato falha antes→passa na suíte dirigida |
| SEC-08, P1: FAQ aguarda rede parada |e06abae: orçamento600ms por etapa e fallback local, prioridade de curadoria preservada |contrato200ms falha→fixture20ms passa(4s); mediana sintética902→602ms |
| SEC-03, P1: diagnóstico interno RAG |8329534: erro público fixo e503 |contrato falha→passa, <1s |
| SEC-02, P1: consumo anônimo RAG |805e3c6: desativado por padrão; opt-in exige identidade/perfil ativo/quota persistente fail-closed |8 contratos falharam→31 testes Edge passam. **Contenção, não serviço reativado/homologado** |
| SEC-01, P0 condicional |61c07fd da A preservado: admin inativo/null/ausente negado antes de efeitos privilegiados |regressão incluída nos31 testes Node de B; sem deploy |
| INSP-05, P2: versão incorreta |d34f4a3: AppInfo/README/rodapé0.3.0/build21 e online não homologado |divergência visual confirmada; metadados corrigidos |
| PDF, desempenho medido |4a08756: cache proporcional de logos600px, assets originais intactos |14 regressões PDF passaram(11s); comparação controlada abaixo |

## Gates e limites da prova

| Gate / prazo externo | Evidência |
|---|---|
| dependências travadas /300s |pub get --enforce-lockfile aprovado; image4.9.1 já transitiva, agora direta sem pacote/versão novos |
| analyzer /180s |final-analysis sem apontamentos16s; CI final abaixo |
| regressão Flutter /480s |102 testes passaram em84s antes da otimização PDF;14 afetados passaram após. Candidato final:104/104 em63s (final-regression, inclui benchmarks). |
| segurança Node /60s |31/31 aprovados em1s, incluindo SEC-01/02/03; sem rede/segredos reais |
| Web release /900s |pré-PDF aprovado60s. Candidato final aprovado60s (final-web). |
| Android debug /900s por build |APROVADO em Actions42157900741: build274s, job5min31s; scaffold/analyzer/TTS/artefato verificados, nenhum APK publicado. |
| questionário |31 itens; hash inicial/final9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd. Nenhum byte alterado |
| PDF |estrutura/texto/31 respostas/acentos/conteúdo longo/opt-in/compartilhador mock validados; inspeção visual sintética confirma logos legíveis |
| Android físico/upgrade/TalkBack/rotação |NÃO HOMOLOGADOS. Widgets responsivos/escala não substituem aparelho |

Gates do candidato: [Flutter/Web/Node42157900727](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/42157900727) e [Android42157900741](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/42157900741), ambos aprovados.

Os pipelines agora têm timeout por comando, job25min e cancelamento de revisões substituídas; não fazem upload/publicação de APK. CI intermediário4a08756/9691f86 falhou no analyzer pelo benchmark em tool/ usar API de testes. Corrigido movendo para test/benchmarks/, sem suprimir alerta; única correção desse bloqueio. Cancelamentos de execuções substituídas não contam como aprovação. Builds não exercitam JWT/RLS ou serviços reais.

## Métricas

Cloud Linux x86_64,3 CPUs reportadas, Flutter3.44.0/Dart3.12.0 em modo de teste. Mesmo fixture,5 repetições; PDF comparado sequencialmente sem outros builds locais. Detalhes em METRICAS_2026-11-06.md.

| Medida | Antes | Depois |
|---|---:|---:|
| FAQ com atraso HTTP sintético900ms, mediana5 |902ms|602ms(-33,3%) |
| PDF cold, amostra única informativa |2103ms|1981ms |
| PDF com cache, mediana4 |1789ms|155,5ms(-91,3%) |
| Tamanho do PDF31 respostas,5 medições por cenário |716915|396162(-44,7%) |

O custo medido vinha de logo4520x4500 usado pequeno no PDF. image4.9.1 já existia na árvore; cache reduz só a representação em memória. Após corrigir metadados de versão no candidato final, smoke da suíte mediu396355bytes por PDF e warm159ms; comparação controlada acima refere-se ao patch4a08756, antes dessa correção de rodapé. Não extrapolar para FPS/startup/aparelho. Inicialização nativa, pico de memória, navegação/TTS e tamanho ARM64 antes/depois NÃO MEDIDOS; não houve refatoração desses fluxos por suposição.

## Riscos residuais e decisão por superfície

| Superfície | Decisão / pendência |
|---|---|
| Núcleo offline, consulta e PDF com fixtures |GO COM RESSALVAS para teste fictício/revisão do fonte; serviços online não homologados não devem ser usados com dados reais |
| Integridade local |SEC-05/06/07 corrigidos no escopo testado. SharedPreferences não garante fsync; fila não é lock entre isolates/abas; exclusão multi-chave não é transação atômica |
| Confidencialidade local |**SEC-04 P1 ABERTO**: texto/JSON legível; SEC04_PLANO_CIFRAGEM.md detalha migração compatível, Keystore, journal, crash/restore/downgrade e decisão Web. Não implementar migração destrutiva sem homologação |
| Autenticação, RLS e isolamento UBS |**SEC-09 NÃO VERIFICADO**, gate para dados reais. Catálogo/visão/RPCs implantados incompletos no repositório. Mock A+B não prova vazamento nem isolamento real |
| Neon Auth/Google Flutter |Integração não concluída/comprovada; cliente ainda usa Supabase legado. Não confundir provisionamento com login funcionando |
| RAG |Fonte nega por padrão. RPC consume_petita_rag_quota não criada/aplicada; ausência/erro nega. Reativação bloqueada até contrato e testes de RAG_REATIVACAO.md. Implantação antiga não alterada nem declarada segura |
| Documentos/admin |SEC-01 corrigido no fonte; gateway, visibilidade de perfil, sessões reais, parser/upload/quotas de Storage continuam sem homologação completa |
| Assinatura/upgrade Android |Debug gerado por scaffold temporário, sem assinatura institucional ou prova de upgrade. PR#16 ainda pendente. Certificados/packageId/backup de instalações antigas exigem homologação; não recomendar desinstalar |
| Supply chain/licenças |100 dependências inventariadas, versões/lock/arquivos de licença identificados. flutter_markdown descontinuado: manutenção P2. Actions ainda usam tags maiores, não SHAs imutáveis; nenhum upgrade amplo foi feito sem avaliação |
| Segredos/histórico |Padrões limitados no pacote candidato não encontraram credencial privilegiada. Não equivale a varredura forense de todo histórico, Actions artifacts ou segredo em runtime |
| Clínica/LGPD/titularidade |Revisão humana necessária. Texto clínico, termos e31 perguntas preservados; CI verde não valida adequação assistencial, anonimização irreversível ou conformidade jurídica |

## PRs pendentes

Usar MATRIZ_CONVERGENCIA_2026-11-05.md sem repetir análise: #15→#17 são fundação/operações dependentes; #16 Android em eixo próprio preservando TTS/versão; #19 fornece referências HTTP/JWT, com esquema concorrente a reconciliar. Nenhuma integrada. Antes de promoção: um backend de referência, fixtures reais de autorização isolada sem owner/BYPASSRLS, tokens inválidos/expirados, revogação concorrente, gestantes/equipes A/B, admin sem conteúdo clínico e upgrade Android compatível. Nenhum teste contra banco produtivo nesta auditoria.

## Inventário e congelamento NITT/INPI

INVENTARIO_TECNICO.json registra versão, lockfile, extensões e100 dependências, origem/escopo/hash das licenças disponíveis. PACOTE_CANDIDATO.json registra cada arquivo/hashes do ZIP de revisão e limites do scanner. Essas evidências não atribuem direitos sobre marcas/fontes/código de terceiros; autores, contribuições e titularidade institucional dependem de confirmação humana.

Candidato de revisão gerado inteiramente no Cloud: Petita_codigo_candidato_d34f4a3.zip,2390645 bytes, SHA-256 **147bca9b923dfcbb082ca34c1b317e4f77ffea3e6ec07d3f9d85cc3ec17aac39**. É hash dos bytes desse ZIP, **não hash definitivo de pacote submetido**. Fonte d34f4a3, escopo lib/assets/supabase/pubspec/test/tool/.github/README, sem .git/build/cache/keystores/ambiente. Nenhum envio ocorreu.

Procedimento: revisar PR#24/parecer/escopo e direitos com responsáveis; resolver ressalvas conforme finalidade; escolher commit imutável/tag após aprovação; gerar pacote representativo a partir desse commit com allowlist explícita; inventariar arquivos/licenças; revisar segredos sem imprimir valores; calcular SHA-256/nome/tamanho sobre os bytes finais; verificar independentemente e guardar pacote imutável junto ao relatório. Qualquer alteração de bytes exige novo hash. Assinatura/certificado APK é artefato separado. Não reutilizar hash antigo nem submeter/publicar sem autorização.

Rollback: patches ainda só na branch, sem migração de banco. Retornar ao candidato anterior por PR/revert revisado, preservando chaves legadas; não reabilitar RAG/anular SEC-01 por conveniência. Para futura cifragem, seguir journal/compatibilidade e nunca apagar chave/envelope silenciosamente. Restaurar fonte não restaura dados excluídos.

## HANDOFF

Último commit de código candidato:d34f4a33e8e9e098ec87730a08feff28218661da. Demais commits de relatório não invalidam esse gate. Pendências prioritárias: SEC-04; SEC-09; implementação/homologação da quota persistente antes de RAG; upgrade/assinatura e validação clínica/jurídica. Primeiro comando de retomada: `git status --short --branch` e ler o bloco final de PROGRESSO.md; não repetir benchmarks/gates válidos se só documentação mudou. Sem produção, merge, publicação ou envio ao NITT/INPI.
