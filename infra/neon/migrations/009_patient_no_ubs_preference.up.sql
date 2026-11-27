-- Persist a patient's explicit decision that their UBS is not registered.
BEGIN;
DO $$ BEGIN
 IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
 OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3,4,5,6,7,8]
 THEN RAISE EXCEPTION 'isolated homologation with exact migrations 001-008 required'; END IF;
END $$;
SET LOCAL ROLE petita_schema_owner;
CREATE TABLE petita.patient_no_ubs_preference (
 patient_id uuid PRIMARY KEY REFERENCES petita.profiles(id),
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE petita.patient_no_ubs_preference ENABLE ROW LEVEL SECURITY;
ALTER TABLE petita.patient_no_ubs_preference FORCE ROW LEVEL SECURITY;
REVOKE ALL ON petita.patient_no_ubs_preference FROM PUBLIC,petita_runtime;
GRANT SELECT ON petita.patient_no_ubs_preference TO petita_runtime;
GRANT INSERT(patient_id) ON petita.patient_no_ubs_preference TO petita_runtime;
CREATE POLICY patient_preference_read ON petita.patient_no_ubs_preference FOR SELECT TO petita_runtime USING ((SELECT petita_private.is_patient()) AND patient_id=(SELECT petita_private.actor_id()));
CREATE POLICY patient_preference_insert ON petita.patient_no_ubs_preference FOR INSERT TO petita_runtime WITH CHECK ((SELECT petita_private.is_patient()) AND patient_id=(SELECT petita_private.actor_id()));
INSERT INTO petita_private.schema_migrations(version) VALUES(9);
COMMIT;
