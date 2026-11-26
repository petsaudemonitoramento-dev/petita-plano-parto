BEGIN;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target', true) IS DISTINCT FROM 'isolated-homologation'
    OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2] THEN
    RAISE EXCEPTION 'isolated target with migrations 001/002 required';
  END IF;
  IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='petita_access_executor') THEN
    CREATE ROLE petita_access_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
  IF EXISTS(SELECT FROM pg_roles WHERE rolname='petita_access_executor'
    AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolbypassrls))
    OR EXISTS(SELECT FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='petita_access_executor') THEN
    RAISE EXCEPTION 'unsafe access executor';
  END IF;
END $guard$;
GRANT petita_access_executor TO CURRENT_USER;
SET LOCAL ROLE petita_schema_owner;
CREATE TABLE petita_private.team_access_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  requested_ubs_code text NOT NULL REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_by uuid REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  decided_at timestamptz,
  UNIQUE(requester_id,idempotency_key),
  CHECK ((status='pending' AND decided_by IS NULL AND decided_at IS NULL)
    OR (status<>'pending' AND decided_by IS NOT NULL AND decided_at IS NOT NULL AND decided_by<>requester_id))
);
CREATE UNIQUE INDEX one_pending_team_request_idx ON petita_private.team_access_requests(requester_id) WHERE status='pending';
CREATE INDEX team_request_queue_idx ON petita_private.team_access_requests(status,created_at,id);
CREATE TABLE petita_private.team_access_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid REFERENCES petita_private.team_access_requests(id) ON DELETE RESTRICT,
  target_profile_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  ubs_code text NOT NULL REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  event text NOT NULL CHECK(event IN ('approved','rejected','revoked')),
  reason text CHECK(length(btrim(reason)) BETWEEN 3 AND 1000),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CHECK(actor_id<>target_profile_id)
);
ALTER TABLE petita_private.team_access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.team_access_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.team_access_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.team_access_events FORCE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA petita,petita_private TO petita_access_executor;
GRANT SELECT ON petita.ubs,petita.profiles,petita_private.team_access_requests,petita_private.ubs_memberships TO petita_access_executor;
GRANT INSERT ON petita_private.team_access_requests,petita_private.ubs_memberships,petita_private.team_access_events TO petita_access_executor;
GRANT UPDATE(status,decided_by,decided_at) ON petita_private.team_access_requests TO petita_access_executor;
GRANT UPDATE(role) ON petita.profiles TO petita_access_executor;
GRANT UPDATE(ubs_code,active,approved_by,approved_at) ON petita_private.ubs_memberships TO petita_access_executor;
GRANT USAGE ON SEQUENCE petita_private.team_access_events_id_seq TO petita_access_executor;
GRANT EXECUTE ON FUNCTION petita_private.require_read_committed() TO petita_access_executor;
SET LOCAL ROLE petita_authorizer;
GRANT EXECUTE ON FUNCTION petita_private.actor_id(),petita_private.is_admin(),petita_private.team_ubs() TO petita_access_executor;
SET LOCAL ROLE petita_schema_owner;
CREATE POLICY access_ubs ON petita.ubs FOR SELECT TO petita_access_executor USING(active);
CREATE POLICY access_profiles_read ON petita.profiles FOR SELECT TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) OR id=(SELECT petita_private.actor_id()));
CREATE POLICY access_profiles_update ON petita.profiles FOR UPDATE TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND active AND role IN ('patient','ubs_team'))
  WITH CHECK ((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND role IN ('patient','ubs_team'));
CREATE POLICY access_requests_read ON petita_private.team_access_requests FOR SELECT TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) OR requester_id=(SELECT petita_private.actor_id()));
CREATE POLICY access_requests_insert ON petita_private.team_access_requests FOR INSERT TO petita_access_executor
  WITH CHECK (requester_id=(SELECT petita_private.actor_id()) AND status='pending' AND decided_by IS NULL AND decided_at IS NULL);
CREATE POLICY access_requests_decide ON petita_private.team_access_requests FOR UPDATE TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id()) AND status='pending')
  WITH CHECK ((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id())
    AND decided_by=(SELECT petita_private.actor_id()) AND status IN ('approved','rejected'));
