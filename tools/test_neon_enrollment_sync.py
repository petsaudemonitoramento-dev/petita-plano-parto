#!/usr/bin/env python3
"""Disposable PostgreSQL integration suite. Fake Auth table, not real Neon OTP/JWT.
No network, real patient data, remote DSN or credentials. Reuses pinned image."""
import subprocess
import unittest
import uuid

import test_neon_foundation as base
import test_neon_workflows as workflows

VER = "2026-10-21-v1"
ISSUER = base.ISSUER

def uid():
    return str(uuid.uuid4())

def request(subject, statement, issuer=ISSUER, check=True):
    return base.sql(f"BEGIN; SET LOCAL ROLE petita_runtime; SET LOCAL petita.issuer='{issuer}'; "
                    f"SET LOCAL petita.subject='{subject}'; {statement}; COMMIT;",
                    check=check)

def fixture(verified=True, banned=False):
    subject=uid()
    base.sql(f"""INSERT INTO neon_auth."user"(id,name,"emailVerified",banned)
                 VALUES('{subject}','Synthetic fixture',{str(verified).lower()},{str(banned).lower()})""", "postgres")
    return subject

class EnrollmentSyncTests(unittest.TestCase):
    def value(self, subject, statement, issuer=ISSUER):
        return request(subject, statement, issuer).stdout.strip()

    def deny(self, subject, statement, state="42501", issuer=ISSUER):
        r=request(subject,statement,issuer,check=False)
        self.assertNotEqual(r.returncode,0)
        self.assertIn(state,r.stderr)

    def enroll(self):
        subject=fixture()
        profile=self.value(subject,"SELECT petita.ensure_patient_profile()")
        self.assertEqual(str(uuid.UUID(profile)),profile)
        return subject,profile

    def consent(self, subject, action="grant"):
        return self.value(subject,f"""INSERT INTO petita.sync_consent_events
          (patient_id,terms_version,operation_id,action)
          VALUES(petita_private.actor_id(),'{VER}','{uid()}','{action}')
          RETURNING action""")

    def new_plan(self, subject, plan):
        return self.value(subject,f"""INSERT INTO petita.birth_plans(id,patient_id,ubs_code,answers_json)
          VALUES('{plan}',petita_private.actor_id(),petita_private.actor_ubs(),'{{}}')
          RETURNING revision""")

    def test_01_identity_positive_and_idempotent(self):
        s,p=self.enroll()
        self.assertEqual(self.value(s,"SELECT petita.auth_identity_active()"),"t")
        self.assertEqual(self.value(s,"SELECT petita.ensure_patient_profile()"),p)
        self.assertEqual(self.value(s,"SELECT role||':'||coalesce(ubs_code,'none') FROM petita.profiles"),"patient:none")

    require_verified_patient = True

    def test_02_identity_denials(self):
        for s,issuer in [("",ISSUER),(uid(),ISSUER),*([(fixture(False),ISSUER)] if self.require_verified_patient else []),
                         (fixture(True,True),ISSUER),(fixture(),"https://wrong.invalid")]:
            self.assertEqual(self.value(s,"SELECT petita.auth_identity_active()",issuer),"f")
            self.deny(s,"SELECT petita.ensure_patient_profile()",issuer=issuer)

    def test_03_no_direct_auth_or_identity_reads(self):
        s,_=self.enroll()
        for table in ['neon_auth."user"','petita_private.identities','petita_private.auth_provider_config']:
            self.deny(s,"SELECT * FROM "+table)
        self.deny(s,"SET ROLE petita_enrollment_executor")
        self.deny(s,"UPDATE petita.profiles SET role='admin'")

    def test_04_live_ban(self):
        s,_=self.enroll()
        base.sql(f"""UPDATE neon_auth."user" SET banned=true WHERE id='{s}'""","postgres")
        self.assertEqual(self.value(s,"SELECT petita.auth_identity_active()"),"f")
        self.deny(s,"SELECT petita.ensure_patient_profile()")

    def test_05_consent_required_and_revocable(self):
        s,_=self.enroll()
        self.assertEqual(self.value(s,"SELECT petita.has_sync_consent()"),"f")
        plan=uid()
        self.deny(s,f"INSERT INTO petita.birth_plans(id,patient_id) VALUES('{plan}',petita_private.actor_id())")
        self.assertEqual(self.consent(s),"grant")
        self.assertEqual(self.new_plan(s,plan),"1")
        self.assertEqual(self.consent(s,"withdraw"),"withdraw")
        self.assertEqual(self.value(s,"SELECT petita.has_sync_consent()"),"f")
        self.assertEqual(self.value(s,f"UPDATE petita.birth_plans SET revision=2 WHERE id='{plan}' RETURNING revision"),"")
        self.assertEqual(self.value(s,f"SELECT revision FROM petita.birth_plans WHERE id='{plan}'"),"1")
        self.assertEqual(self.consent(s),"grant")
        self.assertEqual(self.value(s,f"UPDATE petita.birth_plans SET revision=revision+1 WHERE id='{plan}' AND revision=1 RETURNING revision"),"2")
        self.assertEqual(self.value(s,f"UPDATE petita.birth_plans SET revision=revision+1 WHERE id='{plan}' AND revision=1 RETURNING revision"),"")

    def test_06_cross_patient_consent_and_plan(self):
        a,p=self.enroll()
        b,_=self.enroll()
        self.consent(a)
        self.consent(b)
        plan=uid()
        self.new_plan(a,plan)
        self.assertEqual(self.value(b,f"SELECT count(*) FROM petita.birth_plans WHERE id='{plan}'"),"0")
        self.assertEqual(self.value(b,f"SELECT count(*) FROM petita.sync_consent_events WHERE patient_id='{p}'"),"0")
        self.deny(b,f"INSERT INTO petita.sync_consent_events(patient_id,terms_version,operation_id,action) VALUES('{p}','{VER}','{uid()}','grant')")
        self.assertEqual(self.value(b,f"UPDATE petita.birth_plans SET revision=2 WHERE id='{plan}' RETURNING revision"),"")

    def test_07_consent_history_append_only(self):
        s,_=self.enroll()
        self.consent(s)
        self.deny(s,"UPDATE petita.sync_consent_events SET action='withdraw'")
        self.deny(s,"DELETE FROM petita.sync_consent_events")
        self.deny(s,f"INSERT INTO petita.sync_consent_events(patient_id,terms_version,operation_id,action) VALUES(petita_private.actor_id(),'old','{uid()}','grant')","23514")

