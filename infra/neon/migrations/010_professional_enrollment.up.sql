-- Homologation only. Authentication stays mandatory; professional approval is manual.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5,6,7,8,9]
 THEN RAISE EXCEPTION 'isolated homologation with exact migrations 001-009 required'; END IF;
END $$;
SET LOCAL ROLE petita_schema_owner;
ALTER TABLE petita.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE petita.profiles ADD CONSTRAINT profiles_role_check CHECK(role IN ('patient','professional_pending','ubs_team','admin'));
ALTER POLICY enrollment_patient_insert ON petita.profiles WITH CHECK(role IN ('patient','professional_pending') AND active AND ubs_code IS NULL);
ALTER POLICY access_profiles_update ON petita.profiles USING ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND active AND role IN ('patient','professional_pending','ubs_team')) WITH CHECK ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND role IN ('patient','professional_pending','ubs_team'));
GRANT CREATE ON SCHEMA petita TO petita_enrollment_executor,petita_access_executor;
SET LOCAL ROLE petita_enrollment_executor;
CREATE OR REPLACE FUNCTION petita.auth_identity_active()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
 SELECT EXISTS (
   SELECT 1 FROM petita_private.auth_provider_config c
   JOIN neon_auth."user" u ON u.id::text=nullif(current_setting('petita.subject',true),'')
   LEFT JOIN petita_private.identities i ON i.subject=u.id::text AND i.issuer=c.issuer
   LEFT JOIN petita.profiles p ON p.id=i.profile_id
   WHERE c.issuer=nullif(current_setting('petita.issuer',true),'') AND u.banned IS FALSE
     AND (i.profile_id IS NULL OR p.active)
 )
$function$;
CREATE OR REPLACE FUNCTION petita.ensure_professional_profile()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE v_id uuid; v_name text; v_subject text:=nullif(current_setting('petita.subject',true),''); v_issuer text:=nullif(current_setting('petita.issuer',true),'');
BEGIN
 IF NOT petita.auth_identity_active() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(v_issuer||':'||v_subject,0));
 SELECT i.profile_id INTO v_id FROM petita_private.identities i WHERE i.issuer=v_issuer AND i.subject=v_subject;
 IF FOUND THEN
   IF NOT EXISTS(SELECT 1 FROM petita.profiles p WHERE p.id=v_id AND p.active) THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
   RETURN v_id;
 END IF;
 SELECT left(coalesce(nullif(btrim(u.name),''),'Profissional'),240) INTO v_name FROM neon_auth."user" u WHERE u.id::text=v_subject AND u.banned IS FALSE;
 IF NOT FOUND THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 v_id:=gen_random_uuid();
 INSERT INTO petita.profiles(id,display_name,role) VALUES(v_id,v_name,'professional_pending');
 INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES(v_issuer,v_subject,v_id);
 RETURN v_id;
END $function$;
REVOKE ALL ON FUNCTION petita.ensure_professional_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.ensure_professional_profile() TO petita_runtime;
SET LOCAL ROLE petita_access_executor;
CREATE OR REPLACE FUNCTION petita.request_ubs_team_access(p_ubs_code text, p_idempotency_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE actor uuid; r petita_private.team_access_requests;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF actor IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||actor::text,0));
  IF NOT EXISTS(SELECT FROM petita.profiles WHERE id=actor AND active AND role IN ('professional_pending','ubs_team')) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_idempotency_key IS NULL OR p_ubs_code IS NULL OR NOT EXISTS(SELECT FROM petita.ubs WHERE code=p_ubs_code AND active) THEN
    RAISE EXCEPTION 'invalid_access_request' USING ERRCODE='22023';
  END IF;
  SELECT * INTO r FROM petita_private.team_access_requests WHERE requester_id=actor AND idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF r.requested_ubs_code<>p_ubs_code THEN RAISE EXCEPTION 'idempotency_conflict' USING ERRCODE='P0001'; END IF;
    RETURN jsonb_build_object('id',r.id,'status',r.status);
  END IF;
  IF petita_private.team_ubs() IS NOT NULL OR EXISTS(SELECT FROM petita_private.team_access_requests WHERE requester_id=actor AND status='pending') THEN
    RAISE EXCEPTION 'access_request_conflict' USING ERRCODE='P0001';
  END IF;
  INSERT INTO petita_private.team_access_requests(requester_id,requested_ubs_code,idempotency_key)
    VALUES(actor,p_ubs_code,p_idempotency_key) RETURNING * INTO r;
  RETURN jsonb_build_object('id',r.id,'status',r.status);
