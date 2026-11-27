-- Additive homologation migration. Never apply to an unspecified/default branch.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5]
 THEN RAISE EXCEPTION 'isolated homologation with exact migrations 001-005 required'; END IF;
END $$;
SET LOCAL ROLE petita_schema_owner;
CREATE TABLE petita_private.patient_ubs_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 requester_id uuid NOT NULL REFERENCES petita.profiles(id),
 ubs_code text NOT NULL REFERENCES petita.ubs(code),
 operation_id uuid NOT NULL,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 created_at timestamptz NOT NULL DEFAULT now(),
 decided_by uuid REFERENCES petita.profiles(id), decided_at timestamptz,
 UNIQUE(requester_id,operation_id),
 CHECK((status='pending')=(decided_at IS NULL)),
 CHECK((status='pending')=(decided_by IS NULL))
);
CREATE UNIQUE INDEX one_patient_ubs_pending ON petita_private.patient_ubs_requests(requester_id) WHERE status='pending';
CREATE TABLE petita_private.patient_ubs_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 actor_id uuid NOT NULL REFERENCES petita.profiles(id),
 patient_id uuid NOT NULL REFERENCES petita.profiles(id),
 event text NOT NULL CHECK(event IN ('approved','rejected','revoked')),
 reason text CHECK(length(btrim(reason)) BETWEEN 3 AND 1000),
 occurred_at timestamptz NOT NULL DEFAULT now(), CHECK(actor_id<>patient_id)
);
ALTER TABLE petita_private.patient_ubs_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.patient_ubs_requests FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.patient_ubs_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.patient_ubs_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON petita_private.patient_ubs_requests,petita_private.patient_ubs_events FROM PUBLIC,petita_runtime;
GRANT SELECT,INSERT ON petita_private.patient_ubs_requests TO petita_access_executor;
GRANT UPDATE(status,decided_by,decided_at) ON petita_private.patient_ubs_requests TO petita_access_executor;
GRANT INSERT ON petita_private.patient_ubs_events TO petita_access_executor;
GRANT USAGE ON SEQUENCE petita_private.patient_ubs_events_id_seq TO petita_access_executor;
GRANT UPDATE(ubs_code) ON petita.profiles TO petita_access_executor;
CREATE POLICY patient_link_read ON petita_private.patient_ubs_requests FOR SELECT TO petita_access_executor
 USING((SELECT petita_private.is_admin()) OR requester_id=(SELECT petita_private.actor_id()));
CREATE POLICY patient_link_request ON petita_private.patient_ubs_requests FOR INSERT TO petita_access_executor
 WITH CHECK((SELECT petita_private.is_patient()) AND requester_id=(SELECT petita_private.actor_id()) AND status='pending');
CREATE POLICY patient_link_decide ON petita_private.patient_ubs_requests FOR UPDATE TO petita_access_executor
 USING((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id()) AND status='pending')
 WITH CHECK((SELECT petita_private.is_admin()) AND requester_id<>(SELECT petita_private.actor_id()) AND decided_by=(SELECT petita_private.actor_id()) AND status IN ('approved','rejected'));
CREATE POLICY patient_link_profile ON petita.profiles FOR UPDATE TO petita_access_executor
 USING((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND active AND role='patient')
 WITH CHECK((SELECT petita_private.is_admin()) AND id<>(SELECT petita_private.actor_id()) AND role='patient');
CREATE POLICY patient_link_events ON petita_private.patient_ubs_events FOR INSERT TO petita_access_executor
 WITH CHECK((SELECT petita_private.is_admin()) AND actor_id=(SELECT petita_private.actor_id()) AND patient_id<>actor_id);
GRANT CREATE ON SCHEMA petita TO petita_access_executor;
SET LOCAL ROLE petita_authorizer;
GRANT EXECUTE ON FUNCTION petita_private.is_patient() TO petita_access_executor;
SET LOCAL ROLE petita_access_executor;
CREATE FUNCTION petita.request_patient_ubs(p_ubs_code text,p_operation_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid:=petita_private.actor_id(); existing petita_private.patient_ubs_requests; result uuid;
BEGIN
 PERFORM petita_private.require_read_committed();
 IF NOT petita_private.is_patient() OR p_operation_id IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||actor::text,0));
 SELECT * INTO existing FROM petita_private.patient_ubs_requests WHERE requester_id=actor AND operation_id=p_operation_id;
 IF FOUND THEN
  IF existing.ubs_code IS DISTINCT FROM p_ubs_code THEN RAISE EXCEPTION 'conflict' USING ERRCODE='P0001'; END IF;
  RETURN jsonb_build_object('id',existing.id,'status',existing.status,'ubs_code',existing.ubs_code);
 END IF;
 IF NOT EXISTS(SELECT FROM petita.ubs WHERE code=p_ubs_code AND active) THEN RAISE EXCEPTION 'invalid_ubs' USING ERRCODE='22023'; END IF;
 INSERT INTO petita_private.patient_ubs_requests(requester_id,ubs_code,operation_id) VALUES(actor,p_ubs_code,p_operation_id) RETURNING id INTO result;
 RETURN jsonb_build_object('id',result,'status','pending','ubs_code',p_ubs_code);
