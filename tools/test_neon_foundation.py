#!/usr/bin/env python3
"""Real PostgreSQL authorization tests; disposable local Docker, no URLs/secrets.

No port, network, production configuration, imported rows or host volume is used.
The SQL behavior tests connect as a non-owner LOGIN with only petita_runtime.
"""
import os
from pathlib import Path
import subprocess
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "postgres:17.6-bookworm@sha256:f3bd19c606e442c3d7bdfa8002e03fe260a1023351e0ea4598032022b68dd6e3"
CONTAINER = "petita-rls-test-" + uuid.uuid4().hex[:12]
DOCKER = ["docker", "--host=unix:///var/run/docker.sock"]
ENV = {k: v for k, v in os.environ.items() if k not in {
    "DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"
}}
MIGRATIONS = ROOT / "infra/neon/migrations"
ISSUER = "https://identity.example.invalid"
A = "00000000-0000-4000-8000-000000000001"
B = "00000000-0000-4000-8000-000000000002"
TEAM_A = "00000000-0000-4000-8000-000000000003"
TEAM_B = "00000000-0000-4000-8000-000000000004"
ADMIN = "00000000-0000-4000-8000-000000000005"
INACTIVE = "00000000-0000-4000-8000-000000000006"
UNAPPROVED = "00000000-0000-4000-8000-000000000007"
PLAN_A = "00000000-0000-4000-8000-000000000101"
PLAN_B = "00000000-0000-4000-8000-000000000102"


def docker(*args, input=None, check=True):
    return subprocess.run(DOCKER + list(args), input=input, text=True, capture_output=True,
                          env=ENV, timeout=180, check=check)


def sql(statement, user="petita_test_client", database="petita_test", check=True):
    return docker("exec", "-i", CONTAINER, "psql", "-XqAt", "-v", "ON_ERROR_STOP=1",
                  "-v", "VERBOSITY=sqlstate", "-U", user, "-d", database,
                  input=statement, check=check)


def migrate(direction="up", database="petita_test", check=True, guarded=True, user="postgres"):
    guard = "SET petita.migration_target='isolated-homologation';\n" if guarded else ""
    return sql(guard + (MIGRATIONS / f"001_identity_rls.{direction}.sql").read_text(),
               user, database, check=check)


