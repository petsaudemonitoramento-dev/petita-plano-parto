# Fundação institucional Neon — PR 1

Esta primeira implementação entrega identidade de domínio, vínculo UBS e autorização do plano. Não é a migração completa do backend. Não modifica `public`, não importa dados e não conecta o Flutter ao novo schema. A aplicação Web permanece usando a integração existente até que seus substitutos sejam homologados.

## Arquitetura e fronteira de confiança

Escolha: **Flutter → HTTPS → API própria → Neon PostgreSQL**, com Neon Auth como provedor de identidade a validar na próxima etapa. Não expor este schema diretamente por Data API/PostgREST. O contexto SQL abaixo é confiável somente no backend; uma credencial SQL vazada permite forjá-lo. RLS é defesa adicional à API, não valida assinatura de JWT.

O backend futuro deve verificar assinatura, issuer, destinatário conforme contrato do token, expiração e sessão/revogação, antes de iniciar uma transação com login restrito membro apenas de `petita_runtime`. Deve definir contexto com `set_config(..., ..., true)` e parâmetros vinculados, nunca concatenação de dados de requisição. Não conceder a esse login propriedade, CREATEROLE, BYPASSRLS, associação a roles proprietárias, DDL ou acesso SQL pelo APK. Reservar as chaves `petita.issuer` e `petita.subject` ao adapter autenticado; não aceitar esses campos do corpo HTTP.

```sql
BEGIN;
-- Exemplo conceitual do futuro adapter; $1/$2 vêm do token já verificado.
SELECT set_config('petita.issuer', $1, true);
SELECT set_config('petita.subject', $2, true);
-- Queries parametrizadas: autorização consulta vínculos atuais no banco.
COMMIT;
```

Sem contexto, subject desconhecido, issuer diferente ou perfil inativo: nenhuma linha privada visível. SET LOCAL impede reaproveitamento de contexto pelo pool após commit/rollback. O catálogo ativo de UBS é a única leitura permitida sem identidade e não contém dados de pacientes. O teste de contexto em transações não substitui o teste futuro com pool/driver HTTP.

### Modelo implementado

| Objeto | Identidade e regra |
|---|---|
| `petita.ubs` | Código institucional único; catálogo ativo legível, sem escrita runtime |
| `petita.profiles` | UUID interno estável; papel patient/ubs_team/admin e active somente por operação confiável; runtime lê próprio perfil e edita apenas display_name |
| `petita_private.identities` | `(issuer, subject)` opacos, únicos; correspondência para profile UUID. Um vínculo por perfil/provedor. Sem acesso runtime à tabela |
| `petita_private.ubs_memberships` | Uma UBS aprovada por equipe, estado ativo, aprovador e data; identidade do aprovador diferente da beneficiária. Sem escrita/leitura runtime |
| `petita.birth_plans` | FK para perfil interno, UBS, nome/DPP/acompanhante, JSON objeto e datas explícitas; somente gestante ativa proprietária pode criar/ler/alterar/apagar |

Nenhum administrador ou profissional herda acesso a planos completos. A equipe obtém sua UBS aprovada via helper; não se confia em `profiles.ubs_code` como prova de associação profissional. A UBS de gestante vem do perfil validado; o paciente não pode alterá-la diretamente. O fluxo seguro de escolha/alteração será entregue pela API posterior.

As cinco tabelas de domínio têm ENABLE/FORCE RLS. Roles técnicas:

- `petita_schema_owner`: NOLOGIN, sem superusuário/CREATEROLE/BYPASSRLS; propriedade de schema/tabelas. Não é role do aplicativo.
- `petita_authorizer`: NOLOGIN, sem bypass ou escrita. Helpers SECURITY DEFINER leem somente perfis, identidades, UBS e vínculos, por políticas específicas, para evitar recursão de RLS. Não leem planos. `search_path=pg_catalog`, referências qualificadas, nenhum parâmetro de alvo arbitrário e nenhum EXECUTE público.
- `petita_runtime`: NOLOGIN, sem bypass/DDL; privilégios de coluna e policies. O futuro login do backend poderá ser membro apenas dessa role. Nenhuma credencial é criada aqui.

`schema_migrations` é metadado privado sem grant ao runtime. Operações administrativas, criação de perfil e vinculação de identidade não estão expostas por essas migrations: exigem implementação posterior auditável. Não atribuir papel ou vínculo automaticamente a partir de email ou metadados do cadastro.

## Comparação e estrutura definitiva proposta

Revalidação somente de leitura em 29/10: os dois bancos continuam com 15 tabelas públicas, 126/134 colunas, 31/39 índices, 46/46 constraints, zero policies, zero/duas funções próprias e sem `neon_auth`. Os detalhes históricos estão em [evidências](../../documentos/EVIDENCIAS_NEON_INTEGRADA_2026-10-28.md); o novo namespace ainda não existe nos bancos institucionais. Não foi reaplicada qualquer migration no Neon.

