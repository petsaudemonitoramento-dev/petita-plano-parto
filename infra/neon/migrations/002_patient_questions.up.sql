BEGIN;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target', true) IS DISTINCT FROM 'isolated-homologation'
     OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1] THEN
    RAISE EXCEPTION 'isolated target with migration 001 required';
  END IF;
  IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='petita_questions_executor') THEN
    CREATE ROLE petita_questions_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
  IF EXISTS(SELECT FROM pg_roles WHERE rolname='petita_questions_executor'
    AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolbypassrls))
    OR EXISTS(SELECT FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname='petita_questions_executor') THEN
    RAISE EXCEPTION 'unsafe questions executor';
  END IF;
END $guard$;
GRANT petita_questions_executor TO CURRENT_USER;
SET LOCAL ROLE petita_schema_owner;

CREATE TABLE petita.patient_questions (
  id uuid PRIMARY KEY,
  public_code text NOT NULL UNIQUE DEFAULT ('DUV-' || replace(gen_random_uuid()::text,'-','')),
  ubs_code text NOT NULL REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  category text NOT NULL CHECK (length(btrim(category)) BETWEEN 1 AND 120),
  question_text text NOT NULL CHECK (length(btrim(question_text)) BETWEEN 3 AND 1500),
  self_risk_level text NOT NULL CHECK (self_risk_level IN ('low','medium','high')),
  warning_signs text[] NOT NULL CHECK (cardinality(warning_signs) <= 32),
  urgency_acknowledged boolean NOT NULL,
  expected_response_notice_accepted boolean NOT NULL CHECK (expected_response_notice_accepted),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','answered')),
  created_at timestamptz NOT NULL DEFAULT now(),
  answered_at timestamptz,
  CHECK ((status='answered') = (answered_at IS NOT NULL)),
  CHECK ((self_risk_level<>'high' AND cardinality(warning_signs)=0) OR urgency_acknowledged)
);
CREATE INDEX questions_ubs_status_created_idx ON petita.patient_questions(ubs_code,status,created_at,id);
CREATE TABLE petita_private.question_patient_links (
  question_id uuid PRIMARY KEY REFERENCES petita.patient_questions(id) ON DELETE RESTRICT,
  patient_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  idempotency_key uuid NOT NULL,
  request_hash bytea NOT NULL,
  UNIQUE(patient_id,idempotency_key)
);
CREATE INDEX question_links_patient_idx ON petita_private.question_patient_links(patient_id,question_id);
CREATE TABLE petita.ubs_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL UNIQUE REFERENCES petita.patient_questions(id) ON DELETE RESTRICT,
  ubs_code text NOT NULL REFERENCES petita.ubs(code) ON DELETE RESTRICT,
  answered_by uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  answer_text text NOT NULL CHECK (length(btrim(answer_text)) BETWEEN 3 AND 6000),
  idempotency_key uuid NOT NULL,
  request_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(answered_by,idempotency_key)
);
CREATE TABLE petita_private.question_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  question_id uuid NOT NULL REFERENCES petita.patient_questions(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES petita.profiles(id) ON DELETE RESTRICT,
  event text NOT NULL CHECK (event IN ('submitted','answered')),
  occurred_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE petita.patient_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.patient_questions FORCE ROW LEVEL SECURITY;
ALTER TABLE petita.ubs_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.ubs_answers FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.question_patient_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.question_patient_links FORCE ROW LEVEL SECURITY;
ALTER TABLE petita_private.question_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita_private.question_events FORCE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA petita,petita_private TO petita_questions_executor;
GRANT SELECT ON petita.ubs TO petita_questions_executor;
CREATE POLICY questions_executor_ubs ON petita.ubs FOR SELECT TO petita_questions_executor USING (active);
GRANT SELECT,INSERT ON petita.patient_questions,petita.ubs_answers,petita_private.question_patient_links TO petita_questions_executor;
GRANT UPDATE(status,answered_at) ON petita.patient_questions TO petita_questions_executor;
GRANT INSERT ON petita_private.question_events TO petita_questions_executor;
GRANT USAGE ON SEQUENCE petita_private.question_events_id_seq TO petita_questions_executor;
SET LOCAL ROLE petita_authorizer;
GRANT EXECUTE ON FUNCTION petita_private.actor_id(),petita_private.is_patient(),petita_private.actor_ubs(),petita_private.team_ubs() TO petita_questions_executor;
SET LOCAL ROLE petita_schema_owner;
CREATE FUNCTION petita_private.require_read_committed() RETURNS void
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF current_setting('transaction_isolation')<>'read committed' THEN
    RAISE EXCEPTION 'read_committed_required' USING ERRCODE='25000';
  END IF;
END $$;
REVOKE EXECUTE ON FUNCTION petita_private.require_read_committed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita_private.require_read_committed() TO petita_questions_executor;
CREATE POLICY own_links ON petita_private.question_patient_links FOR SELECT TO petita_questions_executor
  USING (patient_id=(SELECT petita_private.actor_id()) AND (SELECT petita_private.is_patient()));
CREATE POLICY insert_own_link ON petita_private.question_patient_links FOR INSERT TO petita_questions_executor
  WITH CHECK (patient_id=(SELECT petita_private.actor_id()) AND (SELECT petita_private.is_patient()));
CREATE POLICY questions_read ON petita.patient_questions FOR SELECT TO petita_questions_executor
  USING (ubs_code=(SELECT petita_private.team_ubs()) OR EXISTS (
    SELECT FROM petita_private.question_patient_links l WHERE l.question_id=patient_questions.id));
CREATE POLICY questions_insert ON petita.patient_questions FOR INSERT TO petita_questions_executor
  WITH CHECK ((SELECT petita_private.is_patient()) AND ubs_code=(SELECT petita_private.actor_ubs())
    AND status='pending' AND EXISTS(SELECT FROM petita.ubs u WHERE u.code=ubs_code AND u.active));
CREATE POLICY questions_answer ON petita.patient_questions FOR UPDATE TO petita_questions_executor
  USING (ubs_code=(SELECT petita_private.team_ubs()) AND status='pending')
  WITH CHECK (ubs_code=(SELECT petita_private.team_ubs()) AND status='answered');
CREATE POLICY answers_read ON petita.ubs_answers FOR SELECT TO petita_questions_executor
  USING (ubs_code=(SELECT petita_private.team_ubs()) OR EXISTS (
    SELECT FROM petita_private.question_patient_links l WHERE l.question_id=ubs_answers.question_id));
CREATE POLICY answers_insert ON petita.ubs_answers FOR INSERT TO petita_questions_executor
  WITH CHECK (answered_by=(SELECT petita_private.actor_id()) AND ubs_code=(SELECT petita_private.team_ubs())
    AND EXISTS(SELECT FROM petita.patient_questions q WHERE q.id=question_id AND q.ubs_code=ubs_answers.ubs_code AND q.status='pending'));
CREATE POLICY question_event_insert ON petita_private.question_events FOR INSERT TO petita_questions_executor
  WITH CHECK (actor_id=(SELECT petita_private.actor_id()));

CREATE FUNCTION petita.submit_patient_question(
  p_idempotency_key uuid,p_ubs_code text,p_category text,p_question_text text,
  p_self_risk_level text,p_warning_signs text[],p_urgency_acknowledged boolean,
  p_expected_response_notice_accepted boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid; existing petita_private.question_patient_links; q petita.patient_questions;
        request_digest bytea; question_id uuid;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF actor IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||actor::text,0));
  IF NOT petita_private.is_patient() OR p_ubs_code IS DISTINCT FROM petita_private.actor_ubs()
     OR NOT EXISTS(SELECT FROM petita.ubs WHERE code=p_ubs_code AND active) THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501';
  END IF;
  IF p_idempotency_key IS NULL OR p_question_text IS NULL OR length(btrim(p_question_text)) NOT BETWEEN 3 AND 1500
     OR p_category IS NULL OR length(btrim(p_category)) NOT BETWEEN 1 AND 120
     OR p_self_risk_level IS NULL OR p_self_risk_level NOT IN ('low','medium','high')
     OR p_warning_signs IS NULL OR array_ndims(p_warning_signs)>1 OR cardinality(p_warning_signs)>32
     OR EXISTS(SELECT FROM unnest(p_warning_signs) w WHERE w IS NULL OR length(btrim(w)) NOT BETWEEN 1 AND 240)
     OR p_urgency_acknowledged IS NULL OR p_expected_response_notice_accepted IS DISTINCT FROM true
     OR ((p_self_risk_level='high' OR cardinality(p_warning_signs)>0) AND NOT p_urgency_acknowledged) THEN
    RAISE EXCEPTION 'invalid_question_or_acknowledgements' USING ERRCODE='22023';
  END IF;
  request_digest:=sha256(convert_to(jsonb_build_array(p_ubs_code,btrim(p_category),btrim(p_question_text),
    p_self_risk_level,p_warning_signs,p_urgency_acknowledged,p_expected_response_notice_accepted)::text,'UTF8'));
  SELECT * INTO existing FROM petita_private.question_patient_links WHERE patient_id=actor AND idempotency_key=p_idempotency_key;
  IF FOUND THEN
    IF existing.request_hash<>request_digest THEN RAISE EXCEPTION 'idempotency_conflict' USING ERRCODE='P0001'; END IF;
    SELECT * INTO STRICT q FROM petita.patient_questions WHERE id=existing.question_id;
  ELSE
    question_id:=gen_random_uuid();
    INSERT INTO petita.patient_questions(id,ubs_code,category,question_text,self_risk_level,warning_signs,
      urgency_acknowledged,expected_response_notice_accepted)
      VALUES(question_id,p_ubs_code,btrim(p_category),btrim(p_question_text),p_self_risk_level,p_warning_signs,
        p_urgency_acknowledged,p_expected_response_notice_accepted);
    INSERT INTO petita_private.question_patient_links VALUES(question_id,actor,p_idempotency_key,request_digest);
    INSERT INTO petita_private.question_events(question_id,actor_id,event) VALUES(question_id,actor,'submitted');
    SELECT * INTO STRICT q FROM petita.patient_questions WHERE id=question_id;
  END IF;
  RETURN jsonb_build_object('id',q.id,'public_code',q.public_code,'status',q.status);
