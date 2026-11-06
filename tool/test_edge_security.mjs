// Executes the actual TypeScript handlers. No network, SDK install or real secrets.
// Node 24+: node --experimental-vm-modules --test-isolation=none --test tool/test_edge_security.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { webcrypto } from 'node:crypto';
import vm from 'node:vm';
import { test } from 'node:test';

async function fixture(name, { user = null, profile = null, providerError = false, ragEnabled = true, quota = true, quotaError = false } = {}) {
  const effects = { privileged: [], provider: [], authChecks: 0, quotaChecks: 0, queries: [], logs: [] };
  let handler;
  const env = {
    PETITA_PUBLISHABLE_KEY: 'fixture-public', PETITA_RAG_ENABLED: ragEnabled ? 'true' : 'false', SUPABASE_URL: 'https://fixture.invalid',
    SUPABASE_ANON_KEY: 'fixture-anon', SUPABASE_SERVICE_ROLE_KEY: 'fixture-service',
    CLOUDFLARE_ACCOUNT_ID: 'fixture-account', CLOUDFLARE_API_TOKEN: 'fixture-provider',
  };
  function createClient(_url, key) {
    const privileged = key === env.SUPABASE_SERVICE_ROLE_KEY;
    if (privileged) effects.privileged.push('client');
    return {
      auth: { getUser: async () => {
        effects.authChecks++;
        return { data: { user }, error: user ? null : { message: 'fixture rejected' } };
      } },
      rpc: async (name) => {
        if (name === 'consume_petita_rag_quota') {
          effects.quotaChecks++;
          return { data: quota, error: quotaError ? { message: 'fixture quota failure' } : null };
        }
        return { data: [], error: null };
      },
      from(table) {
        const query = { table, privileged, select: null, filters: [] };
        effects.queries.push(query);
        const builder = {
          select(columns) { query.select = columns; return builder; },
          eq(column, value) { query.filters.push([column, value]); return builder; },
          maybeSingle: async () => ({ data: profile }),
          single: async () => ({ data: { id: 'fixture-doc', status: 'available', file_path: 'fixture/doc.pdf' }, error: null }),
          update() { if (privileged) effects.privileged.push('update'); return builder; },
          delete() { if (privileged) effects.privileged.push('delete'); return builder; },
          insert(row) { effects.logs.push(row); return Promise.resolve({ error: null }); },
          then(resolve, reject) { return Promise.resolve({ error: null }).then(resolve, reject); },
        };
        return builder;
      },
      storage: { from: () => ({ remove: async () => {
        effects.privileged.push('remove'); return { error: null };
      } }) },
    };
  }
  const context = vm.createContext({
    Request, Response, Headers, URL, TextEncoder, AbortSignal, crypto: webcrypto,
    Deno: { env: { get: key => env[key] }, serve: fn => { handler = fn; } },
    // The fixture document is already available: background function returns immediately.
    EdgeRuntime: { waitUntil() {} },
    fetch: async (url, options) => {
      effects.provider.push({ url, body: JSON.parse(options.body) });
      if (providerError) throw new Error('fixture-internal-diagnostic');
      return Response.json({ data: [{ embedding: [0.1, 0.2] }] });
    },
  });
  const path = new URL(`../supabase/functions/${name}/index.ts`, import.meta.url);
  const source = stripTypeScriptTypes(readFileSync(path, 'utf8'));
  const mod = new vm.SourceTextModule(source, { context, identifier: path.href });
  await mod.link(specifier => {
    assert.equal(specifier, 'npm:@supabase/supabase-js@2');
    return new vm.SyntheticModule(['createClient'], function () {
      this.setExport('createClient', createClient);
    }, { context });
  });
  await mod.evaluate();
  // Only the auth/dispatch boundary is exercised, not parsing or embedding jobs.
  const dispatch = async (body, headers = {}) => handler(new Request('https://fixture.invalid/function', {
    method: 'POST', headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  }));
  return { effects, dispatch };
}

test('RAG rejects missing/wrong application key before privileged/provider work', async () => {
  for (const key of ['', 'wrong-fixture']) {
    const f = await fixture('ask-petita-rag');
    assert.equal((await f.dispatch({ question: 'Duvida sintetica' }, { apikey: key })).status, 401);
    assert.equal(f.effects.privileged.length + f.effects.provider.length, 0);
  }
});

