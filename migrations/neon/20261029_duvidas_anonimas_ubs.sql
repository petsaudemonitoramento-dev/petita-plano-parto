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
