BEGIN;
SET LOCAL row_security=off;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target',true) IS DISTINCT FROM 'isolated-homologation'
    OR (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1,2,3] THEN
    RAISE EXCEPTION 'isolated target with exact migration history required';
  END IF;
  IF EXISTS(SELECT FROM petita_private.team_access_requests) OR EXISTS(SELECT FROM petita_private.team_access_events) THEN
    RAISE EXCEPTION 'rollback refused: access history exists';
  END IF;
END $guard$;
DROP FUNCTION petita.request_ubs_team_access(text,uuid);
DROP FUNCTION petita.decide_team_access_request(uuid,boolean);
DROP FUNCTION petita.revoke_ubs_team_access(uuid,text);
DROP FUNCTION petita.list_team_access_requests(integer);
DROP TABLE petita_private.team_access_events;
DROP TABLE petita_private.team_access_requests;
DROP POLICY access_ubs ON petita.ubs;
DROP POLICY access_profiles_read ON petita.profiles;
DROP POLICY access_profiles_update ON petita.profiles;
DROP POLICY access_memberships_read ON petita_private.ubs_memberships;
DROP POLICY access_memberships_insert ON petita_private.ubs_memberships;
DROP POLICY access_memberships_update ON petita_private.ubs_memberships;
REVOKE ALL ON petita.ubs,petita.profiles,petita_private.ubs_memberships FROM petita_access_executor;
REVOKE UPDATE(role) ON petita.profiles FROM petita_access_executor;
REVOKE UPDATE(ubs_code,active,approved_by,approved_at) ON petita_private.ubs_memberships FROM petita_access_executor;
REVOKE EXECUTE ON FUNCTION petita_private.actor_id(),petita_private.is_admin(),petita_private.team_ubs() FROM petita_access_executor;
REVOKE USAGE ON SCHEMA petita,petita_private FROM petita_access_executor;
REVOKE EXECUTE ON FUNCTION petita_private.require_read_committed() FROM petita_access_executor;
DELETE FROM petita_private.schema_migrations WHERE version=3;
COMMIT;