END $function$;
CREATE OR REPLACE FUNCTION petita.decide_team_access_request(p_request_id uuid, p_approve boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE actor uuid; r petita_private.team_access_requests;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  IF p_request_id IS NULL OR p_approve IS NULL THEN RAISE EXCEPTION 'invalid_decision' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM petita_private.team_access_requests WHERE id=p_request_id;
  IF NOT FOUND OR r.requester_id=actor THEN RAISE EXCEPTION 'request_unavailable' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||r.requester_id::text,0));
  -- Every participant locks actor before request; competing decisions serialize.
  SELECT * INTO r FROM petita_private.team_access_requests WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
  IF NOT petita_private.is_admin() OR NOT EXISTS(SELECT FROM petita.profiles WHERE id=r.requester_id AND active AND role IN ('professional_pending','ubs_team')) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS(SELECT FROM petita.ubs WHERE code=r.requested_ubs_code AND active) THEN
    RAISE EXCEPTION 'unit_unavailable' USING ERRCODE='42501';
  END IF;
  IF r.status<>'pending' THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
  UPDATE petita_private.team_access_requests SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    decided_by=actor,decided_at=statement_timestamp() WHERE id=r.id RETURNING * INTO r;
  IF p_approve THEN
    UPDATE petita.profiles SET role='ubs_team' WHERE id=r.requester_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'request_conflict' USING ERRCODE='P0001'; END IF;
    INSERT INTO petita_private.ubs_memberships(profile_id,ubs_code,active,approved_by,approved_at)
      VALUES(r.requester_id,r.requested_ubs_code,true,actor,r.decided_at)
      ON CONFLICT(profile_id) DO UPDATE SET ubs_code=excluded.ubs_code,active=true,
        approved_by=excluded.approved_by,approved_at=excluded.approved_at;
  END IF;
  INSERT INTO petita_private.team_access_events(request_id,target_profile_id,ubs_code,actor_id,event)
    VALUES(r.id,r.requester_id,r.requested_ubs_code,actor,r.status);
  RETURN jsonb_build_object('id',r.id,'status',r.status,'decided_by',r.decided_by,'decided_at',r.decided_at);
END $function$;
CREATE FUNCTION petita.list_my_professional_requests() RETURNS TABLE(id uuid,requested_ubs_code text,status text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT r.id,r.requested_ubs_code,r.status,r.created_at FROM petita_private.team_access_requests r
 JOIN petita.profiles p ON p.id=r.requester_id WHERE r.requester_id=petita_private.actor_id() AND p.active AND p.role IN ('professional_pending','ubs_team') ORDER BY r.created_at DESC LIMIT 10
$$;
REVOKE ALL ON FUNCTION petita.list_my_professional_requests() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.list_my_professional_requests() TO petita_runtime;
CREATE FUNCTION petita.list_professional_approvals() RETURNS TABLE(id uuid,requester_id uuid,display_name text,requested_ubs_code text,status text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.id,r.requester_id,p.display_name,r.requested_ubs_code,r.status,r.created_at FROM petita_private.team_access_requests r JOIN petita.profiles p ON p.id=r.requester_id WHERE r.status='pending' AND p.active AND p.role IN ('professional_pending','ubs_team') ORDER BY r.created_at,r.id LIMIT 50;
END $$;
REVOKE ALL ON FUNCTION petita.list_professional_approvals() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.list_professional_approvals() TO petita_runtime;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_enrollment_executor,petita_access_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(10);
COMMIT;
