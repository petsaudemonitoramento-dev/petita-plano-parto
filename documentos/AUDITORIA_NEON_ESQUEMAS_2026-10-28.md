# Petita — auditoria comparativa do Neon institucional

Data: 2026-10-28. Fonte: consultas somente leitura ao PostgreSQL do projeto institucional `round-cherry-59699884`, branch `main` (`br-rough-credit-b648szjj`). **Este arquivo não contém senhas, URLs com credenciais, registros de pessoas nem dados clínicos.**

Bancos comparados:
- `neondb`: esquema inicial criado para a conta institucional.
- `petita_snapshot_pessoal_20261028`: restauração validada do Neon pessoal. Workflow GitHub Actions [40726864093](https://github.com/petsaudemonitoramento-dev/petita-plano-parto/actions/runs/40726864093) confirmou contagens e hashes nas 15 tabelas.

## Sumário

| Métrica | neondb | Snapshot restaurado |
|---|---:|---:|
| Tabelas | 15 | 15 |
| Colunas | 126 | 134 |
| Índices | 31 | 39 |
| Restrições (PK, FK, unique, check) | 46 | 46 |
| Políticas RLS | 0 | 0 |
| Funções próprias, excluídas funções da extensão | 0 | 2 |
| Registros nas tabelas | 11 | 24 |

**Atenção:** RLS habilitada sem policies não equivale a um mecanismo de autorização funcional. Usuários comuns tendem a ser bloqueados, mas roles proprietárias podem contornar RLS. Neon Auth no banco institucional ainda precisa de configuração e auditoria separada. Não presumir compatibilidade com `auth.uid()` do Supabase.

## Comparação de registros (apenas contagens)

| Tabela | neondb | Snapshot |
|---|---:|---:|
| `birth_plans` | 0 | 0 |
| `document_chunks` | 0 | 0 |
| `knowledge_base` | 0 | 3 |
| `knowledge_categories` | 8 | 8 |
| `knowledge_documents` | 0 | 0 |
| `patient_questions` | 0 | 0 |
| `profiles` | 0 | 1 |
| `question_patient_links` | 0 | 0 |
| `rag_query_logs` | 0 | 0 |
| `support_documents` | 0 | 0 |
| `team_access_requests` | 0 | 0 |
| `terms_acceptances` | 0 | 0 |
| `ubs` | 3 | 3 |
| `ubs_answers` | 0 | 0 |
| `warning_sign_options` | 0 | 9 |

## Diferenças de colunas e características

Legenda: primeiro valor = snapshot restaurado; segundo = `neondb`. A comparação inclui tipo de dados, nulidade e defaults. Diferenças em defaults devem ser examinadas mesmo quando os tipos coincidem.

| Campo | Diferença |
|---|---|
| `birth_plans.companion` | Só no snapshot |
| `birth_plans.created_at` | nulo: NO ≠ YES |
| `birth_plans.pdf_generated_at` | Só no snapshot |
| `birth_plans.updated_at` | nulo: NO ≠ YES |
| `knowledge_base.active` | nulo: NO ≠ YES |
| `knowledge_base.created_at` | Só no snapshot |
| `knowledge_base.keywords` | nulo: NO ≠ YES |
| `knowledge_base.updated_at` | nulo: NO ≠ YES |
| `knowledge_documents.active` | nulo: NO ≠ YES |
| `knowledge_documents.created_at` | nulo: NO ≠ YES |
| `knowledge_documents.document_type` | nulo: NO ≠ YES |
| `knowledge_documents.file_path` | Só no snapshot |
| `knowledge_documents.updated_at` | nulo: NO ≠ YES |
| `patient_questions.created_at` | nulo: NO ≠ YES |
| `patient_questions.expected_response_notice_accepted` | Só no snapshot |
| `patient_questions.has_warning_signs` | Só no snapshot |
| `patient_questions.public_code` | default diferente |
| `patient_questions.risk_level` | nulo: NO ≠ YES |
| `patient_questions.self_risk_level` | Só no snapshot |
| `patient_questions.status` | nulo: NO ≠ YES |
| `patient_questions.updated_at` | Só no snapshot |
| `patient_questions.urgency_acknowledged` | Só no snapshot |
| `patient_questions.warning_signs` | Só no snapshot |
| `profiles.active` | nulo: NO ≠ YES |
| `profiles.auth_user_id` | tipo: text ≠ uuid |
| `profiles.created_at` | nulo: NO ≠ YES |
| `profiles.legacy_supabase_user_id` | Só no snapshot |
| `profiles.name` | default diferente |
| `profiles.role` | default diferente |
| `support_documents.uploaded_by` | tipo: text ≠ uuid; nulo: YES ≠ NO |
| `team_access_requests.decided_by` | tipo: text ≠ uuid |
| `team_access_requests.user_id` | tipo: text ≠ uuid |
| `terms_acceptances.accepted_at` | nulo: YES ≠ NO |
| `terms_acceptances.consent_version` | Só no neondb |
| `terms_acceptances.metadata` | Só no neondb |
| `terms_acceptances.patient_id` | Só no neondb |
| `terms_acceptances.privacy_version` | Só no snapshot |
| `terms_acceptances.responsibility_version` | Só no snapshot |
| `terms_acceptances.user_id` | Só no snapshot |
| `ubs.active` | nulo: NO ≠ YES |
| `ubs.city` | nulo: NO ≠ YES |
| `ubs.created_at` | nulo: NO ≠ YES |
| `ubs.state` | nulo: NO ≠ YES |
| `ubs_answers.created_at` | nulo: NO ≠ YES |
| `ubs_answers.question_id` | nulo: NO ≠ YES |
| `warning_sign_options.code` | nulo: NO ≠ YES |
| `warning_sign_options.description` | Só no neondb |
| `warning_sign_options.risk_level` | Só no neondb |
| `warning_sign_options.sort_order` | Só no neondb |

## Diferenças de índices (por nome)

Presentes apenas no snapshot: 9.

- `patient_questions.patient_questions_public_code_key`
- `profiles.idx_profiles_ubs_code`
- `profiles.profiles_auth_user_id_key`
- `profiles.profiles_email_unique_lower`
- `profiles.profiles_legacy_supabase_user_id_key`
- `question_patient_links.idx_question_patient_links_patient`
- `terms_acceptances.idx_terms_acceptances_user`
- `ubs_answers.idx_ubs_answers_question`
- `warning_sign_options.idx_warning_sign_options_code`

Presentes apenas no neondb: 1.

- `patient_questions.idx_patient_questions_public_code`

## Diferenças em definições de restrições

- `birth_plans.birth_plans_patient_id_fkey`: definição diferente (examinar referencial e deleção)
- `knowledge_base.knowledge_base_reviewed_by_fkey`: definição diferente (examinar referencial e deleção)
- `knowledge_base.knowledge_base_source_document_id_fkey`: definição diferente (examinar referencial e deleção)
- `knowledge_documents.knowledge_documents_uploaded_by_fkey`: definição diferente (examinar referencial e deleção)
- `patient_questions.patient_questions_patient_id_fkey`: definição diferente (examinar referencial e deleção)
- `patient_questions.patient_questions_public_code_key`: ausente no neondb
- `profiles.profiles_auth_user_id_key`: ausente no neondb
- `profiles.profiles_legacy_supabase_user_id_key`: ausente no neondb
- `support_documents.support_documents_uploaded_by_fkey`: ausente no snapshot
- `team_access_requests.team_access_requests_decided_by_fkey`: ausente no snapshot
- `team_access_requests.team_access_requests_user_id_fkey`: ausente no snapshot
- `terms_acceptances.terms_acceptances_patient_id_fkey`: ausente no snapshot
- `terms_acceptances.terms_acceptances_user_id_fkey`: ausente no neondb
- `ubs_answers.ubs_answers_answered_by_fkey`: definição diferente (examinar referencial e deleção)
- `ubs_answers.ubs_answers_question_id_fkey`: definição diferente (examinar referencial e deleção)

## Funções de aplicação encontradas (excluídas funções de extensões)

No snapshot:

- `get_support_documents_storage_usage()`
- `match_support_document_chunks(query_embedding vector, match_threshold double precision, match_count integer, filter_category text)`

Somente no snapshot: 2.

## Instruções de auditoria para Codex

1. Confronte este snapshot com o código da branch `main`, procurando todas as referências a Supabase, `auth.uid()`, `auth.users`, RLS, Storage, Edge Functions e RPCs.
2. Determine o esquema-alvo correto para Neon Auth (UUIDs vs IDs texto), o tratamento seguro de perfis e vínculos a UBS, e regras de isolamento entre gestantes e equipes.
3. Priorize segurança: negar acesso anônimo a informações sensíveis, evitar conexão PostgreSQL direta no APK, proteger offline storage e auditar termos/consentimentos.
4. Projetar migrações versionadas e testadas em **branch de homologação**, sem modificar ou apagar `neondb`, o banco snapshot, o Neon pessoal ou o Supabase original.
5. Documentar incompatibilidades por severidade e planejar PRs separadas; **não realizar qualquer operação de escrita no banco neste ciclo**.
6. Não imprimir nem copiar informações de usuários, respostas clínicas, tokens, passwords ou connection strings para logs, commits, relatórios ou PRs.
7. Validar separadamente a prontidão Android: a pasta `android/` ainda não estava persistida na `main` na auditoria anterior; um APK debug gerado por CI não equivale a release assinado.

## Proveniência e limites

O relatório foi gerado de metadados de catálogo PostgreSQL e contagens, sem consultar conteúdo de linhas. Não substitui teste funcional de permissões, de autenticação, de recuperação offline ou validação legal/regulatória. Não garante que o esquema proposto no GitHub seja o alvo definitivo.
