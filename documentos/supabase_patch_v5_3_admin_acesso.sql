-- ============================================================
-- PETITA - PATCH V5.3
-- Acesso administrativo, liberação de Equipe UBS e remoção de
-- liberação aberta de equipe.
-- Execute no SQL Editor do Supabase depois do schema inicial.
-- ============================================================

-- Garante coluna de atualização usada pelos perfis.
alter table public.profiles add column if not exists updated_at timestamptz default now();

-- Função auxiliar: verifica se o usuário autenticado é administrador ativo.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and coalesce(p.active, true) = true
  );
$$;

-- Trigger de criação de perfil: novas contas entram como paciente.
-- A Equipe UBS deve ser liberada posteriormente por uma conta admin.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_ubs text;
begin
  requested_ubs := nullif(coalesce(new.raw_user_meta_data->>'ubs_code', new.raw_user_meta_data->>'requested_ubs_code'), '');

  insert into public.profiles (id, email, name, role, ubs_code, active)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    'patient',
    requested_ubs,
    true
  )
  on conflict (id) do update
  set email = excluded.email,
      name = coalesce(nullif(excluded.name, ''), profiles.name),
      ubs_code = coalesce(excluded.ubs_code, profiles.ubs_code),
      active = true,
      updated_at = now();

  return new;
end;
$$;

-- Remove função anterior de liberação aberta, se existir.
drop function if exists public.register_test_ubs_team(text, text, text);

-- Administrador libera uma conta existente como Equipe UBS e vincula à UBS.
create or replace function public.approve_ubs_team_by_email(
  p_email text,
  p_name text,
  p_ubs_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if not public.is_admin() then
    raise exception 'Apenas administradores podem liberar acesso da Equipe UBS.';
  end if;

  if not exists (
    select 1 from public.ubs
    where code = p_ubs_code
      and coalesce(active, true) = true
  ) then
    raise exception 'UBS inválida ou inativa.';
  end if;

  update public.profiles
  set role = 'ubs_team',
      ubs_code = p_ubs_code,
      name = coalesce(nullif(p_name, ''), name),
      active = true,
      updated_at = now()
  where lower(email) = lower(p_email);

  if not found then
    raise exception 'Conta não encontrada. Primeiro crie a conta com e-mail e senha na área da Equipe UBS.';
  end if;
end;
$$;

grant execute on function public.approve_ubs_team_by_email(text, text, text) to authenticated;

-- Regras de acesso para cadastros administráveis.
alter table public.ubs enable row level security;
alter table public.knowledge_base enable row level security;

drop policy if exists "public_read_ubs" on public.ubs;
create policy "public_read_ubs"
on public.ubs
for select
using (coalesce(active, true) = true);

drop policy if exists "admin_manage_ubs" on public.ubs;
create policy "admin_manage_ubs"
on public.ubs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "public_read_knowledge_base" on public.knowledge_base;
create policy "public_read_knowledge_base"
on public.knowledge_base
for select
using (coalesce(active, true) = true);

drop policy if exists "admin_manage_knowledge_base" on public.knowledge_base;
create policy "admin_manage_knowledge_base"
on public.knowledge_base
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());
