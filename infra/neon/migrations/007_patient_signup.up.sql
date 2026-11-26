-- Additive homologation migration. Never apply to an unspecified/default branch.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5,6]
 THEN RAISE EXCEPTION 'isolated homologation with exact migrations 001-006 required'; END IF;
END $$;
SET LOCAL ROLE petita_schema_owner;
GRANT CREATE ON SCHEMA petita TO petita_enrollment_executor;
SET LOCAL ROLE petita_enrollment_executor;
CREATE OR REPLACE FUNCTION petita.auth_identity_active() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT EXISTS (
   SELECT 1 FROM petita_private.auth_provider_config c
   JOIN neon_auth."user" u ON u.id::text=nullif(current_setting('petita.subject',true),'')
   LEFT JOIN petita_private.identities i ON i.subject=u.id::text AND i.issuer=c.issuer
   LEFT JOIN petita.profiles p ON p.id=i.profile_id
   WHERE c.issuer=nullif(current_setting('petita.issuer',true),'') AND u.banned IS FALSE
     AND (i.profile_id IS NULL OR (p.active AND (p.role='patient' OR u."emailVerified" IS TRUE)))
 )
$$;
CREATE OR REPLACE FUNCTION petita.ensure_patient_profile() RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_name text; v_subject text:=nullif(current_setting('petita.subject',true),''); v_issuer text:=nullif(current_setting('petita.issuer',true),'');
BEGIN
 IF NOT petita.auth_identity_active() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_issuer||':'||v_subject,0));
 SELECT i.profile_id INTO v_id FROM petita_private.identities i WHERE i.issuer=v_issuer AND i.subject=v_subject;
 IF FOUND THEN
   IF NOT EXISTS(SELECT 1 FROM petita.profiles p WHERE p.id=v_id AND p.active) THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
   RETURN v_id;
 END IF;
 SELECT left(coalesce(nullif(btrim(u.name),''),'Gestante'),240) INTO v_name FROM neon_auth."user" u WHERE u.id::text=v_subject AND u.banned IS FALSE;
 IF NOT FOUND THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 v_id:=gen_random_uuid();
 INSERT INTO petita.profiles(id,display_name,role) VALUES(v_id,v_name,'patient');
 INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES(v_issuer,v_subject,v_id);
 RETURN v_id;
END $$;

SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_enrollment_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(7);
COMMIT;
