-- Esquema inicial proposto para a versão online do Plano de Parto PET Saúde.
-- O app permanece offline-first; Supabase entra para sincronização e funcionalidades online.

create table if not exists public.ubs (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  city text default 'Campina Grande',
  state text default 'PB',
  active boolean default true,
  created_at timestamptz default now()
);

insert into public.ubs (code, name, city, state, active) values
  ('UBS-EV-001', 'UBS - Estação Velha', 'Campina Grande', 'PB', true),
  ('UBS-AAV-002', 'UBS - Antônio Aurélio Ventura (Cinza)', 'Campina Grande', 'PB', true),
  ('UBS-RBF-003', 'UBS - Romualdo Brito de Figueiredo', 'Campina Grande', 'PB', true)
on conflict (code) do nothing;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid,
  name text not null,
  email text,
  role text not null check (role in ('patient', 'ubs_team', 'admin')),
  ubs_code text references public.ubs(code),
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.birth_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.profiles(id),
  ubs_code text references public.ubs(code),
  patient_name text,
  dpp date,
  answers_json jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  synced_at timestamptz
);

create table if not exists public.patient_questions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references public.profiles(id),
  ubs_code text references public.ubs(code),
  question_text text not null,
  status text default 'pending' check (status in ('pending', 'answered', 'archived')),
  risk_level text default 'low',
  created_at timestamptz default now(),
  answered_at timestamptz
);

create table if not exists public.ubs_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.patient_questions(id),
  ubs_code text references public.ubs(code),
  answered_by uuid references public.profiles(id),
  answer_text text not null,
  created_at timestamptz default now()
);

create table if not exists public.knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  file_url text,
  file_type text,
  uploaded_by uuid references public.profiles(id),
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.knowledge_base (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  question text not null,
  keywords text[] default '{}',
  answer text not null,
  source_document_id uuid references public.knowledge_documents(id),
  reviewed_by uuid references public.profiles(id),
  active boolean default true,
  updated_at timestamptz default now()
);