class AuthorizationTests(unittest.TestCase):
    def request(self, statement, subject="patient-a", issuer=ISSUER, check=True):
        # Only synthetic constants enter SQL here; this is not a backend adapter.
        prefix = f"BEGIN; SET LOCAL petita.issuer='{issuer}'; SET LOCAL petita.subject='{subject}';"
        return sql(prefix + statement + "; ROLLBACK;", check=check)

    def value(self, statement, subject="patient-a", issuer=ISSUER):
        return self.request(statement, subject, issuer).stdout.strip()

    def denied(self, statement, subject="patient-a", state="42501"):
        result = self.request(statement, subject, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(state, result.stderr)

    def test_real_login_is_neither_owner_nor_bypass(self):
        self.assertEqual(self.value("SELECT current_user"), "petita_test_client")
        self.assertEqual(self.value("SELECT rolsuper OR rolbypassrls OR rolcreaterole FROM pg_roles WHERE rolname=current_user"), "f")
        self.assertEqual(self.value("SELECT count(*) FROM pg_class WHERE relnamespace IN ('petita'::regnamespace,'petita_private'::regnamespace) AND relowner=(SELECT oid FROM pg_roles WHERE rolname=current_user)"), "0")

    def test_patient_sees_only_own_profile_and_plan(self):
        self.assertEqual(self.value("SELECT id FROM petita.profiles"), A)
        self.assertEqual(self.value("SELECT id FROM petita.birth_plans"), PLAN_A)
        self.assertEqual(self.value("SELECT id FROM petita.birth_plans", "patient-b"), PLAN_B)
        self.assertEqual(self.value(f"SELECT count(*) FROM petita.birth_plans WHERE id='{PLAN_B}'"), "0")

    def test_anonymous_unknown_inactive_and_wrong_issuer_fail_closed(self):
        for subject, issuer in [("", ISSUER), ("unknown", ISSUER), ("inactive", ISSUER),
                                ("patient-a", "https://other.example.invalid")]:
            with self.subTest(subject=subject, issuer=issuer):
                self.assertEqual(self.value("SELECT count(*) FROM petita.profiles", subject, issuer), "0")
                self.assertEqual(self.value("SELECT count(*) FROM petita.birth_plans", subject, issuer), "0")
        self.assertEqual(sql("SELECT count(*) FROM petita.birth_plans").stdout.strip(), "0")

    def test_team_and_admin_cannot_read_clinical_plans(self):
        for subject in ["team-a", "team-b", "admin", "unapproved"]:
            with self.subTest(subject=subject):
                self.assertEqual(self.value("SELECT count(*) FROM petita.birth_plans", subject), "0")
                self.assertEqual(self.value("SELECT count(*) FROM petita.profiles", subject), "1")

    def test_team_ubs_comes_from_approved_live_membership(self):
        self.assertEqual(self.value("SELECT petita_private.team_ubs()", "team-a"), "TEST-A")
        self.assertEqual(self.value("SELECT petita_private.team_ubs()", "team-b"), "TEST-B")
        self.assertEqual(self.value("SELECT petita_private.team_ubs()", "unapproved"), "")
        self.assertEqual(self.value("SELECT petita_private.team_ubs()", "patient-a"), "")

    def test_admin_is_derived_from_database_not_client_claim(self):
        self.assertEqual(self.value("SET LOCAL petita.role='admin'; SELECT petita_private.is_admin()"), "f")
        self.assertEqual(self.value("SELECT petita_private.is_admin()", "admin"), "t")
        self.assertEqual(self.value("SELECT petita_private.is_admin()", "inactive"), "f")

    def test_live_deactivation_revokes_access(self):
        sql(f"UPDATE petita.profiles SET active=false WHERE id='{A}'", "postgres")
        try:
            self.assertEqual(self.value("SELECT count(*) FROM petita.birth_plans"), "0")
        finally:
            sql(f"UPDATE petita.profiles SET active=true WHERE id='{A}'", "postgres")

    def test_membership_revocation_and_ubs_deactivation(self):
        sql(f"UPDATE petita_private.ubs_memberships SET active=false WHERE profile_id='{TEAM_A}'", "postgres")
        try:
            self.assertEqual(self.value("SELECT petita_private.team_ubs()", "team-a"), "")
        finally:
            sql(f"UPDATE petita_private.ubs_memberships SET active=true WHERE profile_id='{TEAM_A}'", "postgres")
        sql("UPDATE petita.ubs SET active=false WHERE code='TEST-A'", "postgres")
        try:
            self.assertEqual(self.value("SELECT petita_private.team_ubs()", "team-a"), "")
            self.denied(f"INSERT INTO petita.birth_plans(patient_id,ubs_code) VALUES ('{A}','TEST-A')")
            self.denied(f"UPDATE petita.birth_plans SET answers_json='{{}}' WHERE id='{PLAN_A}'")
            self.assertEqual(self.value("SELECT id FROM petita.birth_plans"), PLAN_A)
        finally:
            sql("UPDATE petita.ubs SET active=true WHERE code='TEST-A'", "postgres")

    def test_private_mappings_cannot_be_selected_or_modified(self):
        for subject in ["patient-a", "team-a", "admin"]:
            for table in ["identities", "ubs_memberships", "schema_migrations"]:
                with self.subTest(subject=subject, table=table):
                    self.denied(f"SELECT * FROM petita_private.{table}", subject)
            self.denied("INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES ('fake','fake',gen_random_uuid())", subject)

    def test_profile_privileged_columns_and_creation_are_denied(self):
        for assignment in ["role='admin'", "active=false", "ubs_code='TEST-B'", f"id='{B}'"]:
            self.denied(f"UPDATE petita.profiles SET {assignment} WHERE id='{A}'")
        self.denied("INSERT INTO petita.profiles(display_name) VALUES ('synthetic')")
        self.denied("DELETE FROM petita.profiles")
        self.assertEqual(self.value(f"UPDATE petita.profiles SET display_name='changed' WHERE id='{A}' RETURNING display_name"), "changed")
        self.assertEqual(self.value(f"UPDATE petita.profiles SET display_name='changed' WHERE id='{B}' RETURNING id"), "")

    def test_patient_plan_crud_and_timestamps(self):
        self.assertEqual(self.value(f"INSERT INTO petita.birth_plans(patient_id,ubs_code,companion,answers_json) VALUES ('{A}','TEST-A','synthetic','{{\"synthetic\":[]}}') RETURNING patient_id"), A)
        self.assertEqual(self.value(f"UPDATE petita.birth_plans SET companion='changed' WHERE id='{PLAN_A}' RETURNING companion"), "changed")
        self.assertEqual(self.value(f"DELETE FROM petita.birth_plans WHERE id='{PLAN_A}' RETURNING id"), PLAN_A)
        self.denied(f"UPDATE petita.birth_plans SET created_at=now() WHERE id='{PLAN_A}'")
        self.denied(f"UPDATE petita.birth_plans SET patient_id='{B}' WHERE id='{PLAN_A}'")

    def test_cross_patient_and_ubs_writes_are_rejected(self):
        self.denied(f"INSERT INTO petita.birth_plans(patient_id,ubs_code) VALUES ('{B}','TEST-B')")
        self.denied(f"INSERT INTO petita.birth_plans(patient_id,ubs_code) VALUES ('{A}','TEST-B')")
        self.denied(f"UPDATE petita.birth_plans SET ubs_code='TEST-B' WHERE id='{PLAN_A}'")
        self.assertEqual(self.value(f"UPDATE petita.birth_plans SET answers_json='{{}}' WHERE id='{PLAN_B}' RETURNING id"), "")
        self.assertEqual(self.value(f"DELETE FROM petita.birth_plans WHERE id='{PLAN_B}' RETURNING id"), "")

    def test_non_patients_and_anonymous_cannot_create_plan(self):
        for subject, profile in [("", A), ("inactive", INACTIVE), ("team-a", TEAM_A), ("admin", ADMIN)]:
            with self.subTest(subject=subject):
                self.denied(f"INSERT INTO petita.birth_plans(patient_id,ubs_code) VALUES ('{profile}','TEST-A')", subject)

    def test_json_shape_constraints(self):
        self.denied(f"UPDATE petita.birth_plans SET answers_json='[]' WHERE id='{PLAN_A}'", state="23514")

    def test_runtime_cannot_become_owner_authorizer_or_disable_rls(self):
        self.denied("SET ROLE petita_schema_owner")
        self.denied("SET ROLE petita_authorizer")
        self.denied("ALTER TABLE petita.birth_plans DISABLE ROW LEVEL SECURITY")
        self.denied("SET LOCAL row_security=off; SELECT * FROM petita.birth_plans")
        self.denied("CREATE FUNCTION petita_private.evil() RETURNS integer LANGUAGE sql AS 'SELECT 1'")
        self.denied("TRUNCATE petita.birth_plans")

    def test_helper_role_cannot_read_clinical_plans_or_mutate_profiles(self):
        # Test-only role inherits authorizer, never the owner. No production grant.
        r = sql("SELECT * FROM petita.birth_plans", "petita_test_helper", check=False)
        self.assertNotEqual(r.returncode, 0)
        r = sql("UPDATE petita.profiles SET role='admin'", "petita_test_helper", check=False)
        self.assertNotEqual(r.returncode, 0)

    def test_transaction_context_does_not_leak(self):
        result = sql(f"BEGIN; SET LOCAL petita.issuer='{ISSUER}'; SET LOCAL petita.subject='patient-a'; SELECT count(*) FROM petita.birth_plans; COMMIT; SELECT count(*) FROM petita.birth_plans;")
        self.assertEqual(result.stdout.strip().splitlines(), ["1", "0"])

    def test_rls_force_and_function_acl_configuration(self):
        self.assertEqual(sql("SELECT count(*) FROM pg_class WHERE relkind='r' AND relnamespace IN ('petita'::regnamespace,'petita_private'::regnamespace) AND relname<>'schema_migrations' AND relrowsecurity AND relforcerowsecurity", "postgres").stdout.strip(), "5")
        self.assertEqual(sql("SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='petita_private' AND p.prosecdef AND (pg_get_userbyid(p.proowner)<>'petita_authorizer' OR p.proconfig IS DISTINCT FROM ARRAY['search_path=pg_catalog'])", "postgres").stdout.strip(), "0")
        self.assertEqual(sql("SELECT count(*) FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE p.pronamespace='petita_private'::regnamespace AND a.grantee=0 AND a.privilege_type='EXECUTE'", "postgres").stdout.strip(), "0")

    def test_identity_uniqueness_and_fk_constraints(self):
        r = sql(f"BEGIN; INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES ('{ISSUER}','patient-a','{B}'); ROLLBACK;", "postgres", check=False)
        self.assertIn("23505", r.stderr)
        r = sql(f"BEGIN; DELETE FROM petita.profiles WHERE id='{A}'; ROLLBACK;", "postgres", check=False)
        self.assertIn("23503", r.stderr)

    def test_guard_and_rollback_preserve_data_and_public_schema(self):
        r = migrate("down", check=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("P0001", r.stderr)
        self.assertEqual(sql("SELECT count(*) FROM public.legacy_sentinel", "postgres").stdout.strip(), "1")
        self.assertEqual(self.value("SELECT id FROM petita.birth_plans"), PLAN_A)

    def test_rollback_cannot_mistake_rls_hidden_rows_for_empty_tables(self):
        # A schema-owner member without bypass must fail safely, even if RLS
        # would hide all rows. It is never used to simulate a patient.
        r = migrate("down", user="petita_test_migrator", check=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(self.value("SELECT id FROM petita.birth_plans"), PLAN_A)

    def test_empty_rollback_reapply_and_unguarded_apply(self):
        sql("CREATE DATABASE petita_empty", "postgres")
        r = migrate(database="petita_empty", check=False, guarded=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(sql("SELECT count(*) FROM pg_namespace WHERE nspname='petita'", "postgres", "petita_empty").stdout.strip(), "0")
        migrate(database="petita_empty")
        migrate("down", database="petita_empty")
        migrate(database="petita_empty")
        r = migrate(database="petita_empty", check=False)
        self.assertNotEqual(r.returncode, 0)


def start_container():
    # No exposed port; trust is only inside this networkless throwaway container.
    docker("run", "-d", "--name", CONTAINER, "--network=none",
           "--tmpfs", "/var/lib/postgresql/data:rw", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
           "-e", "POSTGRES_DB=petita_test", IMAGE)
    for _ in range(120):
        # The entrypoint briefly starts a socket-only bootstrap server.
        # TCP readiness (loopback inside network=none) waits for the final one.
        if docker("exec", CONTAINER, "pg_isready", "-h", "127.0.0.1", "-U", "postgres", check=False).returncode == 0:
            break
        time.sleep(0.25)
    else:
        raise RuntimeError("isolated PostgreSQL did not become ready")
    print("PostgreSQL:", sql("SHOW server_version", "postgres").stdout.strip(), flush=True)


def setup_foundation():
    sql("CREATE TABLE public.legacy_sentinel(value text); INSERT INTO public.legacy_sentinel VALUES ('synthetic-preservation-marker');", "postgres")
    sql("CREATE ROLE petita_test_migrator LOGIN NOSUPERUSER NOCREATEDB CREATEROLE NOBYPASSRLS INHERIT; GRANT CREATE ON DATABASE petita_test TO petita_test_migrator;", "postgres")
    # Verify schema/role creation without a PostgreSQL superuser.
    migrate(user="petita_test_migrator")
    sql(f"""
      INSERT INTO petita.ubs(code,name) VALUES ('TEST-A','Synthetic A'),('TEST-B','Synthetic B');
      INSERT INTO petita.profiles(id,display_name,role,ubs_code,active) VALUES
        ('{A}','Synthetic patient A','patient','TEST-A',true),
        ('{B}','Synthetic patient B','patient','TEST-B',true),
        ('{TEAM_A}','Synthetic team A','ubs_team','TEST-B',true),
        ('{TEAM_B}','Synthetic team B','ubs_team','TEST-A',true),
        ('{ADMIN}','Synthetic admin','admin',NULL,true),
        ('{INACTIVE}','Synthetic inactive','patient','TEST-A',false),
        ('{UNAPPROVED}','Synthetic unapproved','ubs_team','TEST-A',true);
      INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES
        ('{ISSUER}','patient-a','{A}'),('{ISSUER}','patient-b','{B}'),
        ('{ISSUER}','team-a','{TEAM_A}'),('{ISSUER}','team-b','{TEAM_B}'),
        ('{ISSUER}','admin','{ADMIN}'),('{ISSUER}','inactive','{INACTIVE}'),
        ('{ISSUER}','unapproved','{UNAPPROVED}');
      INSERT INTO petita_private.ubs_memberships(profile_id,ubs_code,approved_by,approved_at) VALUES
        ('{TEAM_A}','TEST-A','{ADMIN}',now()),('{TEAM_B}','TEST-B','{ADMIN}',now());
      INSERT INTO petita.birth_plans(id,patient_id,ubs_code) VALUES
        ('{PLAN_A}','{A}','TEST-A'),('{PLAN_B}','{B}','TEST-B');
      CREATE ROLE petita_test_client LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS INHERIT;
      GRANT petita_runtime TO petita_test_client;
      CREATE ROLE petita_test_helper LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS INHERIT;
      GRANT petita_authorizer TO petita_test_helper;
    """, "postgres")


def main():
    created = False
    try:
        start_container()
        created = True
        setup_foundation()
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AuthorizationTests))
        return 0 if result.wasSuccessful() else 1
    except subprocess.CalledProcessError as error:
        print("Isolated test setup failed:", error.stderr)
        return 1
    finally:
        if created:
            docker("rm", "-f", CONTAINER, check=False)


if __name__ == "__main__":
    raise SystemExit(main())
