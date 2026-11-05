# Petita — evidência comparativa de catálogos Neon

Consulta: 2026-10-28, aproximadamente 16:47–16:50 UTC. Projeto `round-cherry-59699884`, branch `br-rough-credit-b648szjj`. Origem: conector Neon, transações com `SET TRANSACTION READ ONLY`; confirmação posterior de `transaction_read_only=on`. Apenas catálogos, definições e contagens, sem conteúdo de registros. A conexão MCP não é uma role dedicada somente de leitura.

Complementa [o diagnóstico integrado](AUDITORIA_INTEGRADA_2026-10-28.md) e a PR #8 (`206b4025cb2a5bbd7f18cde77155e27d8e13e0e0`). Não constitui migração nem esquema-alvo aprovado.

## Resumo

| Métrica | neondb | petita_snapshot_pessoal_20261028 |
|---|---:|---:|
| Tabelas públicas | 15 | 15 |
| Colunas das tabelas (sem view) | 126 | 134 |
| Índices | 31 | 39 |
| Restrições | 46 | 46 |
| Políticas públicas | 0 | 0 |
| Funções próprias públicas | 0 | 2 |
| Views públicas | 1 | 1 |
| Registros (somente contagem) | 11 | 24 |

## Colunas e defaults

Somente diferenças; a seção de colunas também inclui a view, separável pelo prefixo `team_questions_anonymous`.

| Objeto | neondb | Snapshot |
|---|---|---|
| `birth_plans.companion` | ausente | text; nulo=YES; default=sem default |
| `birth_plans.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `birth_plans.pdf_generated_at` | ausente | timestamptz; nulo=YES; default=sem default |
| `birth_plans.updated_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `knowledge_base.active` | bool; nulo=YES; default=true | bool; nulo=NO; default=true |
| `knowledge_base.created_at` | ausente | timestamptz; nulo=YES; default=now() |
| `knowledge_base.keywords` | _text; nulo=YES; default='{}'::text[] | _text; nulo=NO; default='{}'::text[] |
| `knowledge_base.updated_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `knowledge_documents.active` | bool; nulo=YES; default=true | bool; nulo=NO; default=true |
| `knowledge_documents.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `knowledge_documents.document_type` | text; nulo=YES; default='Texto escrito'::text | text; nulo=NO; default='Texto escrito'::text |
| `knowledge_documents.file_path` | ausente | text; nulo=YES; default=sem default |
| `knowledge_documents.updated_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `patient_questions.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `patient_questions.expected_response_notice_accepted` | ausente | bool; nulo=NO; default=false |
| `patient_questions.has_warning_signs` | ausente | bool; nulo=NO; default=false |
| `patient_questions.public_code` | text; nulo=YES; default=sem default | text; nulo=YES; default=('DUV-'::text \|\| upper(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 8))) |
| `patient_questions.risk_level` | text; nulo=YES; default='low'::text | text; nulo=NO; default='low'::text |
| `patient_questions.self_risk_level` | ausente | text; nulo=NO; default='low'::text |
| `patient_questions.status` | text; nulo=YES; default='pending'::text | text; nulo=NO; default='pending'::text |
| `patient_questions.updated_at` | ausente | timestamptz; nulo=YES; default=now() |
| `patient_questions.urgency_acknowledged` | ausente | bool; nulo=NO; default=false |
| `patient_questions.warning_signs` | ausente | _text; nulo=NO; default='{}'::text[] |
| `profiles.active` | bool; nulo=YES; default=true | bool; nulo=NO; default=true |
| `profiles.auth_user_id` | uuid; nulo=YES; default=sem default | text; nulo=YES; default=sem default |
| `profiles.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `profiles.legacy_supabase_user_id` | ausente | uuid; nulo=YES; default=sem default |
| `profiles.name` | text; nulo=NO; default=sem default | text; nulo=NO; default=''::text |
| `profiles.role` | text; nulo=NO; default=sem default | text; nulo=NO; default='patient'::text |
| `support_documents.uploaded_by` | uuid; nulo=NO; default=sem default | text; nulo=YES; default=sem default |
| `team_access_requests.decided_by` | uuid; nulo=YES; default=sem default | text; nulo=YES; default=sem default |
| `team_access_requests.user_id` | uuid; nulo=YES; default=sem default | text; nulo=YES; default=sem default |
| `team_questions_anonymous.answered_at` | timestamptz; nulo=YES; default=sem default | ausente |
| `team_questions_anonymous.has_warning_signs` | ausente | bool; nulo=YES; default=sem default |
| `team_questions_anonymous.risk_level` | text; nulo=YES; default=sem default | ausente |
| `team_questions_anonymous.self_risk_level` | ausente | text; nulo=YES; default=sem default |
| `team_questions_anonymous.warning_signs` | ausente | _text; nulo=YES; default=sem default |
| `terms_acceptances.accepted_at` | timestamptz; nulo=NO; default=now() | timestamptz; nulo=YES; default=now() |
| `terms_acceptances.consent_version` | text; nulo=YES; default=sem default | ausente |
| `terms_acceptances.metadata` | jsonb; nulo=NO; default='{}'::jsonb | ausente |
| `terms_acceptances.patient_id` | uuid; nulo=YES; default=sem default | ausente |
| `terms_acceptances.privacy_version` | ausente | text; nulo=NO; default=sem default |
| `terms_acceptances.responsibility_version` | ausente | text; nulo=NO; default=sem default |
| `terms_acceptances.user_id` | ausente | uuid; nulo=YES; default=sem default |
| `ubs.active` | bool; nulo=YES; default=true | bool; nulo=NO; default=true |
| `ubs.city` | text; nulo=YES; default='Campina Grande'::text | text; nulo=NO; default='Campina Grande'::text |
| `ubs.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `ubs.state` | text; nulo=YES; default='PB'::text | text; nulo=NO; default='PB'::text |
| `ubs_answers.created_at` | timestamptz; nulo=YES; default=now() | timestamptz; nulo=NO; default=now() |
| `ubs_answers.question_id` | uuid; nulo=YES; default=sem default | uuid; nulo=NO; default=sem default |
| `warning_sign_options.code` | text; nulo=YES; default=sem default | text; nulo=NO; default=sem default |
| `warning_sign_options.description` | text; nulo=YES; default=sem default | ausente |
| `warning_sign_options.risk_level` | text; nulo=YES; default=sem default | ausente |
| `warning_sign_options.sort_order` | int4; nulo=NO; default=0 | ausente |

