#!/usr/bin/env python3
"""Admin approval checks against disposable PostgreSQL, synthetic auth records only."""
import subprocess
import unittest
import test_neon_foundation as base
import test_neon_workflows as workflows
import test_neon_enrollment_sync as enrollment

class AdminApprovalTests(unittest.TestCase):
    def value(self, subject, statement):
        return enrollment.request(subject,statement).stdout.strip()
    def deny(self, subject, statement, state='42501'):
        r=enrollment.request(subject,statement,check=False)
        self.assertNotEqual(r.returncode,0)
        self.assertIn(state,r.stderr)
    def google(self, verified=True, linked=True):
        subject=enrollment.uid()
        base.sql(f"""INSERT INTO neon_auth."user"(id,name,email,"emailVerified",banned)
          VALUES('{subject}','Synthetic administrator','{subject}@example.invalid',{str(verified).lower()},false)""",'postgres')
        if linked:
            base.sql(f"""INSERT INTO neon_auth.account("userId","providerId") VALUES('{subject}','google')""",'postgres')
        return subject
    def candidate(self):
        subject=self.google()
        profile=self.value(subject,'SELECT petita.ensure_admin_candidate()')
        self.assertEqual(self.value(subject,'SELECT role FROM petita.profiles'),'admin_pending')
        return subject,profile
    def test_only_other_admin_can_approve(self):
        s,p=self.candidate()
        self.assertEqual(self.value(s,'SELECT petita.ensure_admin_candidate()'),p)
        self.assertEqual(self.value(s,'SELECT status FROM petita.my_admin_request()'),'pending')
        self.assertEqual(self.value(s,'SELECT petita_private.is_admin()'),'f')
        self.deny(s,'SELECT * FROM petita.list_admin_requests()')
        self.deny(s,f"SELECT petita.decide_admin_request('{p}',true)")
        self.deny(s,"UPDATE petita.profiles SET role='admin'")
        self.deny(s,'SET ROLE petita_admin_request_executor')
        self.deny(s,'SELECT * FROM petita_private.admin_access_requests')
        b,bp=self.candidate()
        self.deny(b,f"SELECT petita.decide_admin_request('{p}',true)")
        self.assertEqual(self.value('admin',f"SELECT count(*) FROM petita.list_admin_requests() WHERE requester_id='{p}'"),'1')
        self.assertEqual(self.value('admin',f"SELECT petita.decide_admin_request('{p}',true)"),'approved')
        self.assertEqual(self.value(s,'SELECT petita_private.is_admin()'),'t')
        self.assertEqual(self.value(s,'SELECT status FROM petita.my_admin_request()'),'approved')
        self.deny('admin',f"SELECT petita.decide_admin_request('{p}',true)",'P0001')
        self.deny(s,f"SELECT petita.decide_admin_request('{p}',true)")
        self.assertEqual(self.value(s,f"SELECT petita.decide_admin_request('{bp}',true)"),'approved')
        self.assertEqual(self.value(b,'SELECT petita_private.is_admin()'),'t')
    def test_unverified_and_non_google_cannot_request(self):
        for s in [self.google(False),self.google(True,False)]:
            self.deny(s,'SELECT petita.ensure_admin_candidate()')
        s=self.google()
        self.value(s,'SELECT petita.ensure_patient_profile()')
        self.deny(s,'SELECT petita.ensure_admin_candidate()')
        self.assertEqual(self.value(s,'SELECT role FROM petita.profiles'),'patient')
    def test_rejected_and_banned_candidate_remain_unprivileged(self):
        s,p=self.candidate()
        self.assertEqual(self.value('admin',f"SELECT petita.decide_admin_request('{p}',false)"),'rejected')
        self.assertEqual(self.value(s,'SELECT petita.ensure_admin_candidate()'),p)
        self.assertEqual(self.value(s,'SELECT status FROM petita.my_admin_request()'),'rejected')
        self.assertEqual(self.value(s,'SELECT petita_private.is_admin()'),'f')
        self.deny('admin',f"SELECT petita.decide_admin_request('{p}',true)",'P0001')
        b,bp=self.candidate()
        base.sql(f"""UPDATE neon_auth."user" SET banned=true WHERE id='{b}'""",'postgres')
        self.deny('admin',f"SELECT petita.decide_admin_request('{bp}',true)")
        self.assertEqual(self.value(b,'SELECT petita_private.is_admin()'),'f')

def main():
    created=False
    try:
        base.start_container(); created=True; base.setup_foundation()
        workflows.migration(2); workflows.migration(3)
        base.sql('''CREATE SCHEMA neon_auth;
          CREATE TABLE neon_auth."user"(id uuid PRIMARY KEY,name text,email text,"emailVerified" boolean,banned boolean);
          CREATE TABLE neon_auth.account("userId" uuid REFERENCES neon_auth."user"(id),"providerId" text,PRIMARY KEY("userId","providerId"));
          GRANT USAGE ON SCHEMA neon_auth TO petita_test_migrator WITH GRANT OPTION;
          GRANT SELECT ON neon_auth."user",neon_auth.account TO petita_test_migrator WITH GRANT OPTION;''','postgres')
        for name in ['004_auth_enrollment','005_sync_consent','006_patient_ubs','007_patient_signup','008_educational_knowledge','009_patient_no_ubs_preference','010_professional_enrollment','011_admin_google_approval']:
            base.sql(f"SET petita.migration_target='isolated-homologation'; SET petita.auth_issuer='{base.ISSUER}';\n"+(base.MIGRATIONS/f'{name}.up.sql').read_text(),'petita_test_migrator')
        result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AdminApprovalTests))
        return 0 if result.wasSuccessful() else 1
    except subprocess.CalledProcessError as e:
        print('Isolated setup failed:',e.stderr); return 1
    finally:
        if created: base.docker('rm','-f',base.CONTAINER,check=False)
if __name__=='__main__':raise SystemExit(main())
