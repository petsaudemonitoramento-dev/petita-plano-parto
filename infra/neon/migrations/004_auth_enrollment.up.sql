-- Apply in a transaction to isolated Neon homologation. Configure petita.migration_target and petita.auth_issuer via transaction-local settings before running.
BEGIN;
DO $$ BEGIN IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation' OR (select array_agg(version order by version) from petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3] THEN RAISE EXCEPTION 'isolated target with migrations 001-003 required'; END IF; END $$;

CREATE ROLE petita_enrollment_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;

GRANT petita_enrollment_executor TO CURRENT_USER;

GRANT USAGE ON SCHEMA neon_auth TO petita_enrollment_executor;

GRANT SELECT(id,name,"emailVerified",banned) ON neon_auth."user" TO petita_enrollment_executor;

SET LOCAL ROLE petita_schema_owner;

CREATE TABLE petita_private.auth_provider_config (singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),issuer text NOT NULL CHECK(length(issuer) BETWEEN 10 AND 2048));

INSERT INTO petita_private.auth_provider_config(singleton,issuer) VALUES(true,current_setting('petita.auth_issuer'));

REVOKE ALL ON petita_private.auth_provider_config FROM PUBLIC,petita_runtime;

ALTER TABLE petita_private.auth_provider_config ENABLE ROW LEVEL SECURITY;

ALTER TABLE petita_private.auth_provider_config FORCE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA petita,petita_private TO petita_enrollment_executor;

GRANT SELECT ON petita_private.auth_provider_config TO petita_enrollment_executor;

CREATE POLICY enrollment_provider ON petita_private.auth_provider_config FOR SELECT TO petita_enrollment_executor USING(true);

GRANT SELECT(id,active,role),INSERT(id,display_name,role) ON petita.profiles TO petita_enrollment_executor;

GRANT SELECT(issuer,subject,profile_id),INSERT(issuer,subject,profile_id) ON petita_private.identities TO petita_enrollment_executor;

CREATE POLICY enrollment_identity_read ON petita_private.identities FOR SELECT TO petita_enrollment_executor USING(issuer=nullif(current_setting('petita.issuer',true),'') AND subject=nullif(current_setting('petita.subject',true),''));

CREATE POLICY enrollment_identity_insert ON petita_private.identities FOR INSERT TO petita_enrollment_executor WITH CHECK(issuer=nullif(current_setting('petita.issuer',true),'') AND subject=nullif(current_setting('petita.subject',true),''));

CREATE POLICY enrollment_profile_read ON petita.profiles FOR SELECT TO petita_enrollment_executor USING(EXISTS(SELECT 1 FROM petita_private.identities i WHERE i.profile_id=id));

CREATE POLICY enrollment_patient_insert ON petita.profiles FOR INSERT TO petita_enrollment_executor WITH CHECK(role='patient' AND active AND ubs_code IS NULL);

CREATE FUNCTION petita.auth_identity_active() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$ SELECT EXISTS(SELECT 1 FROM petita_private.auth_provider_config c JOIN neon_auth."user" u ON u.id::text=nullif(current_setting('petita.subject',true),'') WHERE c.issuer=nullif(current_setting('petita.issuer',true),'') AND u."emailVerified" IS TRUE AND u.banned IS FALSE) $$;

CREATE FUNCTION petita.ensure_patient_profile() RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_name text; v_subject text:=nullif(current_setting('petita.subject',true),''); v_issuer text:=nullif(current_setting('petita.issuer',true),'');
BEGIN
 IF NOT petita.auth_identity_active() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_issuer||':'||v_subject,0));
 SELECT i.profile_id INTO v_id FROM petita_private.identities i WHERE i.issuer=v_issuer AND i.subject=v_subject;
 IF FOUND THEN
   IF NOT EXISTS(SELECT 1 FROM petita.profiles p WHERE p.id=v_id AND p.active) THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
   RETURN v_id;
 END IF;
 SELECT left(coalesce(nullif(btrim(u.name),''),'Gestante'),240) INTO v_name FROM neon_auth."user" u WHERE u.id::text=v_subject AND u."emailVerified" IS TRUE AND u.banned IS FALSE;
 IF NOT FOUND THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 v_id:=gen_random_uuid();
 INSERT INTO petita.profiles(id,display_name,role) VALUES(v_id,v_name,'patient');
 INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES(v_issuer,v_subject,v_id);
 RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION petita.auth_identity_active(),petita.ensure_patient_profile() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION petita.auth_identity_active(),petita.ensure_patient_profile() TO petita_runtime,petita_enrollment_executor;

GRANT CREATE ON SCHEMA petita TO petita_enrollment_executor;

RESET ROLE;

ALTER FUNCTION petita.auth_identity_active() OWNER TO petita_enrollment_executor;

ALTER FUNCTION petita.ensure_patient_profile() OWNER TO petita_enrollment_executor;

SET LOCAL ROLE petita_schema_owner;

REVOKE CREATE ON SCHEMA petita FROM petita_enrollment_executor;

INSERT INTO petita_private.schema_migrations(version) VALUES(4);
COMMIT;
