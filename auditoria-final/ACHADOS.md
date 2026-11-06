# Achados técnicos — auditoria final Petita

**Estado em 2026-11-06 / A0:** 22 testes existentes de storage/recuperação/consentimento aprovados (4s, wrapper 180s). Hipóteses de backend ainda em investigação. Nenhum resultado de mock comprova configuração implantada.

## Achados comprovados na retomada (2026-11-06)

### SEC-01 — P0 condicional: administrador inativo alcança operações privilegiadas
- CONFIRMADO no código executado com fixtures: handlers delete-support-document/index.ts:33–34 e process-support-document/index.ts:37–41 selecionavam somente role, ignorando active. Sessão válida e perfil legível com role=admin/active=false obtinham 200 (remoção) e 202 (processamento), com criação de cliente service-role. Permite alterar/remover base educativa após desativação da conta, se perfil continuar legível e sessão válida.
- Impacto e condição: autorização sensível contornada no handler. Visibilidade real do perfil inativo/RLS e validade de sessão no ambiente implantado NÃO VERIFICADAS; não afirmar exploração produtiva. Teste não simula banco nem valida tokens criptográficos.
- Reprodução antes: wrapper edge-authorization-before 60, Node 24.19.0, --experimental-vm-modules --test-isolation=none --test --test-name-pattern='inactive admin' tool/test_edge_security.mjs: **2 falhas**, 200/202 em vez de 403, <1s.
- CORRIGIDO somente na branch: selecionar role, active e exigir active===true antes do cliente privilegiado. Ausente/null também negados. Chamada interna service-role do processador mantém contrato existente, ainda exige credencial de servidor (não testada aqui).
- Depois: wrapper edge-after 60, **24 testes aprovados, 1s**; pacientes/equipes A e B/metadados adulterados/admins inativos negados sem efeitos privilegiados. Admin ativo preservado. Sem deploy: instância remota permanece não verificada.

### SEC-02 — P1: RAG publicável aciona provedor sem identidade/limite no handler
- CONFIRMADO em ask-petita-rag/index.ts:17–27 e config.toml:5: apenas apikey é verificada. Fixture com chave pública e nenhum Authorization faz três chamadas aceitas, três embeddings e zero verificações de usuário. Entrada sintética enviada ao fetch externo simulado.
- Limites: chave pública não é segredo; endpoint educativo público pode ser intencional. Falta de quota no handler permite abuso de custo e transmissão não autenticada; WAF/quota externos NÃO VERIFICADOS. Não provado vazamento de documentos privados nem de pacientes.
- Teste de caracterização no arquivo Edge aprovado confirma o risco presente; não é gate que prova correção. Falta/wrong key e questão >1500 não acionam provedor.
- Janela B: definir política público/autenticado e quota persistente adequada; testar abuso com fixtures. Não improvisar login nem alterar textos clínicos.

### SEC-03 — P1: diagnóstico interno retornado no RAG
- CONFIRMADO em ask-petita-rag/index.ts:65–66,174–175: falha sintética de fetch retorna mensagem interna no JSON ao chamador, status 200. Teste injeta fixture-internal-diagnostic e detecta marcador sem copiar dados reais.
- Risco: detalhes de provedor/configuração podem chegar ao cliente; nenhum segredo real exposto no teste. Janela B: erro público genérico, telemetria mínima sem payload, regressão negativa. Caracterização atual permanece explicitamente nomeada.

## Escopo dos testes de handlers
Node executa TypeScript real com remoção de tipos via stripTypeScriptTypes e VM; apenas import do SDK, Deno.env/serve, fetch e storage são mocks. Nenhum request sai da VM. Node test runner em subprocesso foi bloqueado pelo sandbox; única retentativa em processo (--test-isolation=none) resolveu. Um ajuste do assert de erro acomodou prefixo Error: entre realms; não foi retentativa de erro do produto. Parsing/embedding de arquivos, gateway JWT e RLS do banco não estão simulados como prova de segurança.