## Restrições

Somente diferenças; a seção de colunas também inclui a view, separável pelo prefixo `team_questions_anonymous`.

| Objeto | neondb | Snapshot |
|---|---|---|
| `birth_plans.birth_plans_patient_id_fkey` | FOREIGN KEY (patient_id) REFERENCES profiles(id) | FOREIGN KEY (patient_id) REFERENCES profiles(id) ON DELETE SET NULL |
| `knowledge_base.knowledge_base_reviewed_by_fkey` | FOREIGN KEY (reviewed_by) REFERENCES profiles(id) | FOREIGN KEY (reviewed_by) REFERENCES profiles(id) ON DELETE SET NULL |
| `knowledge_base.knowledge_base_source_document_id_fkey` | FOREIGN KEY (source_document_id) REFERENCES knowledge_documents(id) | FOREIGN KEY (source_document_id) REFERENCES knowledge_documents(id) ON DELETE SET NULL |
| `knowledge_documents.knowledge_documents_uploaded_by_fkey` | FOREIGN KEY (uploaded_by) REFERENCES profiles(id) | FOREIGN KEY (uploaded_by) REFERENCES profiles(id) ON DELETE SET NULL |
| `patient_questions.patient_questions_patient_id_fkey` | FOREIGN KEY (patient_id) REFERENCES profiles(id) | FOREIGN KEY (patient_id) REFERENCES profiles(id) ON DELETE SET NULL |
| `patient_questions.patient_questions_public_code_key` | ausente | UNIQUE (public_code) |
| `profiles.profiles_auth_user_id_key` | ausente | UNIQUE (auth_user_id) |
| `profiles.profiles_legacy_supabase_user_id_key` | ausente | UNIQUE (legacy_supabase_user_id) |
| `support_documents.support_documents_uploaded_by_fkey` | FOREIGN KEY (uploaded_by) REFERENCES profiles(id) ON DELETE RESTRICT | ausente |
| `team_access_requests.team_access_requests_decided_by_fkey` | FOREIGN KEY (decided_by) REFERENCES profiles(id) ON DELETE SET NULL | ausente |
| `team_access_requests.team_access_requests_user_id_fkey` | FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL | ausente |
| `terms_acceptances.terms_acceptances_patient_id_fkey` | FOREIGN KEY (patient_id) REFERENCES profiles(id) ON DELETE CASCADE | ausente |
| `terms_acceptances.terms_acceptances_user_id_fkey` | ausente | FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE |
| `ubs_answers.ubs_answers_answered_by_fkey` | FOREIGN KEY (answered_by) REFERENCES profiles(id) | FOREIGN KEY (answered_by) REFERENCES profiles(id) ON DELETE SET NULL |
| `ubs_answers.ubs_answers_question_id_fkey` | FOREIGN KEY (question_id) REFERENCES patient_questions(id) | FOREIGN KEY (question_id) REFERENCES patient_questions(id) ON DELETE CASCADE |