CREATE POLICY access_memberships_read ON petita_private.ubs_memberships FOR SELECT TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) OR profile_id=(SELECT petita_private.actor_id()));
CREATE POLICY access_memberships_insert ON petita_private.ubs_memberships FOR INSERT TO petita_access_executor
  WITH CHECK ((SELECT petita_private.is_admin()) AND profile_id<>(SELECT petita_private.actor_id()) AND approved_by=(SELECT petita_private.actor_id()));
CREATE POLICY access_memberships_update ON petita_private.ubs_memberships FOR UPDATE TO petita_access_executor
  USING ((SELECT petita_private.is_admin()) AND profile_id<>(SELECT petita_private.actor_id()))
  WITH CHECK ((SELECT petita_private.is_admin()) AND profile_id<>(SELECT petita_private.actor_id()));
CREATE POLICY access_events_insert ON petita_private.team_access_events FOR INSERT TO petita_access_executor
  WITH CHECK ((SELECT petita_private.is_admin()) AND actor_id=(SELECT petita_private.actor_id()) AND target_profile_id<>actor_id);

CREATE FUNCTION petita.request_ubs_team_access(p_ubs_code text,p_idempotency_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid; r petita_private.team_access_requests;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF actor IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||actor::text,0));
  IF NOT EXISTS(SELECT FROM petita.profiles WHERE id=actor AND active AND role IN ('patient','ubs_team')) THEN
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
END $$;

CREATE FUNCTION petita.decide_team_access_request(p_request_id uuid,p_approve boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
  IF NOT petita_private.is_admin() OR NOT EXISTS(SELECT FROM petita.profiles WHERE id=r.requester_id AND active AND role IN ('patient','ubs_team')) THEN
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
END $$;

CREATE FUNCTION petita.revoke_ubs_team_access(p_profile_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid; m petita_private.ubs_memberships;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF NOT petita_private.is_admin() OR p_profile_id IS NULL OR p_profile_id=actor THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 1000 THEN
    RAISE EXCEPTION 'invalid_reason' USING ERRCODE='22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||p_profile_id::text,0));
  IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  UPDATE petita_private.ubs_memberships SET active=false WHERE profile_id=p_profile_id AND active RETURNING * INTO m;
  IF NOT FOUND THEN RAISE EXCEPTION 'membership_unavailable' USING ERRCODE='P0001'; END IF;
  INSERT INTO petita_private.team_access_events(target_profile_id,ubs_code,actor_id,event,reason)
    VALUES(p_profile_id,m.ubs_code,actor,'revoked',btrim(p_reason));
  RETURN jsonb_build_object('profile_id',p_profile_id,'active',false);
END $$;

CREATE FUNCTION petita.list_team_access_requests(p_limit integer DEFAULT 50)
RETURNS TABLE(id uuid,requester_id uuid,requested_ubs_code text,status text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  PERFORM petita_private.require_read_committed();
  IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_page' USING ERRCODE='22023'; END IF;
  RETURN QUERY SELECT r.id,r.requester_id,r.requested_ubs_code,r.status,r.created_at
    FROM petita_private.team_access_requests r WHERE r.status='pending' ORDER BY r.created_at,r.id LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION petita.request_ubs_team_access(text,uuid),petita.decide_team_access_request(uuid,boolean),
  petita.revoke_ubs_team_access(uuid,text),petita.list_team_access_requests(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.request_ubs_team_access(text,uuid),petita.decide_team_access_request(uuid,boolean),
  petita.revoke_ubs_team_access(uuid,text),petita.list_team_access_requests(integer) TO petita_runtime;
GRANT CREATE ON SCHEMA petita TO petita_access_executor;
RESET ROLE;
ALTER FUNCTION petita.request_ubs_team_access(text,uuid) OWNER TO petita_access_executor;
ALTER FUNCTION petita.decide_team_access_request(uuid,boolean) OWNER TO petita_access_executor;
ALTER FUNCTION petita.revoke_ubs_team_access(uuid,text) OWNER TO petita_access_executor;
ALTER FUNCTION petita.list_team_access_requests(integer) OWNER TO petita_access_executor;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_access_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(3);
COMMIT;
