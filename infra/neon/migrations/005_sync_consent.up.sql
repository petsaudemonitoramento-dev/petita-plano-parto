-- Homologation only; no historical acceptance inferred. Online sync requires a distinct user action.
BEGIN;
DO $$ BEGIN IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation' OR (select array_agg(version order by version) from petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4] THEN RAISE EXCEPTION 'isolated target with migrations 001-004 required'; END IF; END $$;

SET LOCAL ROLE petita_schema_owner;

CREATE TABLE petita.sync_consent_events (id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,patient_id uuid NOT NULL REFERENCES petita.profiles(id),terms_version text NOT NULL CHECK(terms_version='2026-10-21-v1'),operation_id uuid NOT NULL,action text NOT NULL CHECK(action IN ('grant','withdraw')),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(patient_id,operation_id));

ALTER TABLE petita.sync_consent_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE petita.sync_consent_events FORCE ROW LEVEL SECURITY;

REVOKE ALL ON petita.sync_consent_events FROM PUBLIC;

GRANT SELECT ON petita.sync_consent_events TO petita_runtime;

GRANT INSERT(patient_id,terms_version,operation_id,action) ON petita.sync_consent_events TO petita_runtime;

GRANT USAGE ON SEQUENCE petita.sync_consent_events_id_seq TO petita_runtime;

CREATE POLICY own_sync_consent_read ON petita.sync_consent_events FOR SELECT TO petita_runtime USING(petita_private.is_patient() AND patient_id=petita_private.actor_id());

CREATE POLICY own_sync_consent_append ON petita.sync_consent_events FOR INSERT TO petita_runtime WITH CHECK(petita_private.is_patient() AND patient_id=petita_private.actor_id());

CREATE FUNCTION petita.has_sync_consent() RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT coalesce((SELECT action='grant' FROM petita.sync_consent_events WHERE patient_id=petita_private.actor_id() ORDER BY id DESC LIMIT 1),false) $$;

REVOKE EXECUTE ON FUNCTION petita.has_sync_consent() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION petita.has_sync_consent() TO petita_runtime;

ALTER TABLE petita.birth_plans ADD COLUMN revision integer NOT NULL DEFAULT 1 CHECK(revision>0);

GRANT UPDATE(revision) ON petita.birth_plans TO petita_runtime;

CREATE POLICY sync_consent_insert ON petita.birth_plans AS RESTRICTIVE FOR INSERT TO petita_runtime WITH CHECK(petita.has_sync_consent());

CREATE POLICY sync_consent_update ON petita.birth_plans AS RESTRICTIVE FOR UPDATE TO petita_runtime USING(petita.has_sync_consent()) WITH CHECK(petita.has_sync_consent());

INSERT INTO petita_private.schema_migrations(version) VALUES(5);
COMMIT;