## Índices

Somente diferenças; a seção de colunas também inclui a view, separável pelo prefixo `team_questions_anonymous`.

| Objeto | neondb | Snapshot |
|---|---|---|
| `patient_questions.idx_patient_questions_public_code` | CREATE UNIQUE INDEX idx_patient_questions_public_code ON public.patient_questions USING btree (public_code) WHERE (public_code IS NOT NULL) | ausente |
| `patient_questions.idx_patient_questions_ubs_status` | CREATE INDEX idx_patient_questions_ubs_status ON public.patient_questions USING btree (ubs_code, status) | CREATE INDEX idx_patient_questions_ubs_status ON public.patient_questions USING btree (ubs_code, status, created_at) |
| `patient_questions.patient_questions_public_code_key` | ausente | CREATE UNIQUE INDEX patient_questions_public_code_key ON public.patient_questions USING btree (public_code) |
| `profiles.idx_profiles_ubs_code` | ausente | CREATE INDEX idx_profiles_ubs_code ON public.profiles USING btree (ubs_code) |
| `profiles.profiles_auth_user_id_key` | ausente | CREATE UNIQUE INDEX profiles_auth_user_id_key ON public.profiles USING btree (auth_user_id) |
| `profiles.profiles_email_unique_lower` | ausente | CREATE UNIQUE INDEX profiles_email_unique_lower ON public.profiles USING btree (lower(email)) WHERE (email IS NOT NULL) |
| `profiles.profiles_legacy_supabase_user_id_key` | ausente | CREATE UNIQUE INDEX profiles_legacy_supabase_user_id_key ON public.profiles USING btree (legacy_supabase_user_id) |
| `question_patient_links.idx_question_patient_links_patient` | ausente | CREATE INDEX idx_question_patient_links_patient ON public.question_patient_links USING btree (patient_id) |
| `terms_acceptances.idx_terms_acceptances_user` | ausente | CREATE INDEX idx_terms_acceptances_user ON public.terms_acceptances USING btree (user_id) |
| `ubs_answers.idx_ubs_answers_question` | ausente | CREATE INDEX idx_ubs_answers_question ON public.ubs_answers USING btree (question_id, created_at DESC) |
| `warning_sign_options.idx_warning_sign_options_code` | ausente | CREATE UNIQUE INDEX idx_warning_sign_options_code ON public.warning_sign_options USING btree (code) |

## Contagens por tabela

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

Contagens não comprovam equivalência de conteúdo. A validação anterior por hashes é atribuída pela PR #8 ao workflow 40726864093; os hashes de registros não foram recalculados nesta auditoria.

## Views e funções

Ambas as views usam `security_invoker=true`. Nenhuma contém predicado de isolamento por UBS. Sem políticas RLS não constituem uma interface de autorização funcional.

### neondb

`team_questions_anonymous`:

```sql
 SELECT id,
    public_code,
    category,
    question_text,
    status,
    risk_level,
    ubs_code,
    created_at,
    answered_at
   FROM patient_questions q;
```

### Snapshot

`team_questions_anonymous`:

```sql
 SELECT id,
    public_code,
    ubs_code,
    question_text,
    status,
    self_risk_level,
    has_warning_signs,
    warning_signs,
    created_at,
    category
   FROM patient_questions;
```

