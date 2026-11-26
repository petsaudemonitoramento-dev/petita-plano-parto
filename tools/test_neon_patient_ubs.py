#!/usr/bin/env python3
"""Real PostgreSQL/RLS tests in disposable Cloud Docker. Synthetic Auth table only."""
import json
import subprocess
import unittest
import test_neon_foundation as base
import test_neon_workflows as workflows
import test_neon_enrollment_sync as enrollment

class PatientUbsTests(enrollment.EnrollmentSyncTests):
    def ask(self, subject, code='TEST-A', operation=None):
        return json.loads(self.value(subject,f"SELECT petita.request_patient_ubs('{code}','{operation or enrollment.uid()}')"))

    def test_08_request_is_pending_idempotent_and_does_not_change_role_or_ubs(self):
        s,_=self.enroll(); operation=enrollment.uid()
        r=self.ask(s,operation=operation)
        self.assertEqual(r['status'],'pending')
        self.assertEqual(self.ask(s,operation=operation),r)
        self.assertEqual(self.value(s,"SELECT role||':'||coalesce(ubs_code,'none') FROM petita.profiles"),'patient:none')
        self.deny(s,f"SELECT petita.request_patient_ubs('TEST-B','{operation}')",'P0001')
        self.deny(s,"UPDATE petita.profiles SET ubs_code='TEST-A'")
        self.deny(s,f"SELECT petita.decide_patient_ubs('{r['id']}',true)")

    def test_09_admin_approves_and_revokes_without_plan_loss(self):
        s,p=self.enroll(); self.consent(s); plan=enrollment.uid(); self.new_plan(s,plan)
        r=self.ask(s)
        self.value('admin',f"SELECT petita.decide_patient_ubs('{r['id']}',true)")
        self.assertEqual(self.value(s,'SELECT petita_private.actor_ubs()'),'TEST-A')
        self.assertEqual(self.value(s,'SELECT role FROM petita.profiles'),'patient')
        self.deny('admin',f"SELECT petita.decide_patient_ubs('{r['id']}',true)",'P0001')
        self.value('admin',f"SELECT petita.revoke_patient_ubs('{p}','Synthetic revocation')")
        self.assertEqual(self.value(s,"SELECT coalesce(petita_private.actor_ubs(),'none')"),'none')
        self.assertEqual(self.value(s,f"SELECT count(*) FROM petita.birth_plans WHERE id='{plan}'"),'1')

    def test_10_cross_patient_team_and_anonymous_cannot_manage_membership(self):
        a,p=self.enroll(); b,_=self.enroll(); r=self.ask(a)
        self.assertEqual(self.value(b,'SELECT count(*) FROM petita.list_my_ubs_requests()'),'0')
        for s in [b,'team-a','team-b','inactive','']:
            self.deny(s,'SELECT * FROM petita.list_patient_ubs_requests()')
            self.deny(s,f"SELECT petita.decide_patient_ubs('{r['id']}',true)")
            self.deny(s,f"SELECT petita.revoke_patient_ubs('{p}','Synthetic revocation')")
        self.deny(a,'SELECT * FROM petita_private.patient_ubs_requests')
        self.deny(a,'SET ROLE petita_access_executor')

    def test_11_inactive_or_missing_ubs_denied_and_rejection_keeps_no_membership(self):
        s,_=self.enroll()
        self.deny(s,f"SELECT petita.request_patient_ubs('MISSING','{enrollment.uid()}')",'22023')
        r=self.ask(s)
        self.value('admin',f"SELECT petita.decide_patient_ubs('{r['id']}',false)")
        self.assertEqual(self.value(s,"SELECT coalesce(petita_private.actor_ubs(),'none')"),'none')


def main():
    created=False
    try:
        base.start_container(); created=True; base.setup_foundation()
        workflows.migration(2); workflows.migration(3)
        base.sql('''CREATE SCHEMA neon_auth;
          CREATE TABLE neon_auth."user"(id uuid PRIMARY KEY,name text,"emailVerified" boolean,banned boolean);
          GRANT USAGE ON SCHEMA neon_auth TO petita_test_migrator WITH GRANT OPTION;
          GRANT SELECT ON neon_auth."user" TO petita_test_migrator WITH GRANT OPTION;''','postgres')
        for name in ['004_auth_enrollment','005_sync_consent','006_patient_ubs']:
            base.sql(f"SET petita.migration_target='isolated-homologation'; SET petita.auth_issuer='{base.ISSUER}';\n"+
                     (base.MIGRATIONS/f'{name}.up.sql').read_text(),'petita_test_migrator')
        r=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PatientUbsTests))
        return 0 if r.wasSuccessful() else 1
    except subprocess.CalledProcessError as e:
        print('Isolated setup failed:',e.stderr); return 1
    finally:
        if created: base.docker('rm','-f',base.CONTAINER,check=False)
if __name__=='__main__':raise SystemExit(main())
