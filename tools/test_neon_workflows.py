#!/usr/bin/env python3
"""Synthetic SQL workflow tests, including real concurrent client connections."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import time
import unittest
import uuid

import test_neon_foundation as base

ADMIN_B = '00000000-0000-4000-8000-000000000008'
TEAM_A2 = '00000000-0000-4000-8000-000000000009'
INACTIVE_TEAM = '00000000-0000-4000-8000-000000000010'


def literal(value):
    # Fixtures only, never a production SQL/HTTP adapter.
    return "'" + str(value).replace("'", "''") + "'"


def migration(number, direction='up', database='petita_test', user='petita_test_migrator', check=True):
    name = {2: '002_patient_questions', 3: '003_team_access'}[number]
    return base.sql("SET petita.migration_target='isolated-homologation';\n" +
                    (base.MIGRATIONS / f'{name}.{direction}.sql').read_text(), user, database, check=check)


def request(statement, subject='patient-a', commit=True, check=True, app=None):
    setting = f'SET application_name={literal(app)};' if app else ''
    return base.sql(setting + f'BEGIN; SET LOCAL petita.issuer={literal(base.ISSUER)}; '
                    f'SET LOCAL petita.subject={literal(subject)};' + statement + ';' +
                    ('COMMIT;' if commit else 'ROLLBACK;'), check=check)


def submit_sql(key=None, unit='TEST-A', text='Synthetic educational question', risk='low', signs='ARRAY[]::text[]', urgent='false', notice='true'):
    return (f'SELECT petita.submit_patient_question({literal(key or uuid.uuid4())}::uuid,'
            f'{literal(unit)},\'Synthetic\',{literal(text)},{literal(risk)},{signs},{urgent},{notice})')


def answer_sql(q, text='Synthetic team answer', key=None):
    return f'SELECT petita.respond_to_patient_question({literal(q)}::uuid,{literal(text)},{literal(key or uuid.uuid4())}::uuid)'


def request_sql(unit='TEST-A', key=None):
    return f'SELECT petita.request_ubs_team_access({literal(unit)},{literal(key or uuid.uuid4())}::uuid)'


def scalar(statement):
    return base.sql(statement, 'postgres').stdout.strip()


def wait_for_sleep(app):
    for _ in range(150):
        if scalar(f"SELECT count(*) FROM pg_stat_activity WHERE application_name={literal(app)} AND wait_event='PgSleep'") == '1':
            return
        time.sleep(0.02)
    raise AssertionError('test transaction did not reach expected pause')


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        base.sql(f"""
          BEGIN;
          DELETE FROM petita_private.question_events;
          DELETE FROM petita.ubs_answers;
          DELETE FROM petita_private.question_patient_links;
          DELETE FROM petita.patient_questions;
          DELETE FROM petita_private.team_access_events;
          DELETE FROM petita_private.team_access_requests;
          DELETE FROM petita_private.ubs_memberships WHERE profile_id IN ('{base.A}','{base.B}','{base.UNAPPROVED}');
          UPDATE petita_private.ubs_memberships SET active=true;
          UPDATE petita.profiles SET role='patient',active=true WHERE id IN ('{base.A}','{base.B}');
          UPDATE petita.profiles SET active=true WHERE id IN ('{base.TEAM_A}','{base.TEAM_B}','{TEAM_A2}','{base.ADMIN}','{ADMIN_B}');
          UPDATE petita.ubs SET active=true;
          COMMIT;
        """, 'postgres')

    def value(self, statement, subject='patient-a', commit=True):
        return request(statement, subject, commit).stdout.strip()

    def json_value(self, statement, subject='patient-a', commit=True):
        return json.loads(self.value(statement, subject, commit))

    def denied(self, statement, subject='patient-a', state='42501'):
        result = request(statement, subject, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(state, result.stderr)

    def submit(self, subject='patient-a', **kwargs):
        return self.json_value(submit_sql(**kwargs), subject)

    def rows(self, function, subject='patient-a'):
        return self.json_value(f"SELECT coalesce(jsonb_agg(to_jsonb(q)),'[]') FROM {function} q", subject)

    def test_01_live_login_and_no_direct_data_or_executor_role(self):
        self.assertEqual(self.value('SELECT current_user'), 'petita_test_client')
        self.assertEqual(self.value("SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user"), 'f')
        for role in ['petita_questions_executor','petita_access_executor']:
            self.denied('SET ROLE '+role)
            self.assertEqual(scalar(f"SELECT has_table_privilege({literal(role)},'petita.birth_plans','SELECT')"), 'f')
        for table in ['petita.patient_questions','petita.ubs_answers','petita_private.question_patient_links',
                      'petita_private.question_events','petita_private.team_access_requests','petita_private.team_access_events']:
            self.denied('SELECT * FROM '+table)
            self.denied('DELETE FROM '+table)

    def test_submit_own_unit_and_private_link_atomic(self):
        q = self.submit()
        self.assertTrue(q['public_code'].startswith('DUV-'))
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '1')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_patient_links'), '1')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_events'), '1')
        self.assertEqual(self.rows('petita.list_my_patient_questions()')[0]['id'], q['id'])

    def test_idempotent_submission_and_changed_payload_conflict(self):
        key = str(uuid.uuid4())
        first = self.submit(key=key)
        self.assertEqual(first, self.submit(key=key))
        self.denied(submit_sql(key=key,text='Different synthetic body'), state='P0001')
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '1')

    def test_idempotency_key_is_scoped_per_patient(self):
        key = str(uuid.uuid4())
        a = self.submit(key=key)
        b = self.submit('patient-b', key=key, unit='TEST-B')
        self.assertNotEqual(a['id'], b['id'])

    def test_submission_blocks_unapproved_identity_roles_and_ubs(self):
        for subject in ['', 'unknown', 'inactive', 'inactive-team', 'admin', 'team-a', 'unapproved']:
            with self.subTest(subject=subject):
                self.denied(submit_sql(), subject)
        self.denied(submit_sql(unit='TEST-B'))
        self.denied(submit_sql(unit='nonexistent'))
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '0')

    def test_content_size_and_acknowledgements_are_enforced(self):
        cases = [dict(text='  '), dict(text='x'*1501), dict(risk='invalid'), dict(notice='false'),
                 dict(notice='NULL'), dict(urgent='NULL'), dict(risk='high'),
                 dict(signs="ARRAY['synthetic-warning']"), dict(signs='NULL::text[]'),
                 dict(signs='ARRAY[NULL]::text[]')]
        for params in cases:
            with self.subTest(params=list(params)):
                self.denied(submit_sql(**params), state='22023')
        self.submit(risk='high', signs="ARRAY['synthetic-warning']", urgent='true')
        self.assertEqual(scalar('SELECT urgency_acknowledged AND expected_response_notice_accepted FROM petita.patient_questions'), 't')

    def test_public_code_and_forged_ids_do_not_grant_access(self):
        a = self.submit()
        b = self.submit('patient-b', unit='TEST-B')
        self.assertEqual([q['id'] for q in self.rows('petita.list_my_patient_questions()')], [a['id']])
        self.assertEqual([q['id'] for q in self.rows('petita.list_my_patient_questions()', 'patient-b')], [b['id']])
        self.assertEqual(self.value(f"SELECT count(*) FROM petita.list_my_patient_questions() WHERE public_code={literal(a['public_code'])}", 'patient-b'), '0')
        self.assertEqual(self.value(f"SELECT count(*) FROM petita.list_my_patient_questions() WHERE id={literal(a['id'])}::uuid", 'patient-b'), '0')
        self.denied('SELECT * FROM petita.list_my_patient_questions()', '')

    def test_team_queue_is_minimal_and_unit_scoped(self):
        a, b = self.submit(), self.submit('patient-b', unit='TEST-B')
        queue = self.rows('petita.list_team_patient_questions()', 'team-a')
        self.assertEqual([q['id'] for q in queue], [a['id']])
        self.assertEqual(set(queue[0]), {'id','public_code','ubs_code','category','question_text','self_risk_level','warning_signs','created_at'})
        self.assertEqual(self.rows('petita.list_team_patient_questions()', 'team-b')[0]['id'], b['id'])
        for subject in ['patient-a','admin','unapproved','inactive-team','']:
            self.denied('SELECT * FROM petita.list_team_patient_questions()', subject)
        self.assertEqual(self.value('SELECT count(*) FROM petita.birth_plans', 'team-a'), '0')

    def test_response_author_and_history_and_private_delivery(self):
        q = self.submit()
        a = self.json_value(answer_sql(q['id']), 'team-a')
        self.assertEqual(a['status'], 'answered')
        self.assertEqual(scalar('SELECT answered_by FROM petita.ubs_answers'), base.TEAM_A)
        self.assertEqual(scalar("SELECT count(*) FROM petita_private.question_events WHERE event='answered'"), '1')
        self.assertEqual(self.rows('petita.list_my_patient_questions()')[0]['answer_text'], 'Synthetic team answer')
        self.assertEqual(self.rows('petita.list_my_patient_questions()', 'patient-b'), [])
        self.assertEqual(self.rows('petita.list_team_patient_questions()', 'team-a'), [])

    def test_response_blocks_foreign_unit_unknown_ids_and_unapproved(self):
        q = self.submit()
        for subject in ['team-b','unapproved','inactive-team','admin','patient-a','']:
            self.denied(answer_sql(q['id']), subject)
        self.denied(answer_sql(uuid.uuid4()), 'team-a')
        self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '0')

    def test_response_retry_and_changed_duplicate_conflict(self):
        q, key = self.submit(), str(uuid.uuid4())
        first = self.json_value(answer_sql(q['id'],key=key), 'team-a')
        self.assertEqual(first, self.json_value(answer_sql(q['id'],key=key), 'team-a'))
        self.denied(answer_sql(q['id'],key=key,text='Changed synthetic answer'), 'team-a', 'P0001')
        self.denied(answer_sql(q['id']), 'team-a', 'P0001')
        self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '1')

    def test_approval_and_membership_are_atomic_and_traced(self):
        r = self.json_value(request_sql(), 'patient-a')
        self.assertEqual(self.value('SELECT petita_private.team_ubs()'), '')
        decision = self.json_value(f"SELECT petita.decide_team_access_request({literal(r['id'])}::uuid,true)", 'admin')
        self.assertEqual(decision['status'], 'approved')
        self.assertEqual(decision['decided_by'], base.ADMIN)
        self.assertEqual(self.value('SELECT petita_private.team_ubs()'), 'TEST-A')
        self.assertEqual(scalar(f"SELECT role FROM petita.profiles WHERE id='{base.A}'"), 'ubs_team')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.team_access_events'), '1')

    def test_rejection_does_not_grant_privileges(self):
        r = self.json_value(request_sql(), 'patient-a')
        self.json_value(f"SELECT petita.decide_team_access_request({literal(r['id'])}::uuid,false)", 'admin')
        self.assertEqual(self.value('SELECT petita_private.team_ubs()'), '')
        self.assertEqual(scalar(f"SELECT role FROM petita.profiles WHERE id='{base.A}'"), 'patient')

    def test_decision_is_admin_only_and_self_approval_is_blocked(self):
        r = self.json_value(request_sql(), 'patient-a')
        for subject in ['patient-a','team-a','unapproved','inactive','']:
            self.denied(f"SELECT petita.decide_team_access_request({literal(r['id'])}::uuid,true)", subject)
        own = str(uuid.uuid4())
        base.sql(f"INSERT INTO petita_private.team_access_requests(id,requester_id,requested_ubs_code,idempotency_key) VALUES('{own}','{base.ADMIN}','TEST-A',gen_random_uuid())", 'postgres')
        self.denied(f"SELECT petita.decide_team_access_request('{own}',true)", 'admin')
        self.denied(f"SELECT petita.decide_team_access_request('{uuid.uuid4()}',true)", 'admin')
        base.sql(f"UPDATE petita.profiles SET active=false WHERE id='{ADMIN_B}'", 'postgres')
        self.denied(f"SELECT petita.decide_team_access_request('{r['id']}',true)", 'admin-b')

    def test_repeated_decisions_conflict(self):
        r = self.json_value(request_sql(), 'patient-a')
        command = f"SELECT petita.decide_team_access_request({literal(r['id'])}::uuid,false)"
        self.value(command, 'admin')
        self.denied(command, 'admin', 'P0001')
        self.denied(command.replace('false','true'), 'admin', 'P0001')

    def test_request_is_idempotent_and_cannot_self_assign_role_or_unit(self):
        key = str(uuid.uuid4())
        r = self.json_value(request_sql(key=key))
        self.assertEqual(r, self.json_value(request_sql(key=key)))
        self.denied(request_sql(unit='TEST-B', key=key), state='P0001')
        self.denied(request_sql(), state='P0001')
        self.denied("UPDATE petita.profiles SET role='admin'")
        self.denied('SELECT * FROM petita.list_team_access_requests()')
        self.assertEqual(len(self.rows('petita.list_team_access_requests()', 'admin')), 1)
        self.assertEqual(scalar(f"SELECT role FROM petita.profiles WHERE id='{base.A}'"), 'patient')

    def test_immediate_membership_profile_and_unit_revocation(self):
        q = self.submit()
        self.value(f"SELECT petita.revoke_ubs_team_access('{base.TEAM_A}','Synthetic revocation')", 'admin')
        self.denied('SELECT * FROM petita.list_team_patient_questions()', 'team-a')
        self.denied(answer_sql(q['id']), 'team-a')
        self.denied(f"SELECT petita.revoke_ubs_team_access('{base.TEAM_B}','Synthetic')", 'patient-a')
        self.denied(f"SELECT petita.revoke_ubs_team_access('{base.ADMIN}','Synthetic')", 'admin')
        base.sql("UPDATE petita.ubs SET active=false WHERE code='TEST-B'", 'postgres')
        self.denied('SELECT * FROM petita.list_team_patient_questions()', 'team-b')
        base.sql(f"UPDATE petita.profiles SET active=false WHERE id='{TEAM_A2}'", 'postgres')
        self.denied(answer_sql(q['id']), 'team-a2')

    def test_submission_and_decision_rollback_no_partial_state(self):
        self.json_value(submit_sql(), commit=False)
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '0')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_patient_links'), '0')
        r = self.json_value(request_sql())
        self.json_value(f"SELECT petita.decide_team_access_request({literal(r['id'])}::uuid,true)", 'admin', commit=False)
        self.assertEqual(scalar('SELECT status FROM petita_private.team_access_requests'), 'pending')
        self.assertEqual(self.value('SELECT petita_private.team_ubs()'), '')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.team_access_events'), '0')

    def test_answer_rollback_preserves_pending_question(self):
        q = self.submit()
        self.json_value(answer_sql(q['id']), 'team-a', commit=False)
        self.assertEqual(scalar('SELECT status FROM petita.patient_questions'), 'pending')
        self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '0')

    def test_failure_inside_private_link_insert_leaves_no_orphan(self):
        base.sql("""
          CREATE FUNCTION petita_private.test_reject_link() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN RAISE EXCEPTION 'synthetic interruption'; END $$;
          CREATE TRIGGER test_reject BEFORE INSERT ON petita_private.question_patient_links
            FOR EACH ROW EXECUTE FUNCTION petita_private.test_reject_link();
        """, 'postgres')
        try:
            self.denied(submit_sql(), state='P0001')
            self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '0')
            self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_patient_links'), '0')
        finally:
            base.sql('DROP TRIGGER test_reject ON petita_private.question_patient_links; DROP FUNCTION petita_private.test_reject_link()', 'postgres')

    def test_failure_recording_answer_event_rolls_back_answer_and_status(self):
        q = self.submit()
        base.sql("""
          CREATE FUNCTION petita_private.test_reject_event() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN IF NEW.event='answered' THEN RAISE EXCEPTION 'synthetic interruption'; END IF; RETURN NEW; END $$;
          CREATE TRIGGER test_reject BEFORE INSERT ON petita_private.question_events
            FOR EACH ROW EXECUTE FUNCTION petita_private.test_reject_event();
        """, 'postgres')
        try:
            self.denied(answer_sql(q['id']), 'team-a', 'P0001')
            self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '0')
            self.assertEqual(scalar('SELECT status FROM petita.patient_questions'), 'pending')
        finally:
            base.sql('DROP TRIGGER test_reject ON petita_private.question_events; DROP FUNCTION petita_private.test_reject_event()', 'postgres')

    def test_real_concurrent_submission_single_question(self):
        command = submit_sql(key=str(uuid.uuid4()))
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: request(command), range(2)))
        self.assertEqual(json.loads(results[0].stdout), json.loads(results[1].stdout))
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '1')

    def test_real_concurrent_answers_single_winner(self):
        q = self.submit()
        with ThreadPoolExecutor(2) as pool:
            futures = [pool.submit(request, answer_sql(q['id']), s, True, False) for s in ['team-a','team-a2']]
            results = [f.result() for f in futures]
        self.assertEqual(sum(r.returncode == 0 for r in results), 1)
        self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '1')
        self.assertEqual(scalar("SELECT count(*) FROM petita_private.question_events WHERE event='answered'"), '1')

    def test_real_concurrent_decisions_single_winner(self):
        r = self.json_value(request_sql())
        with ThreadPoolExecutor(2) as pool:
            futures = [pool.submit(request, f"SELECT petita.decide_team_access_request('{r['id']}',{approve})", s, True, False)
                       for s, approve in [('admin','true'),('admin-b','false')]]
            results = [f.result() for f in futures]
        self.assertEqual(sum(r.returncode == 0 for r in results), 1)
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.team_access_events'), '1')
        status = scalar('SELECT status FROM petita_private.team_access_requests')
        self.assertEqual(self.value('SELECT petita_private.team_ubs()'), 'TEST-A' if status == 'approved' else '')

    def test_revocation_serializes_with_queued_answer(self):
        q = self.submit()
        with ThreadPoolExecutor(2) as pool:
            revoke = pool.submit(request, f"SELECT petita.revoke_ubs_team_access('{base.TEAM_A}','Synthetic concurrency'); SELECT pg_sleep(1)", 'admin', True, True, 'petita-revoke-race')
            wait_for_sleep('petita-revoke-race')
            response = pool.submit(request, answer_sql(q['id']), 'team-a', True, False)
            self.assertEqual(revoke.result().returncode, 0)
            self.assertNotEqual(response.result().returncode, 0)
        self.assertEqual(scalar('SELECT count(*) FROM petita.ubs_answers'), '0')

    def test_connection_interruption_rolls_back_question_and_link(self):
        key = str(uuid.uuid4())
        with ThreadPoolExecutor(1) as pool:
            future = pool.submit(request, submit_sql(key=key)+'; SELECT pg_sleep(15)', 'patient-a', True, False, 'petita-interruption')
            wait_for_sleep('petita-interruption')
            self.assertEqual(scalar("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name='petita-interruption'"), 't')
            self.assertNotEqual(future.result().returncode, 0)
        self.assertEqual(scalar('SELECT count(*) FROM petita.patient_questions'), '0')
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_patient_links'), '0')
        self.submit(key=key)
        self.assertEqual(scalar('SELECT count(*) FROM petita_private.question_events'), '1')

    def test_pagination_and_validation(self):
        for _ in range(3):
            self.submit()
        first = self.rows('petita.list_my_patient_questions(1)')[0]
        following = self.rows(f"petita.list_my_patient_questions(2,{literal(first['created_at'])}::timestamptz,{literal(first['id'])}::uuid)")
        self.assertEqual(len(following), 2)
        self.assertNotIn(first['id'], [q['id'] for q in following])
        self.denied('SELECT * FROM petita.list_my_patient_questions(101)', state='22023')

    def test_migration_acl_and_rls_and_rollback_guards(self):
        self.assertEqual(scalar("SELECT count(*) FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE p.pronamespace='petita'::regnamespace AND a.grantee=0 AND a.privilege_type='EXECUTE'"), '0')
        self.assertEqual(scalar("SELECT count(*) FROM pg_class WHERE relkind='r' AND relnamespace IN ('petita'::regnamespace,'petita_private'::regnamespace) AND relname<>'schema_migrations' AND NOT (relrowsecurity AND relforcerowsecurity)"), '0')
        self.json_value(request_sql())
        self.assertNotEqual(migration(3, 'down', user='postgres', check=False).returncode, 0)
        self.assertEqual(scalar('SELECT count(*) FROM public.legacy_sentinel'), '1')

    def test_stale_snapshot_isolation_is_rejected(self):
        self.denied('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; '+submit_sql(), state='25000')
        self.denied('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; SELECT * FROM petita.list_team_patient_questions()', 'team-a', '25000')
        self.denied('SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; SELECT * FROM petita.list_team_access_requests()', 'admin', '25000')

    def test_empty_migration_rollback_and_reapply(self):
        base.sql('CREATE DATABASE petita_workflows_empty', 'postgres')
        base.migrate(database='petita_workflows_empty')
        for n in [2,3]:
            migration(n, database='petita_workflows_empty', user='postgres')
        for n in [3,2]:
            migration(n, 'down', database='petita_workflows_empty', user='postgres')
        for n in [2,3]:
            migration(n, database='petita_workflows_empty', user='postgres')
        self.assertEqual(base.sql('SELECT count(*) FROM petita_private.schema_migrations', 'postgres', 'petita_workflows_empty').stdout.strip(), '3')


def main():
    try:
        base.start_container()
        base.setup_foundation()
        migration(2)
        migration(3)
        base.sql(f"""
          INSERT INTO petita.profiles(id,role,active,ubs_code) VALUES
            ('{ADMIN_B}','admin',true,NULL),('{TEAM_A2}','ubs_team',true,'TEST-A'),
            ('{INACTIVE_TEAM}','ubs_team',false,'TEST-A');
          INSERT INTO petita_private.identities(issuer,subject,profile_id) VALUES
            ('{base.ISSUER}','admin-b','{ADMIN_B}'),('{base.ISSUER}','team-a2','{TEAM_A2}'),
            ('{base.ISSUER}','inactive-team','{INACTIVE_TEAM}');
          INSERT INTO petita_private.ubs_memberships(profile_id,ubs_code,approved_by,approved_at) VALUES
            ('{TEAM_A2}','TEST-A','{base.ADMIN}',now()),('{INACTIVE_TEAM}','TEST-A','{base.ADMIN}',now());
        """, 'postgres')
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(WorkflowTests))
        return 0 if result.wasSuccessful() else 1
    except subprocess.CalledProcessError as error:
        print('Isolated workflow setup failed:', error.stderr)
        return 1
    finally:
        base.docker('rm', '-f', base.CONTAINER, check=False)


if __name__ == '__main__':
    raise SystemExit(main())
