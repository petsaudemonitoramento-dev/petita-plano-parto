-- Foundation only. Never apply to institutional main as part of CI.
-- Caller must explicitly select an isolated database and set this session guard.
BEGIN;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target', true) IS DISTINCT FROM 'isolated-homologation' THEN
    RAISE EXCEPTION 'isolated homologation target must be explicitly selected';
  END IF;
  IF EXISTS (SELECT FROM pg_namespace WHERE nspname IN ('petita', 'petita_private')) THEN
    RAISE EXCEPTION 'foundation already exists: inspect migration history instead of overwriting';
  END IF;
END
$guard$;

-- No credentials or LOGIN roles are provisioned by a schema migration.
DO $roles$
DECLARE role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['petita_schema_owner', 'petita_authorizer', 'petita_runtime'] LOOP
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS', role_name);
    END IF;
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = role_name
               AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolbypassrls)) THEN
      RAISE EXCEPTION 'unsafe attributes on existing role %', role_name;
    END IF;
    IF EXISTS (SELECT FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member WHERE r.rolname = role_name) THEN
      RAISE EXCEPTION 'application roles must not inherit other roles';
    END IF;
  END LOOP;
END
$roles$;
-- Only the migration identity gets ownership capabilities, never the runtime.
GRANT petita_schema_owner, petita_authorizer TO CURRENT_USER;
CREATE SCHEMA petita AUTHORIZATION petita_schema_owner;
CREATE SCHEMA petita_private AUTHORIZATION petita_schema_owner;
REVOKE ALL ON SCHEMA petita, petita_private FROM PUBLIC;
SET LOCAL ROLE petita_schema_owner;

CREATE TABLE petita.ubs (
  code text PRIMARY KEY CHECK (length(btrim(code)) BETWEEN 1 AND 80),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 240),
  city text,
  state text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE petita.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name text NOT NULL DEFAULT '' CHECK (length(display_name) <= 240),
  role text NOT NULL DEFAULT 'patient' CHECK (role IN ('patient', 'ubs_team', 'admin')),
  active boolean NOT NULL DEFAULT true,
  ubs_code text REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX profiles_ubs_idx ON petita.profiles(ubs_code);

-- Opaque (issuer, subject), independent of internal UUID and legacy provider.
-- Never populated from an unverified client-supplied email or metadata.
CREATE TABLE petita_private.identities (
  issuer text NOT NULL CHECK (length(btrim(issuer)) BETWEEN 1 AND 2048),
  subject text NOT NULL CHECK (length(btrim(subject)) BETWEEN 1 AND 512),
  profile_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (issuer, subject),
  UNIQUE (profile_id, issuer)
);

-- One approved UBS per team member matches the current application scope.
CREATE TABLE petita_private.ubs_memberships (
  profile_id uuid PRIMARY KEY REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  ubs_code text NOT NULL REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  active boolean NOT NULL DEFAULT true,
  approved_by uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  approved_at timestamptz NOT NULL,
  CHECK (approved_by <> profile_id)
);
CREATE INDEX memberships_ubs_idx ON petita_private.ubs_memberships(ubs_code) WHERE active;

CREATE TABLE petita.birth_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  ubs_code text REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  patient_name text CHECK (length(patient_name) <= 240),
  dpp date,
  companion text CHECK (length(companion) <= 1000),
  answers_json jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(answers_json) = 'object'),
  pdf_generated_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX birth_plans_patient_updated_idx ON petita.birth_plans(patient_id, updated_at DESC);

CREATE FUNCTION petita_private.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  NEW.updated_at := statement_timestamp();
  RETURN NEW;
END
$$;
CREATE TRIGGER profiles_updated BEFORE UPDATE ON petita.profiles
  FOR EACH ROW EXECUTE FUNCTION petita_private.touch_updated_at();
CREATE TRIGGER plans_updated BEFORE UPDATE ON petita.birth_plans
  FOR EACH ROW EXECUTE FUNCTION petita_private.touch_updated_at();

-- These helpers run as a dedicated NOLOGIN/NOBYPASSRLS reader, not the owner.
-- Context is set by a trusted backend after token verification, SET LOCAL only.
-- No SQL/Data API access to this role or these context setters in the APK.
CREATE FUNCTION petita_private.actor_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT p.id
  FROM petita_private.identities i JOIN petita.profiles p ON p.id = i.profile_id
  WHERE i.issuer = nullif(current_setting('petita.issuer', true), '')
    AND i.subject = nullif(current_setting('petita.subject', true), '') AND p.active
$$;
CREATE FUNCTION petita_private.is_patient() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT EXISTS (SELECT FROM petita.profiles WHERE id = petita_private.actor_id() AND role = 'patient' AND active)
$$;
CREATE FUNCTION petita_private.actor_ubs() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT ubs_code FROM petita.profiles WHERE id = petita_private.actor_id() AND active
$$;
CREATE FUNCTION petita_private.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT EXISTS (SELECT FROM petita.profiles WHERE id = petita_private.actor_id() AND role = 'admin' AND active)
$$;
CREATE FUNCTION petita_private.team_ubs() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT m.ubs_code FROM petita_private.ubs_memberships m
  JOIN petita.profiles p ON p.id = m.profile_id JOIN petita.ubs u ON u.code = m.ubs_code
  WHERE m.profile_id = petita_private.actor_id() AND p.role = 'ubs_team' AND p.active AND m.active AND u.active