END $$;
CREATE FUNCTION petita.list_my_ubs_requests() RETURNS TABLE(id uuid,ubs_code text,status text,created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT id,ubs_code,status,created_at FROM petita_private.patient_ubs_requests
 WHERE requester_id=petita_private.actor_id() ORDER BY created_at DESC LIMIT 50
$$;
CREATE FUNCTION petita.list_patient_ubs_requests() RETURNS TABLE(id uuid,patient_id uuid,display_name text,ubs_code text,status text,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN
 IF NOT petita_private.is_admin() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT r.id,r.requester_id,p.display_name,r.ubs_code,r.status,r.created_at
 FROM petita_private.patient_ubs_requests r JOIN petita.profiles p ON p.id=r.requester_id
 WHERE r.status='pending' ORDER BY r.created_at LIMIT 100;
END $$;
CREATE FUNCTION petita.decide_patient_ubs(p_request_id uuid,p_approve boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE r petita_private.patient_ubs_requests; actor uuid:=petita_private.actor_id();
BEGIN
 PERFORM petita_private.require_read_committed();
 IF NOT petita_private.is_admin() OR p_approve IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM petita_private.patient_ubs_requests WHERE id=p_request_id;
 IF NOT FOUND OR r.requester_id=actor THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||r.requester_id::text,0));
 SELECT * INTO r FROM petita_private.patient_ubs_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'already_decided' USING ERRCODE='P0001'; END IF;
 IF r.status<>'pending' THEN RAISE EXCEPTION 'already_decided' USING ERRCODE='P0001'; END IF;
 IF NOT EXISTS(SELECT FROM petita.profiles WHERE id=r.requester_id AND active AND role='patient') THEN RAISE EXCEPTION 'inactive_patient' USING ERRCODE='42501'; END IF;
 IF p_approve THEN
  IF NOT EXISTS(SELECT FROM petita.ubs WHERE code=r.ubs_code AND active) THEN RAISE EXCEPTION 'inactive_ubs' USING ERRCODE='42501'; END IF;
  UPDATE petita.profiles SET ubs_code=r.ubs_code WHERE id=r.requester_id;
 END IF;
 UPDATE petita_private.patient_ubs_requests SET status=CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,decided_by=actor,decided_at=now() WHERE id=r.id;
 INSERT INTO petita_private.patient_ubs_events(actor_id,patient_id,event) VALUES(actor,r.requester_id,CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END);
 RETURN jsonb_build_object('id',r.id,'status',CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END);
END $$;
CREATE FUNCTION petita.revoke_patient_ubs(p_patient_id uuid,p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN
 PERFORM petita_private.require_read_committed();
 IF NOT petita_private.is_admin() OR p_patient_id=petita_private.actor_id() OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 1000 THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||p_patient_id::text,0));
 UPDATE petita.profiles SET ubs_code=NULL WHERE id=p_patient_id AND active AND role='patient';
 IF NOT FOUND THEN RAISE EXCEPTION 'invalid_patient' USING ERRCODE='42501'; END IF;
 INSERT INTO petita_private.patient_ubs_events(actor_id,patient_id,event,reason) VALUES(petita_private.actor_id(),p_patient_id,'revoked',btrim(p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION petita.request_patient_ubs(text,uuid),petita.list_my_ubs_requests(),petita.list_patient_ubs_requests(),petita.decide_patient_ubs(uuid,boolean),petita.revoke_patient_ubs(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.request_patient_ubs(text,uuid),petita.list_my_ubs_requests(),petita.list_patient_ubs_requests(),petita.decide_patient_ubs(uuid,boolean),petita.revoke_patient_ubs(uuid,text) TO petita_runtime;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_access_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(6);
COMMIT;