def main():
    created=False
    try:
        base.start_container()
        created=True
        base.setup_foundation()
        workflows.migration(2)
        workflows.migration(3)
        # Explicit fake Neon Auth table: fixtures only, no managed schema touched.
        base.sql("""CREATE SCHEMA neon_auth;
          CREATE TABLE neon_auth."user"(id uuid PRIMARY KEY,name text,"emailVerified" boolean,banned boolean);
          GRANT USAGE ON SCHEMA neon_auth TO petita_test_migrator WITH GRANT OPTION;
          GRANT SELECT ON neon_auth."user" TO petita_test_migrator WITH GRANT OPTION;
        ""","postgres")
        for name in ["004_auth_enrollment","005_sync_consent"]:
            base.sql(f"SET petita.migration_target='isolated-homologation'; SET petita.auth_issuer='{ISSUER}';\n"+
              (base.MIGRATIONS / f"{name}.up.sql").read_text(),"petita_test_migrator")
        r=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(EnrollmentSyncTests))
        return 0 if r.wasSuccessful() else 1
    except subprocess.CalledProcessError as e:
        print("Isolated setup failed:",e.stderr)
        return 1
    finally:
        if created:
            base.docker("rm","-f",base.CONTAINER,check=False)

if __name__=="__main__":
    raise SystemExit(main())
