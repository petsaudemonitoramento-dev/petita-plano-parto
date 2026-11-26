-- Deliberately refuses rollback after importing/creating any domain data.
BEGIN;
-- Fail instead of mistaking rows hidden by RLS for an empty database.
SET LOCAL row_security = off;
DO $guard$
BEGIN
  IF current_setting('petita.migration_target', true) IS DISTINCT FROM 'isolated-homologation' THEN
    RAISE EXCEPTION 'isolated homologation target must be explicitly selected';
  END IF;
  IF (SELECT array_agg(version ORDER BY version) FROM petita_private.schema_migrations) IS DISTINCT FROM ARRAY[1] THEN
    RAISE EXCEPTION 'unexpected migration history';
  END IF;
  IF EXISTS (SELECT FROM petita.ubs) OR EXISTS (SELECT FROM petita.profiles)
    OR EXISTS (SELECT FROM petita.birth_plans) OR EXISTS (SELECT FROM petita_private.identities)
    OR EXISTS (SELECT FROM petita_private.ubs_memberships) THEN
    RAISE EXCEPTION 'rollback refused: domain data exists; preserve and migrate forward';
  END IF;
END
$guard$;
-- Explicit objects; unknown dependent objects cause rollback failure, not CASCADE.
DROP TABLE petita.birth_plans;
DROP TABLE petita_private.ubs_memberships;
DROP TABLE petita_private.identities;
DROP TABLE petita.profiles;
DROP TABLE petita.ubs;
DROP FUNCTION petita_private.team_ubs();
DROP FUNCTION petita_private.is_admin();
DROP FUNCTION petita_private.actor_ubs();
DROP FUNCTION petita_private.is_patient();
DROP FUNCTION petita_private.actor_id();
DROP FUNCTION petita_private.touch_updated_at();
DROP TABLE petita_private.schema_migrations;
DROP SCHEMA petita;
DROP SCHEMA petita_private;
-- NOLOGIN roles are retained: they may be used by another database in the cluster.
COMMIT;
