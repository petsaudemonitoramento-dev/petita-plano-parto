import test from 'node:test';
import assert from 'node:assert/strict';
import {authOrigin,verifiedIdentity} from '../lib/auth.js';
const origin='https://auth.example.invalid';
const claims={iss:origin,aud:origin,sub:'synthetic-user',emailVerified:true,banned:false,role:'admin'};
test('issuer e audience são origem, não caminho',()=>{assert.equal(authOrigin(origin+'/neondb/auth'),origin);assert.deepEqual(verifiedIdentity(claims,origin),{issuer:origin,subject:'synthetic-user'});});
test('rejeita token com emissor, público, email ou bloqueio inválido',()=>{for(const changes of [{iss:origin+'/neondb/auth'},{aud:'https://other.invalid'},{emailVerified:false},{banned:true},{sub:''}])assert.throws(()=>verifiedIdentity({...claims,...changes},origin),{status:401});});
test('não aceita HTTP',()=>{assert.throws(()=>authOrigin('http://auth.example.invalid'),{status:503});});


import {generateKeyPair,SignJWT} from 'jose';
import {verifyAccessToken} from '../lib/auth.js';
test('criptografia JWT real: assinatura válida, expiração, público, emissor e chave forjada',async()=>{
 const key=await generateKeyPair('EdDSA'),other=await generateKeyPair('EdDSA');
 const now=Math.floor(Date.now()/1000);
 const sign=(changes={},privateKey=key.privateKey)=>new SignJWT({...claims,iat:now,exp:now+300,...changes}).setProtectedHeader({alg:'EdDSA'}).sign(privateKey);
 assert.deepEqual(await verifyAccessToken(await sign(),key.publicKey,origin),{issuer:origin,subject:'synthetic-user'});
 for(const change of [{exp:now-60},{iat:now-1800},{aud:'wrong'},{iss:'https://wrong.invalid'},{emailVerified:false},{banned:true}])await assert.rejects(verifyAccessToken(await sign(change),key.publicKey,origin),{status:401});
 await assert.rejects(verifyAccessToken(await sign({},other.privateKey),key.publicKey,origin),{status:401});
});
