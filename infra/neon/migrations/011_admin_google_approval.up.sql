-- Isolated homologation only. Separate authentication from admin authorization.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5,6,7,8,9,10]
 THEN RAISE EXCEPTION 'isolated homologation with migrations 001-010 required'; END IF;
END $$;
CREATE ROLE petita_admin_request_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
GRANT petita_admin_request_executor TO CURRENT_USER;
GRANT USAGE ON SCHEMA neon_auth TO petita_enrollment_executor,petita_admin_request_executor;
GRANT SELECT(id,name,email,"emailVerified",banned) ON neon_auth."user" TO petita_enrollment_executor,petita_admin_request_executor;
GRANT SELECT("userId","providerId") ON neon_auth.account TO petita_enrollment_executor,petita_admin_request_executor;
SET LOCAL ROLE petita_schema_owner;
ALTER TABLE petita.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE petita.profiles ADD CONSTRAINT profiles_role_check CHECK(role IN ('patient','professional_pending','ubs_team','admin_pending','admin'));
ALTER POLICY enrollment_patient_insert ON petita.profiles WITH CHECK(role IN ('patient','professional_pending','admin_pending') AND active AND ubs_code IS NULL);
CREATE TABLE petita_private.admin_access_requests (
 requester_id uuid PRIMARY KEY REFERENCES petita.profiles(id) ON DELETE RESTRICT,
 email text NOT NULL CHECK(length(email) BETWEEN 3 AND 320),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(),
 decided_at timestamptz,
 decided_by uuid REFERENCES petita.profiles(id) ON DELETE RESTRICT,
 CHECK(decided_by IS NULL OR decided_by<>requester_id),
 CHECK((status='pending' AND decided_at IS NULL AND decided_by IS NULL) OR (status IN ('approved','rejected') AND decided_at IS NOT NULL AND decided_by IS NOT NULL))
);
ALTER TABLE petita_private.admin_access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.admin_access_requests FORCE ROW LEVEL SECURITY;
REVOKE ALL ON petita_private.admin_access_requests FROM PUBLIC,petita_runtime;
GRANT USAGE ON SCHEMA petita,petita_private TO petita_admin_request_executor;
GRANT SELECT ON petita.profiles,petita_private.identities,petita_private.admin_access_requests,petita_private.auth_provider_config TO petita_admin_request_executor;
GRANT UPDATE(role) ON petita.profiles TO petita_admin_request_executor;
GRANT UPDATE(status,decided_at,decided_by) ON petita_private.admin_access_requests TO petita_admin_request_executor;
GRANT SELECT,INSERT ON petita_private.admin_access_requests TO petita_enrollment_executor;
CREATE POLICY admin_request_enroll_read ON petita_private.admin_access_requests FOR SELECT TO petita_enrollment_executor USING (EXISTS(SELECT 1 FROM petita_private.identities i WHERE i.profile_id=requester_id));
CREATE POLICY admin_request_enroll_insert ON petita_private.admin_access_requests FOR INSERT TO petita_enrollment_executor WITH CHECK(status='pending' AND decided_by IS NULL AND decided_at IS NULL AND EXISTS(SELECT 1 FROM petita_private.identities i WHERE i.profile_id=requester_id));
CREATE POLICY admin_request_access_read ON petita_private.admin_access_requests FOR SELECT TO petita_admin_request_executor USING ((SELECT petita_private.is_admin()) OR requester_id=(SELECT petita_private.actor_id()));
CREATE POLICY admin_request_access_decide ON petita_private.admin_access_requests FOR UPDATE TO petita_admin_request_executor
 USING ((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id()) AND status='pending')
 WITH CHECK ((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id()) AND decided_by=(SELECT petita_private.actor_id()) AND status IN ('approved','rejected'));
CREATE POLICY admin_request_profiles_read ON petita.profiles FOR SELECT TO petita_admin_request_executor USING ((SELECT petita_private.is_admin()) OR id=(SELECT petita_private.actor_id()));
CREATE POLICY admin_request_identity_read ON petita_private.identities FOR SELECT TO petita_admin_request_executor USING ((SELECT petita_private.is_admin()) OR profile_id=(SELECT petita_private.actor_id()));
CREATE POLICY admin_request_provider_read ON petita_private.auth_provider_config FOR SELECT TO petita_admin_request_executor USING(true);
CREATE POLICY admin_request_profiles_promote ON petita.profiles FOR UPDATE TO petita_admin_request_executor
 USING ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND active AND role='admin_pending' AND ubs_code IS NULL)
 WITH CHECK ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND active AND role='admin' AND ubs_code IS NULL AND EXISTS(SELECT 1 FROM petita_private.admin_access_requests r WHERE r.requester_id=id AND r.status='approved' AND r.decided_by=(SELECT petita_private.actor_id())));
