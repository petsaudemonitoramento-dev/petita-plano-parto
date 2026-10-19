-- Petita V6 | Adicoes identificadas no backup PostgreSQL de 2026-08-21.
-- Importacao validada em uma ramificacao do Neon antes de aplicar na main.
-- Este arquivo nao contem dados de usuario nem dados confidenciais.
ALTER TABLE public.knowledge_base ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.knowledge_documents ADD COLUMN IF NOT EXISTS file_path text;
ALTER TABLE public.patient_questions ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.patient_questions ALTER COLUMN public_code SET DEFAULT ('DUV-'::text || upper(substr(replace((gen_random_uuid())::text, '-', ''), 1, 8)));
CREATE TABLE IF NOT EXISTS public.warning_sign_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE, label text NOT NULL,
  active boolean NOT NULL DEFAULT true, created_at timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.terms_acceptances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  terms_version text NOT NULL, privacy_version text NOT NULL,
  responsibility_version text NOT NULL, accepted_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_terms_acceptances_user ON public.terms_acceptances(user_id);
ALTER TABLE public.warning_sign_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terms_acceptances ENABLE ROW LEVEL SECURITY;