### SEC-04 — P1: dados de saúde sem cifragem na camada do app
- CONFIRMADO: StorageService:23–25,66–68,141–143 escreve JSON/texto legível no SharedPreferences. Teste security_storage_audit: resposta/notas sintéticas recuperadas diretamente pelas chaves. Exige acesso ao storage do dispositivo para explorar; não provada leitura por outro app, backup ou ausência de criptografia de disco.
- ABERTO para B: modelo de ameaças, storage cifrado com migração compatível, proteção de chaves/backup e recuperação. Não apagar dados existentes nem chamar cifragem do SO de cifragem do app.

### SEC-05 — P1: gravação rejeitada é reportada como sucesso
- CONFIRMADO: StorageService:23–25,66–68 ignora retorno bool de setString. RejectingWrites devolve false: saveAnswers/saveConsultationNotes completam normalmente; resposta fica no cache, mas reload mostra perda. Dois testes adversariais reproduzem; não houve falha real de disco nem dados reais.
- ABERTO para B, alta prioridade offline: checar retorno/falhas em escritas e remoções, propagar erro tratável ao usuário; preservar estado anterior e evitar falsa confirmação no cache. Testes negativos deverão esperar erro e conservação de dados após reload. Não basta lançar sem tratar UI/caches.

### SEC-06 — P2: corrida entre marcações para consulta
- CONFIRMADO no serviço, StorageService:47–58: Future.wait de defer(a)/defer(b) resulta em apenas um ID. Teste usa duas operações concorrentes, sem scheduler artificial. Impacto: perde pendência de consulta, não cria resposta falsa.
- ABERTO para B: serializar read/modify/write, incluindo remoção e clear. Concorrência real por gesto/rota não reproduzida; não afirmar perda de resposta clínica no fluxo normal.

### SEC-07 — P2: revogação preserva dúvidas UBS do storage legado
- CONFIRMADO, StorageService:129–138 versus164–175: fixture grava UbsQuestion, revoga ciência e recarrega; texto permanece em ubs_questions. API não tem uso nas telas atuais segundo rg; pode importar para instalações anteriores, cuja existência/conteúdo não foram inspecionados.
- ABERTO para B: limpar a chave legada na revogação sem apagar dados institucionais/documentos. Testar somente chaves pertinentes. Texto atual da UI promete perfil/plano; não alegar descumprimento de exclusão remota nem vazamento atual.

### SEC-08 — P1: resposta local da FAQ aguarda HTTP parado
- CONFIRMADO em FaqSearchService:19–23,67–71: há resposta bundled, mas search espera _searchOnlineCurated sem prazo antes de entregá-la. Mock HTTP pendente por 80ms impede resultado; completar resposta vazia libera resposta local. Não se mediu timeout do sistema/provedor nem desempenho em aparelho.
- ABERTO para B: preservar prioridade clínica/curadoria com orçamento de rede e fallback local; reproduzir falha antes e prazo após. Teste existe em security_auth_boundary_test. Não trocar conteúdo ou remover curadoria sem avaliar contrato.

### SEC-09 — UNKNOWN: isolamento UBS e autorização do backend implantado
- NÃO VERIFICADO: SupabaseService:259–267 usa select * em team_questions_anonymous; servidor deve filtrar e projetar dados. Mock devolvendo A+B chega como A+B. Isso só comprova fronteira do cliente, não falha real de RLS.
- Definição da visão e corpos de submit/respond não encontrados nos SQL de main; patches não constituem snapshot completo implantado. Sem fixtures de banco autoritativas não simular policies inventadas. Plano de testes negativos em SEGURANCA_JANELA_A_2026-11-06.md.
- Testes de áreas Flutter: perfil local adulterado admin/ubs_team não desbloqueou UI sem sessão; histórico sem sessão recusado antes de HTTP. Esses resultados não validam JWT/RLS reais, IDOR ou privilégios em produção.