Proposta: construir `petita`/`petita_private` por migrations aditivas, preservar os schemas legados e importar seletivamente somente após reconciliação. A fundação 001 não finge compatibilidade direta com Supabase, nem renomeia tabelas originais. Próximas migrations completarão as demais entidades sem modificar conteúdos clínicos.

| Origem / divergência | Destino e decisão | Estado |
|---|---|---|
| profiles.id vs auth_user_id UUID/text | UUID interno em profiles; sujeito opaco em identities; preservar UUID legado no import | Estrutura criada, import pendente |
| profiles.name/email/role/ubs | name→display_name; email fica no provedor e/ou arquivo privado de reconciliação, sem copiar como autoridade. Não elevar papel automaticamente | Estrutura criada, revisão/import pendentes |
| ubs | Código preservado; timestamps não nulos somente após saneamento explícito, sem inventar cidade/estado | Estrutura criada, import pendente |
| birth_plans.companion/pdf_generated_at ausentes em neondb | Colunas explícitas; FK patient_id interna com RESTRICT; preservar dados ao excluir perfis | Estrutura criada, import pendente |
| Ações de deleção diferentes nas FKs | RESTRICT nesta fundação; exclusão de dados pessoais por workflow explícito, sem cascata oculta | Implementado para núcleo |
| Índices de identidade/UBS/planos | PK/UNIQUE (issuer,subject), UNIQUE(profile,issuer); btree UBS de perfil/vínculo e paciente/data do plano | Implementado para núcleo |
| patient_questions e view | Campos de sinais/avisos do snapshot, sem converter ausência em ausência de risco; seleção por UBS no servidor | PR seguinte |
| question_patient_links | Tabela privada, vínculo reversível somente para entrega à gestante | PR seguinte |
| ubs_answers | Dúvida, UBS e autor validados na mesma transação; proibir resposta de outra unidade | PR seguinte |
| team_access_requests | Sujeito resolvido para perfil; decisão administrativa atômica e registro de aprovação | PR seguinte |
| terms_acceptances | Eventos versionados e atribuíveis, sem criar aceite retroativo; conservar user/patient, privacy/responsibility/metadata legados em reconciliação | PR própria de consentimento |
| warning_sign_options | Conservar códigos e conteúdo dos dois bancos; revisão clínica antes de escolher catálogo | PR de reconciliação, sem conteúdo alterado |
| knowledge_base/categories/documents | Conservar autoria, referências, timestamps e status revisado; distinguir knowledge_documents legado de support_documents RAG | PR de conhecimento |
| support_documents/document_chunks/rag_query_logs | Storage privado e jobs próprios; pgvector(1024)/HNSW compatíveis; manter logs minimizados | PRs de ingestão/RAG |
| 2 funções RAG do snapshot | Recriar por contrato, grants mínimos, sem copiar SECURITY DEFINER legado indiscriminadamente | PR RAG |
| Índice public_code | Neondb já tem UNIQUE parcial; snapshot tem constraint UNIQUE. Não duplicar índice por nomes diferentes | PR de dúvidas |
| Índice UBS/status | Definições diferem com mesmo nome; usar `(ubs_code,status,created_at)` ao implementar fila de dúvidas | PR de dúvidas |

Não há nesta PR sincronização, controle de revisão/conflito, contrato de opt-in de pronomes para upload ou exclusão remota. O schema novo não será usado pelo app até essas garantias e a API estarem completas. `pdf_generated_at` não será inferido do ato de sincronizar.

### Quatro interfaces seguras equivalentes às RPCs ausentes

Contrato previsto para a próxima PR; não são endpoints existentes:

| Interface | Identidade e condição obrigatória | Transação / teste de aceitação |
|---|---|---|
| `POST /v1/questions` (`submit_patient_question`) | Gestante ativa, UBS do perfil, avisos exigidos e conteúdo validado; ignorar/rejeitar patient_id do cliente | Criar pergunta/vínculo privado atomicamente com idempotência; falha não deixa órfão |
| `GET /v1/me/questions` (`list_my_patient_questions`) | Profile resolvido pelo token | Apenas perguntas/respostas do vínculo próprio; código público não é senha de acesso |
| `POST /v1/team/questions/{id}/answers` (`respond_to_patient_question`) | Equipe ativa com aprovação para a mesma UBS da pergunta | Derivar UBS/answered_by; disputa/retry não duplica nem cruza UBS |
| `POST /v1/admin/team-requests/{id}/decision` (`decide_team_access_request`) | Admin ativo, sem autoaprovação | Bloquear decisão concorrente/repetida, gravar aprovador/data/membership; não dar acesso clínico ao admin |

A listagem de equipe também será endpoint dedicado com projeção mínima, sem nomes/emails/planos/vínculos. O canal é pseudonimizado e o texto livre pode conter identificação. Nenhuma alteração de terminologia legal ou texto clínico é feita aqui.

## Neon Auth e migração de dados: próximos passos controlados

