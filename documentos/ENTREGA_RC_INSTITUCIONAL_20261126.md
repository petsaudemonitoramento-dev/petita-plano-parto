# Entrega incremental institucional — 26/11/2026

**Decisão: NO-GO para candidata aprovada/produção/uso assistencial.** Há implementação efetiva e builds de homologação, mas a suíte Flutter ainda reprova dois testes de tela autenticada e faltam validações remotas e físicas. Não houve merge, publicação, alteração de produção, uso de dados reais ou mudança de configuração externa.

Código do aplicativo: `89aa1605257ea0c16771d9bd9cd365d3a2837104`. Tooling portátil: `eee959873f17c32f8eb0483df04a0f555f1c48a9`. PR rastreável: [#28](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/pull/28). Os commits partem de `fc554711`, última referência confirmada no início. Main não foi alterada.

## Implementação entregue

| Item | Estado e limites |
|---|---|
| Cadastro/login/verificação/recuperação de senha Neon | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO real. Flutter Web usa SDK oficial local; Android/iOS usam REST documentado, com suporte Bearer nativo ainda a confirmar. Sem Google ou login simulado no produto. |
| Sessão, JWT fresco, expiração e logout | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO real. Cofre nativo, senha/OTP/JWT não persistidos pelo transporte; resposta tardia de token é recusada após logout. JWT já emitido pode continuar válido até expirar; revogação individual imediata no backend permanece aberta. |
| Consentimento versionado | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO real. Cinco aceites locais e seis escolhas online, inicialmente desmarcadas; grant/withdraw distintos, sem inferência. Documentos e versão institucional preservados. Revisão LGPD/jurídica pendente. |
| Plano local, sincronização e recuperação | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO real. Fila durável por identidade, revisão otimista, ACK confirmado, reconciliação estrita de resposta perdida, conflito sem sobrescrita e recuperação com confirmação/backup. Offline inclui edição/PDF e fila após consentimento já registrado, revalidado antes de enviar. Reconexão é verificada na área da conta/retorno ao app ou por ação manual; não há sincronização de fundo permanente. |
| Proteção local | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO de upgrade/restauração/aparelho. AES-256-GCM, nonce novo, chave separada em secure storage, leitura após gravação. Chave perdida/tag inválida bloqueiam sobrescrita. Migração mantém fonte legada: instalações antigas ainda podem conter dados em claro. Web não protege contra XSS nem acesso ao mesmo perfil do navegador. Logout mantém plano offline conforme aviso; outra conta não o envia silenciosamente. |
| UBS/perfis | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO remota. Cadastro inicial somente patient; UBS por solicitação e decisão institucional, sem papel/identidade arbitrários no cliente. Migration006 é aditiva e foi aplicada SOMENTE em PostgreSQL descartável. Administração inicial e homologação de credenciais institucionais são externas ao app. |
| Dúvidas/equipe/admin | IMPLEMENTADO, AGUARDANDO VALIDAÇÃO. Rotas ativas apontam à API canônica; perfil local não autoriza envio nem acesso profissional. Código legado preservado, sem inicializar Supabase em main. Dois testes novos de widget reprovados: ver abaixo. |
| RAG/documentos remotos | BLOQUEADO para uso assistencial; sem rotas Neon habilitadas nem reativação de legado. FAQ local e alertas existentes preservados. Fontes/ingestão/acesso remoto não homologados. |

O protocolo atual sincroniza respostas das 31 perguntas; notas de consulta e preferências opcionais de tratamento permanecem locais. Não há procedimento institucional completo de eliminação de registros remotos. Troca de conta em um aparelho com plano vinculado exige resolver/limpar explicitamente o espaço local; não há troca automática de prontuários locais.

## Evidências executadas

Todos os comandos demorados usaram `tool/run_bounded_audit.sh`. Resultados se sobrepõem; não representam soma de testes únicos.

| Verificação | Resultado |
|---|---|
| Análise Flutter | APROVADO no Cloud e no CI do código89aa160. |
| Suíte Flutter completa | REPROVADO: **142 passaram, 2 falharam**, [run45892964333](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45892964333). Falhas em `institutional_ui_test.dart`, carregamento das telas com fixture HTTP. Não suprimidas nem convertidas em aprovação. |
| Transporte API + sincronização | APROVADO:28/28,4s, incluindo timeout absoluto/aborto, fila, conflito, retirada, isolamento de conta e limpeza. |
| Sessão nativa/expiração/logout | APROVADO:6/6,5s, HTTP e cofre simulados. |
| Snapshot cifrado/migração/falhas | APROVADO:5 cenários, incluindo recusa de gravação, falta de chave, tag adulterada e limpeza de resíduo legado. Cofre simulado. |
| API/JWT | APROVADO:19 testes Node; assinatura EdDSA real com chaves fictícias, emissor/público/expiração/chave forjada. Não são tokens do Neon. [CI45892964078](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45892964078). |
| SQL/RLS/UBS | APROVADO em PostgreSQL17.6 descartável:12 cenários após migrations001–006; Auth fictício, login sem owner/BYPASSRLS. Inclui pacienteA/B, UBSA/B, profissional, admin, elevação, consentimento/revisão/aprovação/revogação. [CI SQL45892964173](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45892964173). Não valida RLS implantada remotamente. |
| Legado Edge | APROVADO:31 testes dos handlers reais com Supabase/provedor simulados; SEC-01 preservado. |
| PDF/regressão offline | APROVADO nos testes executados da suíte:31 respostas, dois formatos, texto longo, compartilhamento simulado, consulta/pronomes, navegação e persistência. Compartilhamento/aparelho reais NÃO EXECUTADOS. |
| Dependências | APROVADO no escopo consultado: npm audit=0; OSV116 pacotes Pub sem advisory retornado. Lockfiles preservados. Scanner limitado de fontes sem padrão de chave privada, URI com senha ou service-role JWT; histórico/provedores não atestados. |
| Questionário | APROVADO:31 perguntas, bytes/SHA256 `9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd`. Documentos legais e textos clínicos não reescritos. |
| Web release | APROVADO:45s, configurações públicas de homologação, bundle oficial Auth compilado, sem deployment. |
| Web navegador real | APROVADO:7s, Chromium Cloud com sandbox e perfil isolado, abertura/criação do envelope cifrado/reabertura; Auth/API indisponíveis. Isso não prova cache integral do site para primeiro acesso offline ou integração remota. |
| Fluxo autenticado em Chromium com fixtures | BLOQUEADO na automação de navegação/semântica após3 tentativas; asserções de consentimento/sync não alcançadas. Preservado em modo separado do smoke offline. Não é evidência contra o Neon real nem substitui os widgets reprovados. |
| APK Android | APROVADO build/artefato: [run45892964201](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45892964201). Build do merge efêmero `c35a255` da PR, head89aa160; sem merge na main. Identificador `br.edu.ufcg.petsaude.petita.homologacao`, debug, backup/cleartext desabilitados, sem release pública. Teste físico NÃO EXECUTADO. |
| iOS | APROVADO build/210s: [run45893413561](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45893413561), somente simulador/sem assinatura, Runner.app gerado. Primeira execução bloqueada por ausência de GNU timeout; fallback POSIX testado e apenas iOS repetido. Flutter/Linux intencionalmente não repetido nesse dispatch; não significa aprovação da suíte reprovada. Teste físico/assinatura/TestFlight NÃO EXECUTADOS. |

APK de revisão (retenção7dias): [artefato15151963680](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/45892964201/artifacts/15151963680). ZIP89850822bytes, SHA256 `ccd5baeb0edaa6c343cbd333ecc5f7f6f04905be481791009c2d943b4e96807a`. O hash refere-se ao ZIP do GitHub, não ao APK individual. Usar exclusivamente fixtures em aparelho de homologação; não desinstalar/substituir versão produtiva. A geração não autoriza distribuição assistencial.

Não houve nova refatoração de performance sem benefício comprovado. Otimização de logos/PDF e orçamento FAQ da PR24 foram reaproveitados; métricas históricas não são apresentadas como medidas da revisão atual. Tempos acima são execução de verificações/builds, não latência assistencial ou benchmark de aparelhos.

## Bloqueios e intervenção externa precisa

1. **P0 interno — testes de widget:** investigar a conclusão de streams HTTP no FakeAsync; nenhuma causa remota comprovada. Preservar as asserções de seis escolhas desmarcadas/ausência de POST implícito e de ausência de privilégios administrativos. Resolver antes de chamar a suíte aprovada. Não depende de senha/permissão do usuário.
2. **Neon Auth:** Console Neon → projeto `round-cherry-59699884` → branch `br-purple-surf-b6k7zrka` → Auth/Settings/Trusted domains. A configuração lida só autoriza a origem do projeto API; a instituição deve definir e autorizar a origem HTTPS exata do Flutter de homologação e os callbacks. Não usar wildcard. Confirmar com cadastro fictício/verificação de e-mail na caixa institucional de testes, senha/OTP fora do chat; validar sessão, recuperação e expiração em Web/Android. E-mail/senha/OTP já estavam habilitados; não foram modificados.
3. **API Vercel:** projeto `petita-api-neon-homologacao`, id `prj_36Cds5VJcPNsuWzy0YWaNG36NmM7`, Settings → Deployment Protection: SSO está em all. A instituição precisa aprovar o desenho de exposição controlada da API para clientes autenticados por JWT Neon. Não inserir bypass secret no Flutter nem desligar proteções para testar. Confirmar origem/CORS e login dedicado/TLS verify-full com acesso a petita_runtime; existência de secrets corretos NÃO foi presumida. Node do projeto foi informado como26, contrato CI/backend22: reconciliar antes de deployment autorizado.
4. **Migration006:** após revisão técnica, no SQL Editor exclusivamente da branch de homologação acima, com o papel institucional de migração já aprovado, conferir versões001–005 e aplicar `SET petita.migration_target='isolated-homologation';` seguido de `infra/neon/migrations/006_patient_ubs.up.sql`. O script exige histórico exato e transação. Não rodar na default/main/produção, não criar outro banco nem importar dados reais. Confirmar versão6 e testarA/B com identidades reais de teste/login não-owner. A sessão atual não consultou registros nem aplicou SQL remoto; aplicação001–005 consta do histórico anterior e não foi reatestada aqui.
5. **Deployment de autenticação:** bloqueio anterior permanece. Nenhuma tela deve ser publicada para solucionar os itens acima sem liberação explícita da instituição/usuário. `git.deploymentEnabled=false` permanece nos manifests. Builds e servidor de teste loopback não foram deployments.
6. **Proteção local/LGPD:** homologar atualização sem perda, restore/backup/Keychain/Keystore e remoção verificada do resíduo legado. Revisar retenção, revogação, pedidos de titulares, conteúdo dos termos e compartilhamento de PDF com responsáveis clínico/jurídico/encarregado. Não apagar cópias antigas de maneira automática/destrutiva.

Gravidade de liberação: **P0** para suíte autenticada reprovada, ausência de prova de Auth/JWT/RLS/isolamento remoto e desenho de acesso à API; **P0 a resolver/mitigar** para revogação individual de JWT e validação da sessão nativa; **P1** para resíduo legado, backup/upgrade/aparelhos e distribuição assinada; **P2 indisponível** para RAG/documentos. Nenhuma dessas pendências está aprovada por um teste de fixture.

## Continuidade, instalação e integração

No Codex Cloud, ler `documentos/RETOMADA_RC_20261126.md` e este arquivo. Não repetir comparação das PRs nem auditorias A/B. O fonte de #28 consolida migrations de #15/#17, correções selecionadas de #24, manifesto de #25 e linha de Auth/API de #26/#27. PRs continuam abertas e exigem revisão de sobreposição antes de integração; nenhuma foi mesclada automaticamente.

Builds reproduzíveis exclusivamente Cloud/Actions: instalar dependências travadas, `npm run --prefix backend build:flutter-auth` antes de `flutter build web --dart-define-from-file=config/homologacao.json`; todos com wrapper180/480/900s. APK pelo workflow `validar_apk_tts.yml`; scaffolds são efêmeros e o helper aplica o identificador de homologação. O workflow manual `verificar_pull_request.yml` aceita `ios_only=true` para compilar somente iOS. Não executar workflows de publicação.

Antes de congelar código/NITT/INPI: resolver gates, revisão institucional, registrar commit limpo/revisado, builds/testes daquele código, manifesto de arquivos/lockfiles/licenças/autoria e SHA256 de pacote sem .env, chaves, logs sensíveis ou dados pessoais. Nenhuma tag definitiva, submissão ou envio institucional foi realizado.
