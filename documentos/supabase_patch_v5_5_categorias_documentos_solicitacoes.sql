-- ============================================================
-- PETITA - PATCH V5.5
-- Categorias oficiais da Petita, documentos de apoio consultáveis
-- e solicitações de acesso da Equipe UBS em formato de lista.
-- Execute no SQL Editor do Supabase após os patches anteriores.
-- ============================================================

create table if not exists public.knowledge_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.knowledge_categories (name, active) values
  ('Plano de Parto', true),
  ('Sinais de atenção', true),
  ('Acompanhante e apoio', true),
  ('Trabalho de parto', true),
  ('Nascimento', true),
  ('Cuidados com o bebê', true),
  ('Cesárea', true),
  ('Pós-parto', true)
on conflict (name) do update set active = true, updated_at = now();

alter table public.knowledge_documents add column if not exists document_type text default 'Texto escrito';
alter table public.knowledge_documents add column if not exists content_text text;
alter table public.knowledge_documents add column if not exists observations text;
alter table public.knowledge_documents add column if not exists category text;
alter table public.knowledge_documents add column if not exists active boolean default true;
alter table public.knowledge_documents add column if not exists updated_at timestamptz default now();

create table if not exists public.team_access_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  name text not null default '',
  email text not null,
  requested_ubs_code text not null references public.ubs(code),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  decided_by uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_team_access_requests_status on public.team_access_requests(status);
create index if not exists idx_team_access_requests_email on public.team_access_requests(lower(email));

alter table public.knowledge_categories enable row level security;
alter table public.knowledge_documents enable row level security;
alter table public.team_access_requests enable row level security;

drop policy if exists "public_read_knowledge_categories" on public.knowledge_categories;
create policy "public_read_knowledge_categories"
on public.knowledge_categories
for select
using (coalesce(active, true) = true);

drop policy if exists "admin_manage_knowledge_categories" on public.knowledge_categories;
create policy "admin_manage_knowledge_categories"
on public.knowledge_categories
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "public_read_knowledge_documents" on public.knowledge_documents;
create policy "public_read_knowledge_documents"
on public.knowledge_documents
for select
using (coalesce(active, true) = true);

drop policy if exists "admin_manage_knowledge_documents" on public.knowledge_documents;
create policy "admin_manage_knowledge_documents"
on public.knowledge_documents
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "team_request_insert_own" on public.team_access_requests;
create policy "team_request_insert_own"
on public.team_access_requests
for insert
to authenticated
with check (auth.uid() = user_id or user_id is null);

drop policy if exists "team_request_select_own_or_admin" on public.team_access_requests;
create policy "team_request_select_own_or_admin"
on public.team_access_requests
for select
to authenticated
using (public.is_admin() or auth.uid() = user_id or lower(email) = lower(auth.jwt()->>'email'));

drop policy if exists "admin_manage_team_requests" on public.team_access_requests;
create policy "admin_manage_team_requests"
on public.team_access_requests
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create or replace function public.decide_team_access_request(
  p_request_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.team_access_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if not public.is_admin() then
    raise exception 'Apenas administradores podem decidir solicitações da Equipe UBS.';
  end if;

  select * into req
  from public.team_access_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Solicitação não encontrada.';
  end if;

  if p_approve then
    update public.profiles
    set role = 'ubs_team',
        ubs_code = req.requested_ubs_code,
        name = coalesce(nullif(req.name, ''), name),
        active = true,
        updated_at = now()
    where lower(email) = lower(req.email);

    if not found then
      raise exception 'Conta não encontrada no perfil. Peça para a profissional criar a conta novamente.';
    end if;

    update public.team_access_requests
    set status = 'approved',
        decided_by = auth.uid(),
        decided_at = now(),
        updated_at = now()
    where id = p_request_id;
  else
    update public.team_access_requests
    set status = 'rejected',
        decided_by = auth.uid(),
        decided_at = now(),
        updated_at = now()
    where id = p_request_id;
  end if;
end;
$$;

grant execute on function public.decide_team_access_request(uuid, boolean) to authenticated;
