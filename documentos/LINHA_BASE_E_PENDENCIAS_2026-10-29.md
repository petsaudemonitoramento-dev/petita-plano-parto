# Petita — linha de base e implementação inicial, 29/10/2026

Base de trabalho: `origin/main` `784271a` (hash completo pode ser consultado no histórico Git). Este documento atualiza o estado operacional sem reescrever a auditoria histórica de 28/10.

## Etapa 1 — relatórios recuperados e versionados

Commit `35acfe5fcd9285b8e76151a80012477477afb745`, anterior à implementação: [auditoria integrada](AUDITORIA_INTEGRADA_2026-10-28.md) e [evidências Neon](EVIDENCIAS_NEON_INTEGRADA_2026-10-28.md). Os dois arquivos foram mantidos como registro da base `344f3b0`, sem incluir dados de pessoas/credenciais. Seus 67 testes são resultado histórico; o total atual é 79.

## Etapa 2 — estado atual da main confirmado

| Mudança integrada | Estado observado / ação nesta execução |
|---|---|
| PR #9, merge `191f141f` | Arte oficial `assets/branding/Petita_icone_android_1024.png` existe. Não recriar arte; mipmaps/adaptativo/monocromático/splash continuam pendentes |
| PR #13, merge `56a547d2` | DPP/idade gestacional estimada, pronomes opcionais editáveis, opt-in separado para PDF, texto personalizado/múltiplas escolhas e explicações das 31 perguntas presentes. Não reimplementar |
| PR #14, merge `7c3a839f` | Diálogo continuar/recomeçar/cancelar, proteção do plano salvo/completo e limpeza delimitada presentes. Não reimplementar |
| Publicação Web | Usuário informa site atualizado; histórico contém as publicações autorizadas. Esta execução não publica nem homologa o site/aparelho |
| Questionário | 31 itens, hash SHA-256 `9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd`; bytes iguais à base histórica |

Revisão clínica humana dos novos textos educativos continua pendente. Sua existência no site não prova aprovação clínica. Crédito visual do desenvolvedor não resolve autoria/titularidade jurídica.

## Etapa 3 — nova linha de base executada

| Verificação | Resultado local no cloud |
|---|---|
| Flutter/Dart | 3.44.0 / 3.12.0; origem/canal local não padrão já documentados |
| `flutter pub get --enforce-lockfile` | Passou, sem mudança em lockfile |
| `flutter analyze --no-pub` | Passou, zero apontamentos |
| `flutter test --no-pub --reporter expanded` | **79 testes aprovados** |
| `flutter build web --release --base-href /petita-plano-parto/ --no-wasm-dry-run --no-pub` | Passou |
| Invariantes de código | Nenhum arquivo Flutter, asset clínico, texto legal, pubspec/lockfile ou branding alterado nesta PR |
| Neon, somente leitura | 15/15 tabelas; 126/134 colunas; 31/39 índices; 46/46 constraints; zero policies; zero/duas funções próprias; sem schema neon_auth; schemas novos ausentes nos dois bancos |

A leitura Neon usou explicitamente o projeto institucional, branch main e transações READ ONLY. Não houve escrita em `neondb`, snapshot, main ou homologação Neon. Os testes com escrita ocorreram apenas em PostgreSQL descartável na máquina cloud. Não foram usados dados de gestantes ou cópias de registros existentes.

## Etapa 4 — primeira PR de implementação

Branch `infra/neon-identidade-rls`; commits/CI e número da PR são rastreáveis no GitHub. Escopo fechado: fundação de identidade e autorização do núcleo. [Implementação e contratos seguintes](../infra/neon/README.md).

Arquivos de implementação:

- `infra/neon/migrations/001_identity_rls.up.sql`: schemas novos, roles sem login/bypass, identidades, UBS, perfis, vínculos aprovados e planos com RLS/grants mínimos.
- `infra/neon/migrations/001_identity_rls.down.sql`: rollback transacional apenas vazio, recusando perda de dados/objetos desconhecidos.
- `tools/test_neon_foundation.py`: testes reais de PostgreSQL, login comum, dados sintéticos, container sem rede/portas e digest fixo.
- `tools/check_frozen_questionnaire.py`: proteção de bytes e 31 IDs canônicos.
- `.github/workflows/testar_infra_neon.yml`: CI isolado, sem credenciais Neon, execução de migrations e autorização.
- `.gitignore`: exclusão de bytecode Python gerado pelas verificações.