```sql
CREATE OR REPLACE FUNCTION public.get_support_documents_storage_usage()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
 SELECT jsonb_build_object(
 'used_bytes',COALESCE(SUM(size_bytes) FILTER (WHERE active),0),
 'max_bytes',943718400)
 FROM public.support_documents;
$function$

```

```sql
CREATE OR REPLACE FUNCTION public.match_support_document_chunks(query_embedding vector, match_threshold double precision DEFAULT 0.58, match_count integer DEFAULT 5, filter_category text DEFAULT NULL::text)
 RETURNS TABLE(chunk_id bigint, document_id uuid, document_title text, document_category text, content text, similarity double precision)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT c.id, d.id, d.title, d.category, c.content,
    (1 - (c.embedding <=> query_embedding))::double precision
  FROM public.document_chunks AS c
  JOIN public.support_documents AS d ON d.id = c.document_id
  WHERE d.active
    AND d.status = 'available'
    AND c.embedding IS NOT NULL
    AND (filter_category IS NULL OR lower(d.category) = lower(filter_category))
    AND (1 - (c.embedding <=> query_embedding)) >= match_threshold
  ORDER BY c.embedding <=> query_embedding
  LIMIT greatest(1, least(match_count, 10));
$function$

```

As duas funções no snapshot são `SECURITY INVOKER`, `STABLE`, com `search_path=public` e ACL nula (permissão padrão de execução a PUBLIC; acesso efetivo ainda depende de schema/tabelas). Isso difere dos SQLs legados Supabase com `SECURITY DEFINER`. Limitar explicitamente quem pode executá-las na implementação futura.

## Segurança e detalhes comuns

- Todas as 15 tabelas: proprietário `neondb_owner`, `relrowsecurity=true`, `relforcerowsecurity=false`.
- `neondb_owner`, `neon_service` e `neon_superuser`: `rolbypassrls=true`; `cloud_admin` também é superusuário. `token_roles` não tem bypass. São roles técnicas, não os perfis de domínio gestante/equipe/admin.
- ACL de cada tabela e da view é nula, com privilégios padrão do proprietário; não foram observados grants explícitos de aplicação nessas relações. `public` permite USAGE a PUBLIC; há ACLs padrão técnicas para `neon_superuser`. Não inferir acesso remoto anônimo a partir desses metadados.
- Ausência do schema `neon_auth` nos dois bancos. API de controle confirma Auth desabilitado na branch. Data API de `neondb`: não encontrada. Data API do snapshot não foi consultada.
- Nenhum trigger de aplicação retornado em `information_schema.triggers`.
- Extensões comuns: `plpgsql` 1.0 e `vector` 0.8.0. `document_chunks.embedding` é `vector(1024)`, com HNSW `vector_cosine_ops`. Há unicidade em `(document_id, chunk_index)`.
- As quatro RPCs do Flutter (`submit_patient_question`, `list_my_patient_questions`, `respond_to_patient_question`, `decide_team_access_request`) estão ausentes do schema público dos dois bancos.
- O índice `idx_patient_questions_ubs_status` tem definição diferente apesar de manter o mesmo nome. O índice exclusivo parcial de `public_code` em neondb já exige unicidade dos valores não nulos: a ausência de uma constraint com o nome do snapshot não significa ausência total de unicidade.

## Método e limitações

`PETITA_NEON_AUDIT_URL` ausente; nenhuma URL de conexão foi obtida ou gravada. Não houve tentativa de TCP PostgreSQL: a política de rede mostra zero destinos TCP autorizados. O MCP foi uma alternativa disponível e funcionou; não houve erro de rede na leitura via MCP. Consultas limitadas ao projeto e aos dois bancos informados, sem acesso ao Neon pessoal ou ao Supabase original.

Foram consultados `pg_class`, `pg_namespace`, `information_schema.columns`, `pg_constraint`/`pg_get_constraintdef`, `pg_indexes`, `pg_proc`/`pg_get_functiondef`, `pg_depend`, `information_schema.views`, `information_schema.role_table_grants`, `pg_roles`, `pg_extension`, `information_schema.triggers`, `pg_attribute`, `pg_default_acl`, `pg_policies`, além de `COUNT(*)` nas 15 tabelas. Nenhuma função de aplicação foi executada. Não foram testadas operações de escrita, autenticação, troca de identidade ou autorização funcional.