1. Criar ou selecionar homologação com somente estrutura e dados sintéticos; verificar projeto/branch e compatibilidade da região/configuração de Auth. A branch de migração já existente contém estado histórico e não foi reutilizada como sandbox desta PR.
2. Habilitar Auth apenas na homologação apropriada na próxima etapa; provar cadastro, email, login/logout/reset, expiração, revogação e persistência de sessão Android/Web. O adapter JavaScript de Supabase não é substituto direto de supabase_flutter. Esta etapa não habilita serviços nem usa novas credenciais.
3. Implementar adapter Flutter/HTTP e backend que verifique a identidade; provisionar credenciais restritas por fluxo protegido. Manter Supabase funcionando até validar todos os substitutos. Data API não será exposta com o modelo de contexto SQL desta PR.
4. Preparar inventário confidencial de reconciliação a partir de acesso aprovado: preservar IDs internos de origem, identificar subjects/issuer históricos e conflitos. Não vincular contas só por email/nome. Senhas e sessões não são presumidas migráveis.
5. Antes de importar, validar nulidade/tipos, FKs, duplicações e identidades sem correspondência; manter registros originais e relatório de exceções privado, sem dados nos logs/PR. Conservar versão/hash do arquivo de migração de dados e contagens agregadas. Hashes de linhas clínicas não entram em relatório público.
6. Importar primeiro em homologação, sem sobrescrever `neondb`, snapshot ou Supabase; comparar contagens/FKs e fluxos. Ausências de consentimento/aprovação/sinais não viram evidência fabricada. Sem correspondência segura, manter registro preservado e indisponível ao runtime até revisão.
7. Somente depois de homologação e autorização explícita, planejar janela de corte, backup, reconciliação final, restauração e rollback de aplicação. Nunca rodar esta migration em main por CI.

## Reprodução dos testes no Codex Cloud / GitHub Actions

```bash
python3 tools/check_frozen_questionnaire.py
python3 tools/test_neon_foundation.py
```

O runner não aceita DATABASE_URL e não lê variáveis de conexão. Cria container local exclusivo `petita-rls-test-*` com PostgreSQL 17.6 por digest fixo, sem rede, portas ou mounts de arquivos do host; usa tmpfs e dados sintéticos, removendo o próprio container no final. Conexões usam socket dentro do container. O modo trust existe apenas nesse container inacessível pela rede; não é configuração recomendada para Neon.

Migração executada por login sintético **não superusuário**, com CREATEROLE/CREATE para setup. Fixtures são carregadas pelo administrador do container; testes funcionais abrem novas conexões como login comum, membro apenas de petita_runtime, sem owner/superuser/BYPASSRLS. O uso administrativo para preparar fixtures não simula autorização de gestantes.

22 cenários executados em 29/10: propriedade/bypass reais; leitura própria A/B; anônimo/issuer incorreto/identidade desconhecida/inativa; bloqueio clínico equipe/admin; UBS aprovada; role derivada do banco; desativação imediata; revogação de vínculo e UBS inativa; sigilo de mappings; proteção de colunas/autoelevação; CRUD próprio; escrita cruzada paciente/UBS; inserção por não pacientes; formato JSON; bloqueio de SET ROLE/DDL/TRUNCATE/row_security off; privilégios limitados dos helpers; contexto após commit; configuração RLS/ACL/search_path; unicidade/FK; rollback com dados; rollback sob RLS; apply/rollback/reapply vazio e recusa de apply duplicado/sem guarda. Resultado: **22 aprovados**.

O PostgreSQL institucional informa 17.11. Testar 17.6 prova comportamento no mesmo major com patch fixado, mas ainda exige execução da mesma suíte em homologação Neon antes de promover. Não foram realizados testes de JWT/Neon Auth, API, concorrência de RPCs, migração de registros reais ou aparelho Android. O workflow `testar_infra_neon.yml` executa estes testes sem secrets; o workflow Flutter existente continua analisando, testando e compilando Web.

## Migrations e rollback

`001_identity_rls.up.sql` é transacional, recusa namespace já existente e exige marcador explícito de homologação. O marcador não detecta a branch remota e não substitui verificar o destino; não existe runner remoto/automático nesta PR. A migration não cria login/senha, seed clínico nem Neo Auth.

`001_identity_rls.down.sql` só desfaz uma fundação vazia e com histórico 1. Recusa qualquer dado de domínio ou dependência desconhecida e não usa CASCADE. `row_security=off` faz o rollback falhar se a inspeção de vazio poderia esconder dados por RLS; não se desliga RLS da tabela. Após importação, a estratégia é migration corretiva, não apagar schemas. Roles NOLOGIN são retidas porque são compartilhadas no cluster. As duas direções foram testadas somente no container descartável.

Critérios desta PR: migrations aplicáveis isoladamente; originais preservados; políticas executadas por login comum; 31 perguntas byte a byte; 79 testes Flutter e build Web preservados; CI de autorização e Flutter aprovados. Critérios pendentes antes de uso real: interfaces de dúvidas/aprovação, Auth/API, consentimento remoto, storage local cifrado e sync por conta, plataforma Android permanente e homologação.