test('public key alone never reaches provider without user session', async () => {
  const f = await fixture('ask-petita-rag');
  for (let i = 0; i < 3; i++) {
    assert.equal((await f.dispatch({ question: 'Duvida sintetica' }, { apikey: 'fixture-public' })).status, 401);
  }
  assert.equal(f.effects.provider.length, 0);
  assert.equal(f.effects.logs.length, 0);
});

const ragUser = { user: { id: 'fixture-patient' }, profile: { role: 'patient', active: true } };
const ragHeaders = { apikey: 'fixture-public', authorization: 'Bearer fixture-session' };
for (const [label, options, expected] of [
  ['disabled by default', { ragEnabled: false }, 503],
  ['invalid session', {}, 401],
  ['inactive profile', { user: ragUser.user, profile: { role: 'patient', active: false } }, 403],
  ['quota exhausted', { ...ragUser, quota: false }, 429],
  ['quota unavailable', { ...ragUser, quotaError: true }, 503],
  ['malformed quota result', { ...ragUser, quota: [] }, 503],
]) {
  test(`RAG fail-closed: ${label} has no provider side effects`, async () => {
    const f = await fixture('ask-petita-rag', options);
    const response = await f.dispatch({ question: 'Duvida sintetica' }, ragHeaders);
    assert.equal(response.status, expected);
    assert.equal(f.effects.provider.length, 0);
  });
}

test('RAG checks server identity and persistent quota before provider work', async () => {
  const f = await fixture('ask-petita-rag', ragUser);
  assert.equal((await f.dispatch({ question: 'Duvida sintetica' }, ragHeaders)).status, 200);
  assert.equal(f.effects.authChecks, 1);
  assert.equal(f.effects.quotaChecks, 1);
  assert.equal(f.effects.provider.length, 1);
  assert.ok(f.effects.logs.every(row => !Object.hasOwn(row, 'question')));
});

test('RAG length guard prevents provider work on oversized question', async () => {
  const f = await fixture('ask-petita-rag', ragUser);
  await f.dispatch({ question: 'x'.repeat(1501) }, ragHeaders);
  assert.equal(f.effects.provider.length, 0);
});

test('RAG returns generic public error without provider diagnostics', async () => {
  const f = await fixture('ask-petita-rag', { ...ragUser, providerError: true });
  const response = await f.dispatch({ question: 'Duvida sintetica' }, ragHeaders);
  assert.equal(response.status, 503);
  assert.doesNotMatch(JSON.stringify(await response.json()), /fixture-internal-diagnostic/);
});

for (const name of ['delete-support-document', 'process-support-document']) {
  for (const [label, user, profile, expected] of [
    ['missing session', null, null, 401],
    ['patient', { id: 'fixture-patient-a' }, { role: 'patient', active: true }, 403],
    ['team A', { id: 'fixture-team-a' }, { role: 'ubs_team', active: true }, 403],
    ['team B', { id: 'fixture-team-b' }, { role: 'ubs_team', active: true }, 403],
    ['inactive admin', { id: 'fixture-admin' }, { role: 'admin', active: false }, 403],
    ['admin without active flag', { id: 'fixture-admin' }, { role: 'admin' }, 403],
    ['admin with null active flag', { id: 'fixture-admin' }, { role: 'admin', active: null }, 403],
    ['forged metadata admin', { id: 'fixture-patient', user_metadata: { role: 'admin' } }, { role: 'patient', active: true }, 403],
  ]) {
    test(`${name}: ${label} denied before privileged effects`, async () => {
      const f = await fixture(name, { user, profile });
      const response = await f.dispatch({ document_id: 'fixture-doc', phase: 'embed' });
      assert.equal(response.status, expected);
      assert.equal(f.effects.privileged.length, 0);
    });
  }
  test(`${name}: active admin is checked against server profile ID`, async () => {
    const f = await fixture(name, { user: { id: 'fixture-admin' }, profile: { role: 'admin', active: true } });
    // Missing ID stops before jobs/deletion; identity/profile must still be resolved.
    assert.equal((await f.dispatch({})).status, 400);
    const query = f.effects.queries.find(q => q.table === 'profiles');
    assert.deepEqual(query.filters, [['id', 'fixture-admin']]);
    assert.equal(f.effects.authChecks, 1);
  });
  test(`${name}: active admin can dispatch operation`, async () => {
    const f = await fixture(name, { user: { id: 'fixture-admin' }, profile: { role: 'admin', active: true } });
    const response = await f.dispatch({ document_id: 'fixture-doc', phase: 'embed' });
    assert.equal(response.status, name === 'delete-support-document' ? 200 : 202);
    assert.ok(f.effects.privileged.length > 0);
  });
}
