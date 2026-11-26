import test from 'node:test';
import assert from 'node:assert/strict';
import {authOrigin,verifiedIdentity} from '../lib/auth.js';
const origin='https://auth.example.invalid';
const claims={iss:origin,aud:origin,sub:'synthetic-user',emailVerified:true,banned:false,role:'admin'};
test('issuer e audience são origem, não caminho',()=>{assert.equal(authOrigin(origin+'/neondb/auth'),origin);assert.deepEqual(verifiedIdentity(claims,origin),{issuer:origin,subject:'synthetic-user'});});
test('rejeita token com emissor, público, email ou bloqueio inválido',()=>{for(const changes of [{iss:origin+'/neondb/auth'},{aud:'https://other.invalid'},{emailVerified:false},{banned:true},{sub:''}])assert.throws(()=>verifiedIdentity({...claims,...changes},origin),{status:401});});
test('não aceita HTTP',()=>{assert.throws(()=>authOrigin('http://auth.example.invalid'),{status:503});});