GRANT CREATE ON SCHEMA petita TO petita_enrollment_executor,petita_admin_request_executor;
SET LOCAL ROLE petita_authorizer;
GRANT EXECUTE ON FUNCTION petita_private.actor_id(),petita_private.is_admin() TO petita_admin_request_executor;
SET LOCAL ROLE petita_enrollment_executor;
CREATE FUNCTION petita.ensure_admin_candidate() RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_name text; v_email text; v_role text; v_subject text:=nullif(current_setting('petita.subject',true),''); v_issuer text:=nullif(current_setting('petita.issuer',true),'');
BEGIN
 IF NOT petita.auth_identity_active() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_issuer||':'||v_subject,0));
 SELECT i.profile_id,p.role INTO v_id,v_role FROM petita_private.identities i JOIN petita.profiles p ON p.id=i.profile_id AND p.active WHERE i.issuer=v_issuer AND i.subject=v_subject;
 IF v_role='admin' THEN RETURN v_id; END IF;
 IF v_id IS NOT NULL AND v_role IS DISTINCT FROM 'admin_pending' THEN RAISE EXCEPTION 'separate_admin_account_required' USING ERRCODE='42501'; END IF;
 SELECT left(coalesce(nullif(btrim(u.name),''),'Administrador'),240),u.email INTO v_name,v_email
 FROM neon_auth."user" u WHERE u.id::text=v_subject AND u."emailVerified" IS TRUE AND u.banned IS FALSE AND length(u.email) BETWEEN 3 AND 320
 AND EXISTS(SELECT 1 FROM neon_auth.account a WHERE a."userId"=u.id AND a."providerId"='google');
 IF NOT FOUND THEN RAISE EXCEPTION 'verified_google_identity_required' USING ERRCODE='42501'; END IF;
 IF v_id IS NULL THEN
   v_id:=gen_random_uuid();
   INSERT INTO petita.profiles(id,display_name,role) VALUES(v_id,v_name,'admin_pending');
   INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES(v_issuer,v_subject,v_id);
 END IF;
 INSERT INTO petita_private.admin_access_requests(requester_id,email) VALUES(v_id,v_email) ON CONFLICT(requester_id) DO NOTHING;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION petita.ensure_admin_candidate() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.ensure_admin_candidate() TO petita_runtime;
SET LOCAL ROLE petita_admin_request_executor;
CREATE FUNCTION petita.my_admin_request() RETURNS TABLE(status text,created_at timestamptz) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT r.status,r.created_at FROM petita_private.admin_access_requests r WHERE r.requester_id=petita_private.actor_id()
$$;
CREATE FUNCTION petita.list_admin_requests() RETURNS TABLE(requester_id uuid,display_name text,email text,status text,created_at timestamptz) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.requester_id,p.display_name,r.email,r.status,r.created_at FROM petita_private.admin_access_requests r JOIN petita.profiles p ON p.id=r.requester_id WHERE r.status='pending' AND p.active AND p.role='admin_pending' ORDER BY r.created_at,r.requester_id LIMIT 50;
END $$;
CREATE FUNCTION petita.decide_admin_request(p_requester uuid,p_approve boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid:=petita_private.actor_id(); r petita_private.admin_access_requests; v_status text;
BEGIN
 IF NOT petita_private.is_admin() OR p_requester IS NULL OR p_approve IS NULL OR p_requester=actor THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM petita_private.admin_access_requests WHERE requester_id=p_requester FOR UPDATE;
 IF NOT FOUND OR r.status<>'pending' THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
 IF p_approve AND NOT EXISTS(SELECT 1 FROM petita.profiles p JOIN petita_private.identities i ON i.profile_id=p.id JOIN petita_private.auth_provider_config c ON c.issuer=i.issuer JOIN neon_auth."user" u ON u.id::text=i.subject WHERE p.id=p_requester AND p.active AND p.role='admin_pending' AND p.ubs_code IS NULL AND u."emailVerified" IS TRUE AND u.banned IS FALSE AND u.email=r.email AND EXISTS(SELECT 1 FROM neon_auth.account a WHERE a."userId"=u.id AND a."providerId"='google')) THEN RAISE EXCEPTION 'verified_google_identity_required' USING ERRCODE='42501'; END IF;
 v_status:=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END;
 UPDATE petita_private.admin_access_requests SET status=v_status,decided_at=now(),decided_by=actor WHERE requester_id=p_requester;
 IF NOT FOUND THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
 IF p_approve THEN
   UPDATE petita.profiles SET role='admin' WHERE id=p_requester;
   IF NOT FOUND THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
 END IF;
 RETURN v_status;
END $$;
REVOKE ALL ON FUNCTION petita.my_admin_request(),petita.list_admin_requests(),petita.decide_admin_request(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.my_admin_request(),petita.list_admin_requests(),petita.decide_admin_request(uuid,boolean) TO petita_runtime;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_enrollment_executor,petita_admin_request_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(11);
COMMIT;