END $$;

CREATE FUNCTION petita.list_my_patient_questions(p_limit integer DEFAULT 50,p_before_created timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid,public_code text,ubs_code text,category text,question_text text,self_risk_level text,
  warning_signs text[],status text,created_at timestamptz,answer_text text,answered_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  PERFORM petita_private.require_read_committed();
  IF NOT petita_private.is_patient() THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR ((p_before_created IS NULL)<>(p_before_id IS NULL)) THEN
    RAISE EXCEPTION 'invalid_page' USING ERRCODE='22023';
  END IF;
  RETURN QUERY SELECT q.id,q.public_code,q.ubs_code,q.category,q.question_text,q.self_risk_level,
    q.warning_signs,q.status,q.created_at,a.answer_text,a.created_at
    FROM petita.patient_questions q JOIN petita_private.question_patient_links l ON l.question_id=q.id
    LEFT JOIN petita.ubs_answers a ON a.question_id=q.id
    WHERE l.patient_id=petita_private.actor_id()
      AND (p_before_created IS NULL OR (q.created_at,q.id)<(p_before_created,p_before_id))
    ORDER BY q.created_at DESC,q.id DESC LIMIT p_limit;
END $$;

CREATE FUNCTION petita.list_team_patient_questions(p_limit integer DEFAULT 50,p_before_created timestamptz DEFAULT NULL,p_before_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid,public_code text,ubs_code text,category text,question_text text,self_risk_level text,
  warning_signs text[],created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  PERFORM petita_private.require_read_committed();
  IF petita_private.team_ubs() IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR ((p_before_created IS NULL)<>(p_before_id IS NULL)) THEN
    RAISE EXCEPTION 'invalid_page' USING ERRCODE='22023';
  END IF;
  RETURN QUERY SELECT q.id,q.public_code,q.ubs_code,q.category,q.question_text,q.self_risk_level,q.warning_signs,q.created_at
    FROM petita.patient_questions q WHERE q.ubs_code=petita_private.team_ubs() AND q.status='pending'
      AND (p_before_created IS NULL OR (q.created_at,q.id)<(p_before_created,p_before_id))
    ORDER BY q.created_at DESC,q.id DESC LIMIT p_limit;
END $$;

CREATE FUNCTION petita.respond_to_patient_question(p_question_id uuid,p_answer_text text,p_idempotency_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid; unit text; q petita.patient_questions; a petita.ubs_answers; request_digest bytea;
BEGIN
  PERFORM petita_private.require_read_committed();
  actor:=petita_private.actor_id();
  IF actor IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.actor:'||actor::text,0));
  unit:=petita_private.team_ubs();
  IF unit IS NULL THEN RAISE EXCEPTION 'not_authorized' USING ERRCODE='42501'; END IF;
  IF p_question_id IS NULL OR p_idempotency_key IS NULL OR p_answer_text IS NULL
     OR length(btrim(p_answer_text)) NOT BETWEEN 3 AND 6000 THEN
    RAISE EXCEPTION 'invalid_answer' USING ERRCODE='22023';
  END IF;
  -- Advisory lock serializes even a second writer whose RLS sees an answered row.
  PERFORM pg_advisory_xact_lock(hashtextextended('petita.question:'||p_question_id::text,0));
  SELECT * INTO q FROM petita.patient_questions WHERE id=p_question_id AND ubs_code=unit;
  IF NOT FOUND THEN RAISE EXCEPTION 'question_unavailable' USING ERRCODE='42501'; END IF;
  request_digest:=sha256(convert_to(jsonb_build_array(p_question_id,btrim(p_answer_text))::text,'UTF8'));
  SELECT * INTO a FROM petita.ubs_answers WHERE question_id=q.id;
  IF FOUND THEN
    IF a.answered_by<>actor OR a.idempotency_key<>p_idempotency_key OR a.request_hash<>request_digest THEN
      RAISE EXCEPTION 'answer_conflict' USING ERRCODE='P0001';
    END IF;
    RETURN jsonb_build_object('id',a.id,'question_id',a.question_id,'status','answered');
  END IF;
  INSERT INTO petita.ubs_answers(question_id,ubs_code,answered_by,answer_text,idempotency_key,request_hash)
    VALUES(q.id,unit,actor,btrim(p_answer_text),p_idempotency_key,request_digest) RETURNING * INTO a;
  UPDATE petita.patient_questions SET status='answered',answered_at=a.created_at WHERE id=q.id AND status='pending';
  IF NOT FOUND THEN RAISE EXCEPTION 'answer_conflict' USING ERRCODE='P0001'; END IF;
  INSERT INTO petita_private.question_events(question_id,actor_id,event) VALUES(q.id,actor,'answered');
  RETURN jsonb_build_object('id',a.id,'question_id',q.id,'status','answered');
END $$;

REVOKE EXECUTE ON FUNCTION petita.submit_patient_question(uuid,text,text,text,text,text[],boolean,boolean),
  petita.list_my_patient_questions(integer,timestamptz,uuid),petita.list_team_patient_questions(integer,timestamptz,uuid),
  petita.respond_to_patient_question(uuid,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION petita.submit_patient_question(uuid,text,text,text,text,text[],boolean,boolean),
  petita.list_my_patient_questions(integer,timestamptz,uuid),petita.list_team_patient_questions(integer,timestamptz,uuid),
  petita.respond_to_patient_question(uuid,text,uuid) TO petita_runtime;
GRANT CREATE ON SCHEMA petita TO petita_questions_executor;
RESET ROLE;
ALTER FUNCTION petita.submit_patient_question(uuid,text,text,text,text,text[],boolean,boolean) OWNER TO petita_questions_executor;
ALTER FUNCTION petita.list_my_patient_questions(integer,timestamptz,uuid) OWNER TO petita_questions_executor;
ALTER FUNCTION petita.list_team_patient_questions(integer,timestamptz,uuid) OWNER TO petita_questions_executor;
ALTER FUNCTION petita.respond_to_patient_question(uuid,text,uuid) OWNER TO petita_questions_executor;
SET LOCAL ROLE petita_schema_owner;
REVOKE CREATE ON SCHEMA petita FROM petita_questions_executor;
INSERT INTO petita_private.schema_migrations(version) VALUES(2);
COMMIT;