Resultado local: **22 testes de autorização aprovados**. Incluem gestante A/B, equipe UBS A/B, admin, anônimo e inativo, escrita e leitura cruzadas, role/UBS forjadas, sigilo de vínculos, suspensão, grants/ACL/RLS reais, contexto transacional, FK/unicidade, apply/rollback e preservação de legado sintético. A migration de setup também foi executada por login não superusuário. PostgreSQL local 17.6, institucional 17.11: execução em homologação Neon ainda é um gate antes de promoção.

Limite: estes são testes de **autorização SQL com contexto confiável**, não autenticação Neon nem API HTTP. Auth continua não ativado; nenhum novo login/senha foi provisionado no Neon. As quatro RPCs continuam ausentes dos bancos originais; seus substitutos foram delimitados para a próxima PR e não são declarados implementados.

## Matriz de pendências atualizada

| Prioridade / item | Situação após esta PR | Próxima entrega objetiva |
|---|---|---|
| Preservar auditorias | Versionadas antes da implementação | Revisão da PR, sem reescrever histórico |
| Arte oficial, DPP, pronomes/opt-in PDF, personalização, explicações e continuar/reiniciar | Já integrados, nova suíte preservada | Homologar no APK; revisão clínica humana das explicações |
| Identidade UUID interna / sujeito opaco | Implementada em namespace novo; sem import/corte | Revisar, testar mesma migration em homologação Neon |
| RLS/privilégio mínimo para perfil/plano/UBS | 22 cenários locais aprovados; não aplicados no Neon | CI e validação Neon isolada antes de promoção |
| Quatro interfaces de dúvidas/aprovação e projeção de equipe | Contratos definidos, implementação pendente | PR 2: tabelas/vínculos privados e operações atômicas, testes com duas contas/UBS |
| Aceites e reconciliação dos dois schemas | Plano definido; nenhum dado importado | PR própria: mapping validado, eventos/versões e exceções preservadas |
| Neon Auth / API HTTPS | Arquitetura escolhida; ativação e adapter pendentes | Prova de signup/login/verificação/reset/renovação/logout e validação de token/issuer |
| Flutter integrado ao Neon | Supabase preservado, sem reapontamento improvisado | Adapter API e testes HTTP/Auth, depois retirar legado |
| Dados locais cifrados / isolamento de conta | Pendente; SharedPreferences global continua existente | Migration local segura, Keystore/tokens, troca de conta/logout/revogação e recuperação |
| Sync resiliente / conflitos | Pendente | Outbox cifrada, idempotência, revisões, ACK/pull/conflitos explícitos |
| Conhecimento / Storage / RAG | Legado preservado; substitutos pendentes | Corpus autorizado, busca com fontes, quotas/ingestão privada e testes de falhas |
| Android permanente / pipeline / assinatura | Pendente; #6 era debug temporário | PR independente com package ID documentado, ícones/splash/permissões/backup e build release protegida |
| Homologação Android | Não executada | Inspeção binária, instalação/update/reinstalação e testes físicos com evidências |
| Registro NITT/INPI | Não congelado; sem hash definitivo | Após homologação: versão/commit, PDF fonte/pacote/APK e hashes distintos, licenças/autoria/checklist |

## Próximas PRs e critérios

1. **Dúvidas e aprovação UBS:** quatro operações equivalentes às RPCs ausentes, idempotência/transações e projeção mínima de equipe. Bloquear IDs forjados, autoaprovação, concorrência e qualquer cruzamento de UBS/vínculos.
2. **Identidade e API:** homologação Neon Auth e backend parametrizado, login e sessão nativos/Web; nenhuma credencial administrativa no cliente; nenhuma produção alterada sem autorização.
3. **Flutter + segurança local + sync**, em PRs separadas: manter 79 testes e expandir para dados cifrados, contas distintas, falhas/interrupções e conflitos, preservando pronomes opcionais/opt-in PDF.
4. **Android permanente:** pode avançar independentemente sem dar acesso inseguro ao banco. Release só com assinatura institucional protegida e versão/commit identificáveis.
5. **Homologação e dossiê:** testes físicos e revisão clínica/regulatória/titularidade permanecem gates humanos. Somente congelar e calcular hashes definitivos depois.

Critério desta primeira execução: relatórios versionados, main atual reconhecida, 79 testes e build Web aprovados, questionário intacto e primeira PR executável de infraestrutura com evidências de autorização. Isso não encerra as fases A–F nem prova prontidão para uso assistencial/distribuição.
