-- ============================================================
-- PETITA V6.0 - RAG DOCUMENTAL AUTOMÁTICO
-- Execute após todos os patches anteriores.
-- PDF com texto selecionável e DOCX, até 20 MB por arquivo.
-- Limite interno do aplicativo: 900 MB de arquivos ativos.
-- ============================================================

create extension if not exists vector with schema extensions;

create table if not exists public.support_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  file_name text not null,
  file_path text not null unique,
  mime_type text not null check (mime_type in (
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  )),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
  status text not null default 'queued' check (status in ('queued', 'processing', 'available', 'error')),
  chunk_count integer not null default 0,
  total_chunks integer not null default 0,
  embedded_chunks integer not null default 0,
  processing_error text,
  active boolean not null default true,
  uploaded_by uuid not null references auth.users(id) on delete restrict,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.document_chunks (
  id bigint generated always as identity primary key,
  document_id uuid not null references public.support_documents(id) on delete cascade,
  chunk_index integer not null,
  content text not null,
  embedding extensions.vector(1024),
  created_at timestamptz not null default now(),
  unique(document_id, chunk_index)
);

create table if not exists public.rag_query_logs (
  id bigint generated always as identity primary key,
  question_hash text not null,
  question_length integer not null default 0,
  category text,
  found boolean not null default false,
  top_similarity double precision,
  source_document_ids uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.support_documents add column if not exists total_chunks integer not null default 0;
alter table public.support_documents add column if not exists embedded_chunks integer not null default 0;
alter table public.document_chunks alter column embedding drop not null;

create index if not exists idx_support_documents_status on public.support_documents(status);
create index if not exists idx_support_documents_category on public.support_documents(category);
create index if not exists idx_document_chunks_document on public.document_chunks(document_id);
create index if not exists idx_document_chunks_embedding_hnsw
  on public.document_chunks using hnsw (embedding vector_cosine_ops);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-documents',
  'support-documents',
  false,
  20971520,
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.support_documents enable row level security;
alter table public.document_chunks enable row level security;
alter table public.rag_query_logs enable row level security;

drop policy if exists "admin_manage_support_documents" on public.support_documents;
create policy "admin_manage_support_documents"
on public.support_documents
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "admin_read_document_chunks" on public.document_chunks;
create policy "admin_read_document_chunks"
on public.document_chunks
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin_read_rag_query_logs" on public.rag_query_logs;
create policy "admin_read_rag_query_logs"
on public.rag_query_logs
for select
to authenticated
using (public.is_admin());

drop policy if exists "admin_upload_support_documents" on storage.objects;
create policy "admin_upload_support_documents"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'support-documents' and public.is_admin());

drop policy if exists "admin_read_support_documents_files" on storage.objects;
create policy "admin_read_support_documents_files"
on storage.objects
for select
to authenticated
using (bucket_id = 'support-documents' and public.is_admin());

drop policy if exists "admin_delete_support_documents_files" on storage.objects;
create policy "admin_delete_support_documents_files"
on storage.objects
for delete
to authenticated
using (bucket_id = 'support-documents' and public.is_admin());

create or replace function public.get_support_documents_storage_usage()
returns jsonb
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Apenas administradores podem consultar o uso dos documentos.';
  end if;

  select jsonb_build_object(
    'used_bytes', coalesce(sum(size_bytes) filter (where active), 0),
    'max_bytes', 943718400
  ) into result
  from public.support_documents;

  return result;
end;
$$;

revoke all on function public.get_support_documents_storage_usage() from public, anon;
grant execute on function public.get_support_documents_storage_usage() to authenticated;

create or replace function public.match_support_document_chunks(
  query_embedding extensions.vector(1024),
  match_threshold double precision default 0.58,
  match_count integer default 5,
  filter_category text default null
)
returns table (
  chunk_id bigint,
  document_id uuid,
  document_title text,
  document_category text,
  content text,
  similarity double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    c.id,
    d.id,
    d.title,
    d.category,
    c.content,
    1 - (c.embedding <=> query_embedding) as similarity
  from public.document_chunks c
  join public.support_documents d on d.id = c.document_id
  where d.active = true
    and d.status = 'available'
    and c.embedding is not null
    and (filter_category is null or lower(d.category) = lower(filter_category))
    and 1 - (c.embedding <=> query_embedding) >= match_threshold
  order by c.embedding <=> query_embedding
  limit greatest(1, least(match_count, 10));
$$;

revoke all on function public.match_support_document_chunks(extensions.vector, double precision, integer, text) from public, anon, authenticated;
grant execute on function public.match_support_document_chunks(extensions.vector, double precision, integer, text) to service_role;

-- A gestante consulta apenas as próprias dúvidas. A Equipe UBS continua
-- usando a visão anonimizada e não recebe o vínculo abaixo.
create or replace function public.list_my_patient_questions()
returns table (
  id uuid,
  public_code text,
  category text,
  question_text text,
  status text,
  ubs_code text,
  answer_text text,
  created_at timestamptz,
  answered_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    q.id,
    q.public_code,
    q.category,
    q.question_text,
    case when a.answer_text is not null then 'answered' else q.status end,
    q.ubs_code,
    a.answer_text,
    q.created_at,
    coalesce(q.answered_at, a.created_at)
  from public.question_patient_links link
  join public.patient_questions q on q.id = link.question_id
  left join lateral (
    select answer_text, created_at
    from public.ubs_answers
    where question_id = q.id
    order by created_at desc
    limit 1
  ) a on true
  where link.patient_id = auth.uid()
  order by q.created_at desc;
$$;

grant execute on function public.list_my_patient_questions() to authenticated;
