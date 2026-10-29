-- Petita: nucleo de perguntas, branch Neon de homologacao.
-- Migração não aplicada em main; base já validada em homologação.
CREATE SCHEMA IF NOT EXISTS petita_atendimento;
CREATE SCHEMA IF NOT EXISTS petita_privado;
REVOKE ALL ON SCHEMA petita_atendimento FROM PUBLIC;
REVOKE ALL ON SCHEMA petita_privado FROM PUBLIC;

CREATE TABLE IF NOT EXISTS petita_atendimento.acessos (
 usuario_id uuid PRIMARY KEY,
 papel text NOT NULL CHECK (papel IN ('gestante','equipe_ubs','administrador')),
 ativo boolean NOT NULL DEFAULT true,
 criado_em timestamptz NOT NULL DEFAULT now(),
 atualizado_em timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS petita_privado.vinculos_gestantes (
 usuario_id uuid PRIMARY KEY REFERENCES petita_atendimento.acessos(usuario_id),
 ubs_codigo text NOT NULL REFERENCES public.ubs(code),
 confirmado_em timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS petita_atendimento.vinculos_equipes (
 usuario_id uuid PRIMARY KEY REFERENCES petita_atendimento.acessos(usuario_id),
 ubs_codigo text NOT NULL REFERENCES public.ubs(code),
 autorizado_por uuid REFERENCES petita_atendimento.acessos(usuario_id),
 autorizado_em timestamptz NOT NULL DEFAULT now(),
 ativo boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS petita_atendimento.solicitacoes_acesso (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 usuario_id uuid NOT NULL REFERENCES petita_atendimento.acessos(usuario_id),
 ubs_codigo text NOT NULL REFERENCES public.ubs(code),
 justificativa text NOT NULL DEFAULT '' CHECK (length(justificativa) <= 600),
 situacao text NOT NULL DEFAULT 'pendente'
   CHECK (situacao IN ('pendente','aprovada','recusada','cancelada')),
 solicitado_em timestamptz NOT NULL DEFAULT now(),
 decidido_por uuid REFERENCES petita_atendimento.acessos(usuario_id),
 decidido_em timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS solicitacao_equipe_pendente_usuario
 ON petita_atendimento.solicitacoes_acesso(usuario_id) WHERE situacao='pendente';

CREATE TABLE IF NOT EXISTS petita_atendimento.duvidas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 codigo_publico text NOT NULL DEFAULT
  ('PET-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))) UNIQUE,
 ubs_codigo text NOT NULL REFERENCES public.ubs(code),
 categoria text NOT NULL CHECK (length(btrim(categoria)) BETWEEN 2 AND 80),
 texto text NOT NULL CHECK (length(btrim(texto)) BETWEEN 5 AND 2000),
 nivel_percebido text NOT NULL DEFAULT 'baixo'
  CHECK (nivel_percebido IN ('baixo','moderado')),
 sinais_alerta text[] NOT NULL DEFAULT '{}'::text[]
  CHECK (cardinality(sinais_alerta)=0),
 situacao text NOT NULL DEFAULT 'pendente'
  CHECK (situacao IN ('pendente','respondida','encerrada_sem_resposta')),
 versao_termo text NOT NULL CHECK (length(btrim(versao_termo)) BETWEEN 3 AND 40),
 confirmou_nao_urgencia boolean NOT NULL CHECK (confirmou_nao_urgencia IS TRUE),
 confirmou_resposta_facultativa boolean NOT NULL CHECK (confirmou_resposta_facultativa IS TRUE),
 confirmou_visibilidade_anonimizada boolean NOT NULL
  CHECK (confirmou_visibilidade_anonimizada IS TRUE),
 confirmou_ubs_exclusiva boolean NOT NULL CHECK (confirmou_ubs_exclusiva IS TRUE),
 criada_em timestamptz NOT NULL DEFAULT now(),
 atualizada_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS duvidas_fila_ubs
 ON petita_atendimento.duvidas(ubs_codigo,situacao,criada_em DESC);

-- Vinculo real requer confirmacao administrativa, nao simples escolha da usuaria.
CREATE TABLE IF NOT EXISTS petita_privado.solicitacoes_vinculo_gestantes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 usuario_id uuid NOT NULL REFERENCES petita_atendimento.acessos(usuario_id),
 ubs_codigo text NOT NULL REFERENCES public.ubs(code),
 situacao text NOT NULL DEFAULT 'pendente'
   CHECK (situacao IN ('pendente','aprovada','recusada','cancelada')),
 solicitado_em timestamptz NOT NULL DEFAULT now(),
 decidido_por uuid REFERENCES petita_atendimento.acessos(usuario_id),
 decidido_em timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS vinculo_gestante_pendente_usuario
 ON petita_privado.solicitacoes_vinculo_gestantes(usuario_id)
 WHERE situacao = 'pendente';
REVOKE ALL ON petita_privado.solicitacoes_vinculo_gestantes FROM PUBLIC;
ALTER TABLE petita_privado.solicitacoes_vinculo_gestantes ENABLE ROW LEVEL SECURITY;

-- Esta ligacao privada NUNCA e incluida na fila da equipe.
CREATE TABLE IF NOT EXISTS petita_privado.autoria_duvidas (
 duvida_id uuid PRIMARY KEY REFERENCES petita_atendimento.duvidas(id) ON DELETE CASCADE,
 gestante_usuario_id uuid NOT NULL REFERENCES petita_atendimento.acessos(usuario_id),
 vinculada_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS autoria_por_gestante
 ON petita_privado.autoria_duvidas(gestante_usuario_id);

CREATE TABLE IF NOT EXISTS petita_atendimento.respostas (
 duvida_id uuid PRIMARY KEY REFERENCES petita_atendimento.duvidas(id),
 texto text NOT NULL CHECK (length(btrim(texto)) BETWEEN 3 AND 4000),
 respondida_por uuid NOT NULL REFERENCES petita_atendimento.acessos(usuario_id),
 respondida_em timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS petita_atendimento.eventos_auditoria (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 ator_usuario_id uuid NOT NULL,
 acao text NOT NULL CHECK (acao IN (
  'solicitacao_aprovada','solicitacao_recusada','equipe_desativada',
  'ubs_vinculada','duvida_respondida','duvida_encerrada'
 )),
 referencia_id uuid,
 quando timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE VIEW petita_atendimento.fila_anonima AS
 SELECT id,codigo_publico,ubs_codigo,categoria,texto,nivel_percebido,situacao,criada_em
 FROM petita_atendimento.duvidas;

REVOKE ALL ON ALL TABLES IN SCHEMA petita_atendimento FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA petita_privado FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA petita_atendimento FROM PUBLIC;
ALTER TABLE petita_atendimento.acessos ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_atendimento.vinculos_equipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_atendimento.solicitacoes_acesso ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_atendimento.duvidas ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_atendimento.respostas ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_atendimento.eventos_auditoria ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_privado.vinculos_gestantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_privado.autoria_duvidas ENABLE ROW LEVEL SECURITY;
-- Ausencia de policies libera acesso SOMENTE pelo backend DB autorizado.
-- O backend devera validar JWT Neon, permissoes e vinculo antes de toda operacao.