$$;

ALTER TABLE petita.ubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.ubs FORCE ROW LEVEL SECURITY;
ALTER TABLE petita.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE petita.birth_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.birth_plans FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.identities FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.ubs_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.ubs_memberships FORCE ROW LEVEL SECURITY;

-- Explicit narrow helper privileges avoid recursive profile RLS checks.
CREATE POLICY authorizer_ubs ON petita.ubs FOR SELECT TO petita_authorizer USING (true);
CREATE POLICY authorizer_profiles ON petita.profiles FOR SELECT TO petita_authorizer USING (true);
CREATE POLICY authorizer_identities ON petita_private.identities FOR SELECT TO petita_authorizer USING (true);
CREATE POLICY authorizer_memberships ON petita_private.ubs_memberships FOR SELECT TO petita_authorizer USING (true);
GRANT USAGE ON SCHEMA petita, petita_private TO petita_authorizer;
GRANT SELECT ON petita.ubs, petita.profiles, petita_private.identities, petita_private.ubs_memberships TO petita_authorizer;

CREATE POLICY active_ubs ON petita.ubs FOR SELECT TO petita_runtime USING (active);
CREATE POLICY own_profile_read ON petita.profiles FOR SELECT TO petita_runtime
  USING (id = (SELECT petita_private.actor_id()));
CREATE POLICY own_profile_update ON petita.profiles FOR UPDATE TO petita_runtime
  USING (id = (SELECT petita_private.actor_id())) WITH CHECK (id = (SELECT petita_private.actor_id()));
CREATE POLICY own_plan_read ON petita.birth_plans FOR SELECT TO petita_runtime
  USING ((SELECT petita_private.is_patient()) AND patient_id = (SELECT petita_private.actor_id()));
CREATE POLICY own_plan_insert ON petita.birth_plans FOR INSERT TO petita_runtime
  WITH CHECK ((SELECT petita_private.is_patient()) AND patient_id = (SELECT petita_private.actor_id())
    AND ubs_code IS NOT DISTINCT FROM (SELECT petita_private.actor_ubs())
    AND (ubs_code IS NULL OR EXISTS (SELECT FROM petita.ubs u WHERE u.code = birth_plans.ubs_code AND u.active)));
CREATE POLICY own_plan_update ON petita.birth_plans FOR UPDATE TO petita_runtime
  USING ((SELECT petita_private.is_patient()) AND patient_id = (SELECT petita_private.actor_id()))
  WITH CHECK ((SELECT petita_private.is_patient()) AND patient_id = (SELECT petita_private.actor_id())
    AND ubs_code IS NOT DISTINCT FROM (SELECT petita_private.actor_ubs())
    AND (ubs_code IS NULL OR EXISTS (SELECT FROM petita.ubs u WHERE u.code = birth_plans.ubs_code AND u.active)));
CREATE POLICY own_plan_delete ON petita.birth_plans FOR DELETE TO petita_runtime
  USING ((SELECT petita_private.is_patient()) AND patient_id = (SELECT petita_private.actor_id()));

GRANT USAGE ON SCHEMA petita, petita_private TO petita_runtime;
GRANT SELECT ON petita.ubs, petita.profiles, petita.birth_plans TO petita_runtime;
GRANT UPDATE (display_name) ON petita.profiles TO petita_runtime;
GRANT INSERT (id, patient_id, ubs_code, patient_name, dpp, companion, answers_json, pdf_generated_at),
      UPDATE (ubs_code, patient_name, dpp, companion, answers_json, pdf_generated_at), DELETE
  ON petita.birth_plans TO petita_runtime;
GRANT EXECUTE ON FUNCTION petita_private.actor_id(), petita_private.is_patient(), petita_private.actor_ubs(),
  petita_private.is_admin(), petita_private.team_ubs() TO petita_runtime, petita_authorizer;
-- A schema-local default REVOKE cannot undo PostgreSQL's global default EXECUTE.
-- Explicitly revoke on every function before this transaction becomes visible.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA petita_private FROM PUBLIC;

-- PostgreSQL requires CREATE in the schema when changing function ownership.
GRANT CREATE ON SCHEMA petita_private TO petita_authorizer;
RESET ROLE;
ALTER FUNCTION petita_private.actor_id() OWNER TO petita_authorizer;
ALTER FUNCTION petita_private.is_patient() OWNER TO petita_authorizer;
ALTER FUNCTION petita_private.actor_ubs() OWNER TO petita_authorizer;
ALTER FUNCTION petita_private.is_admin() OWNER TO petita_authorizer;
ALTER FUNCTION petita_private.team_ubs() OWNER TO petita_authorizer;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita_private FROM petita_authorizer;
CREATE TABLE petita_private.schema_migrations (
  version integer PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON ALL TABLES IN SCHEMA petita_private FROM PUBLIC, petita_runtime;
INSERT INTO petita_private.schema_migrations(version) VALUES (1);
COMMIT;
