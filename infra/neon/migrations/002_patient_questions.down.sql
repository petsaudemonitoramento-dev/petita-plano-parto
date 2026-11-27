BEGIN;
SET LOCAL row_security=off;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
    OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2] THEN
    RAISE EXCEPTION 'isolated target with exact migration history required';
  END IF;
  IF EXISTS(SELECT FROM petita.patient_questions) OR EXISTS(SELECT FROM petita.ubs_answers)
    OR EXISTS(SELECT FROM petita_private.question_patient_links) OR EXISTS(SELECT FROM petita_private.question_events) THEN
    RAISE EXCEPTION 'rollback refused: question data exists';
  END IF;
END $guard$;
DROP FUNCTION petita.submit_patient_question(uuid,text,text,text,text,text[],boolean,boolean);
DROP FUNCTION petita.list_my_patient_questions(integer,timestamptz,uuid);
DROP FUNCTION petita.list_team_patient_questions(integer,timestamptz,uuid);
DROP FUNCTION petita.respond_to_patient_question(uuid,text,uuid);
DROP FUNCTION petita_private.require_read_committed();
DROP TABLE petita_private.question_events;
DROP TABLE petita.ubs_answers;
DROP POLICY questions_read ON petita.patient_questions;
DROP TABLE petita_private.question_patient_links;
DROP TABLE petita.patient_questions;
DROP POLICY questions_executor_ubs ON petita.ubs;
REVOKE ALL ON petita.ubs FROM petita_questions_executor;
REVOKE EXECUTE ON FUNCTION petita_private.actor_id(),petita_private.is_patient(),petita_private.actor_ubs(),petita_private.team_ubs() FROM petita_questions_executor;
REVOKE USAGE ON SCHEMA petita,petita_private FROM petita_questions_executor;
DELETE FROM petita_private.schema_migrations WHERE version=2;
COMMIT;
