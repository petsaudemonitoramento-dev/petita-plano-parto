-- PETITA V6 | BASE NEON (RECONSTRUCAO PARCIAL E CONSERVADORA)
-- Schema reconstruido dos arquivos versionados em documentos/ e codigo Flutter.
-- Nao e dump do Supabase original (projeto INACTIVE).
-- Ajustes deliberados: nenhum auth.users do Supabase, IDs Neon Auth textuais,
-- RLS habilitada SEM politicas liberadas. API deve validar identidade e UBS.
-- Uso somente no projeto Neon Petita, NAO no Supabase existente.

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

CREATE TABLE IF NOT EXISTS public.ubs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 code text NOT NULL UNIQUE, name text NOT NULL,
 city text NOT NULL DEFAULT 'Campina Grande',
 state text NOT NULL DEFAULT 'PB', active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 auth_user_id text UNIQUE,
 legacy_supabase_user_id uuid UNIQUE,
 name text NOT NULL DEFAULT '', email text,
 role text NOT NULL DEFAULT 'patient' CHECK (role IN ('patient','ubs_team','admin')),
 ubs_code text REFERENCES public.ubs(code),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_unique_lower
 ON public.profiles (lower(email)) WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.birth_plans (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 patient_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 ubs_code text REFERENCES public.ubs(code),
 patient_name text, dpp date, companion text,
 answers_json jsonb NOT NULL DEFAULT '{}'::jsonb,
 pdf_generated_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(), synced_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.patient_questions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 patient_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 public_code text UNIQUE,
 ubs_code text REFERENCES public.ubs(code),
 category text, question_text text NOT NULL,
 status text NOT NULL DEFAULT 'pending'
   CHECK (status IN ('pending','answered','archived')),
 risk_level text NOT NULL DEFAULT 'low',
 self_risk_level text NOT NULL DEFAULT 'low',
 has_warning_signs boolean NOT NULL DEFAULT false,
 warning_signs text[] NOT NULL DEFAULT '{}',
 urgency_acknowledged boolean NOT NULL DEFAULT false,
 expected_response_notice_accepted boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), answered_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.question_patient_links (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 question_id uuid NOT NULL UNIQUE REFERENCES public.patient_questions(id) ON DELETE CASCADE,
 patient_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.ubs_answers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 question_id uuid NOT NULL REFERENCES public.patient_questions(id) ON DELETE CASCADE,
 ubs_code text REFERENCES public.ubs(code),
 answered_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 answer_text text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.knowledge_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL, file_url text, file_type text,
 uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 document_type text NOT NULL DEFAULT 'Texto escrito',
 content_text text, observations text, category text,
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.knowledge_base (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 category text NOT NULL, question text NOT NULL,
 keywords text[] NOT NULL DEFAULT '{}', answer text NOT NULL,
 source_document_id uuid REFERENCES public.knowledge_documents(id) ON DELETE SET NULL,
 reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 active boolean NOT NULL DEFAULT true, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.knowledge_categories (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL UNIQUE, active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.team_access_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id text, name text NOT NULL DEFAULT '', email text NOT NULL,
 requested_ubs_code text NOT NULL REFERENCES public.ubs(code),
 status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
 decided_by text, decided_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.support_documents (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL, category text NOT NULL,
 file_name text NOT NULL, file_path text NOT NULL UNIQUE,
 mime_type text NOT NULL CHECK (mime_type IN
   ('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document')),
 size_bytes bigint NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 20971520),
 status text NOT NULL DEFAULT 'queued'
   CHECK (status IN ('queued','processing','available','error')),
 chunk_count integer NOT NULL DEFAULT 0,
 total_chunks integer NOT NULL DEFAULT 0,
 embedded_chunks integer NOT NULL DEFAULT 0,
 processing_error text, active boolean NOT NULL DEFAULT true,
 uploaded_by text, processed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.document_chunks (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 document_id uuid NOT NULL REFERENCES public.support_documents(id) ON DELETE CASCADE,
 chunk_index integer NOT NULL, content text NOT NULL,
 embedding public.vector(1024),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(document_id,chunk_index)
);
CREATE TABLE IF NOT EXISTS public.rag_query_logs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 question_hash text NOT NULL, question_length integer NOT NULL DEFAULT 0,
 category text, found boolean NOT NULL DEFAULT false,
 top_similarity double precision,
 source_document_ids uuid[] NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_profiles_ubs_code ON public.profiles(ubs_code);
CREATE INDEX IF NOT EXISTS idx_birth_plans_patient ON public.birth_plans(patient_id);
CREATE INDEX IF NOT EXISTS idx_patient_questions_ubs_status
 ON public.patient_questions(ubs_code,status,created_at);
CREATE INDEX IF NOT EXISTS idx_question_patient_links_patient
 ON public.question_patient_links(patient_id);
CREATE INDEX IF NOT EXISTS idx_ubs_answers_question
 ON public.ubs_answers(question_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_team_access_requests_status
 ON public.team_access_requests(status);
CREATE INDEX IF NOT EXISTS idx_team_access_requests_email
 ON public.team_access_requests(lower(email));
CREATE INDEX IF NOT EXISTS idx_knowledge_base_category
 ON public.knowledge_base(category);
CREATE INDEX IF NOT EXISTS idx_support_documents_status
 ON public.support_documents(status);
CREATE INDEX IF NOT EXISTS idx_support_documents_category
 ON public.support_documents(category);
CREATE INDEX IF NOT EXISTS idx_document_chunks_document
 ON public.document_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding_hnsw
 ON public.document_chunks USING hnsw(embedding vector_cosine_ops);

-- Sem politicas e sem Data API ate configuracao e testes do Neon Auth.
ALTER TABLE public.ubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.birth_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_patient_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ubs_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_base ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rag_query_logs ENABLE ROW LEVEL SECURITY;

INSERT INTO public.ubs(code,name,city,state,active) VALUES
 ('UBS-EV-001','UBS - Estação Velha','Campina Grande','PB',true),
 ('UBS-AAV-002','UBS - Antônio Aurélio Ventura (Cinza)','Campina Grande','PB',true),
 ('UBS-RBF-003','UBS - Romualdo Brito de Figueiredo','Campina Grande','PB',true)
ON CONFLICT(code) DO NOTHING;

INSERT INTO public.knowledge_categories(name,active) VALUES
 ('Plano de Parto',true),('Sinais de atenção',true),
 ('Acompanhante e apoio',true),('Trabalho de parto',true),
 ('Nascimento',true),('Cuidados com o bebê',true),
 ('Cesárea',true),('Pós-parto',true)
ON CONFLICT(name) DO NOTHING;

CREATE OR REPLACE VIEW public.team_questions_anonymous
WITH (security_invoker=true) AS
 SELECT id, public_code, ubs_code, question_text,
        status, self_risk_level, has_warning_signs,
        warning_signs, created_at, category
 FROM public.patient_questions;
REVOKE ALL ON public.team_questions_anonymous FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.match_support_document_chunks(
 query_embedding public.vector(1024),
 match_threshold double precision DEFAULT 0.58,
 match_count integer DEFAULT 5,
 filter_category text DEFAULT NULL
)
RETURNS TABLE(chunk_id bigint, document_id uuid, document_title text,
 document_category text, content text, similarity double precision)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=public AS $$
 SELECT c.id,d.id,d.title,d.category,c.content,
        (1 - (c.embedding <=> query_embedding))::double precision
 FROM public.document_chunks c
 JOIN public.support_documents d ON d.id=c.document_id
 WHERE d.active AND d.status='available'
   AND c.embedding IS NOT NULL
   AND (filter_category IS NULL OR lower(d.category)=lower(filter_category))
   AND 1-(c.embedding <=> query_embedding)>=match_threshold
 ORDER BY c.embedding <=> query_embedding
 LIMIT greatest(1,least(match_count,10));
$$;
REVOKE ALL ON FUNCTION public.match_support_document_chunks(
 public.vector,double precision,integer,text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.get_support_documents_storage_usage()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=public AS $$
 SELECT jsonb_build_object(
  'used_bytes',COALESCE(SUM(size_bytes) FILTER (WHERE active),0),
  'max_bytes',943718400)
 FROM public.support_documents;
$$;
REVOKE ALL ON FUNCTION public.get_support_documents_storage_usage() FROM PUBLIC;

-- NAO rodar patches Supabase originais diretamente neste banco:
-- suas referencias a auth.users, auth.uid, auth.jwt, storage.* e service_role
-- nao sao portaveis para o Neon sem adaptar autenticacao e autorizacao.
