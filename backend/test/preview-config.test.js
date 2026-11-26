import test from 'node:test';
import assert from 'node:assert/strict';
import {previewConfig} from '../lib/preview-config.js';
const env={PETITA_MODE:'homologacao',PETITA_AUTH_PREVIEW:'enabled',PETITA_WEB_ORIGIN:'https://preview.example.invalid',NEON_AUTH_BASE_URL:'https://example.neon.tech/neondb/auth'};
test('configuração de teste exige modo, habilitação e host exatos',()=>{assert.deepEqual(previewConfig(env,'preview.example.invalid'),{auth_url:env.NEON_AUTH_BASE_URL});assert.throws(()=>previewConfig({...env,PETITA_MODE:'production'},'preview.example.invalid'),{status:404});assert.throws(()=>previewConfig(env,'other.example.invalid'),{status:403});assert.throws(()=>previewConfig({...env,NEON_AUTH_BASE_URL:'https://other.example.invalid'},'preview.example.invalid'),{status:503});});