## Ranking para a próxima janela
1. SEC-01: patch P0 condicional na branch, sem deploy; ainda requer homologação isolada. Não declarar proteção da implantação.
2. SEC-05, SEC-02/03 e SEC-08: P1 reproduzidos e testes prontos. SEC-04: P1 que exige desenho de migração seguro, não troca abrupta.
3. SEC-06/07: P2 limitados ao serviço/legado, patches pequenos possíveis sem reconstrução.
4. SEC-09: gate indispensável para dados reais; resultado desconhecido não pode virar GO por CI verde.

Evidência completa de fluxos de abuso, dados/retenção, comandos, limites e 61 verificações em SEGURANCA_JANELA_A_2026-11-06.md. Hash do questionário inicial/final idêntico. Builds, suíte completa e benchmark ficam para B.

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

## Atualização B — SEC-05
CORRIGIDO na branch: setString/setStringList/remove têm retorno e estado recarregado verificados. Erros normalizados sem payload; cache rejeitado não se apresenta como salvo. UI mantém edição e não mostra sucesso/avanço. Testes negativos de resposta e notas: 3 falhas antes (3s), 3 aprovados depois (2s), prazo180s. Persistência sujeita às garantias do plugin/SO, sem alegação de fsync. Serialização será tratada em SEC-06; remoções de múltiplas chaves não são transações atômicas.

## Atualização B — SEC-06/07
CORRIGIDOS na branch: operações locais serializadas, inclusive limpeza/revogação, e chave UBS legada removida na revogação. Dois testes falharam antes (3s); suíte dirigida de storage validará o conjunto após patch. A fila é por processo/isolate; não é lock entre múltiplos isolates ou abas Web. Exclusão de múltiplas chaves continua não atômica; erro impede confirmação falsa de conclusão.
SEC-06/07 confirmado depois: 7 testes aprovados em4s na única retentativa após liberar a fila ociosa. Primeiro comando atingiu TIMEOUT180s; não foi contado como aprovado. Usar esta correção com cc855f2.

## Atualização B — SEC-08
CORRIGIDO: espera da busca curada e do RAG limitada por orçamento600ms cada. FAQ local não espera indefinidamente. Antes: contrato200ms falha; depois orçamento20ms no fixture passa (4s de comando). Future.timeout limita espera, não cancela requisição em andamento. Sem mudança de textos/curadoria; serviço remoto continua não homologado.

## Atualização B — SEC-03
CORRIGIDO: catch do RAG retorna503 com erro público fixo; diagnóstico de provedor não sai no JSON. Um contrato falha antes/passou depois, <1s, limite60s. Falha de geração ainda utiliza fallback documental existente; revisão clínica não inferida.

## Atualização B — SEC-02
CONTIDO NO FONTE: RAG externo desligado por padrão. Reativação exige token validado, perfil ativo e quota persistente obrigatória, falhando fechado na ausência/erro. Não há RPC de quota entregue/implantada; não declarar serviço operacional nem quota homologada. Oito testes falharam antes;31 Node aprovados depois (<1s), com regressão SEC-01/03. Contrato e bloqueio em RAG_REATIVACAO.md. Serviço remoto continua NÃO VERIFICADO.

## Atualização B — SEC-04
P1 ABERTO, com plano detalhado e bloqueio em SEC04_PLANO_CIFRAGEM.md. Migração/backup/Keystore/Web e upgrade com assinatura histórica não homologados. Não houve substituição destrutiva nem alegação de cifragem implementada. Impede GO assistencial; documentação de registro pode explicitar esse limite.

## B2 — gargalo medido de PDF
CORRIGIDO: decodificação repetida de logo4520x4500 para exibição pequena. Cache proporcional600px: warm mediana1789→155,5ms; PDF716915→396162bytes;14 testes PDF aprovados(11s). Métricas Cloud debug, não de telefone. Sem alteração de assets originais/conteúdo clínico. Ver METRICAS_2026-11-06.md.

## INSP-05 — P2 confirmado e corrigido
AppInfo e README exibiam0.2.0-beta/build20 enquanto pubspec define0.3.0+21. Visível no rodapé do PDF sintético. Metadados agora0.3.0/build21/novembro2026 e sem alegação de RAG/UBS homologados. Não houve mudança clínica. CI final valida o fonte com benchmark no diretório de testes apropriado.
