import test from 'node:test';
import assert from 'node:assert/strict';
import {webAuthProxy} from '../lib/web-auth-proxy.js';
const env={PETITA_MODE:'homologacao',PETITA_WEB_ORIGIN:'https://web.example',NEON_AUTH_BASE_URL:'https://test.neon.tech/neondb/auth'};
const response=()=>({headers:{},setHeader(k,v){this.headers[k]=v;},status(s){this.code=s;return this;},json(v){this.value=v;return this;}});
const req=(headers={})=>({method:'POST',headers:{origin:env.PETITA_WEB_ORIGIN,...headers}});
test('login returns sanitized identity and host-only first-party cookie',async()=>{
 const res=response();
 await webAuthProxy(req(),res,'login',{email:'test@example.com',password:'not-real'},env,async(u,o)=>{
  assert.equal(u,env.NEON_AUTH_BASE_URL+'/sign-in/email');
  assert.equal(o.redirect,'error');
  return new Response(JSON.stringify({token:'opaque-secret',user:{id:'x',email:'test@example.com',emailVerified:false}}),{headers:{'Set-Cookie':'__Secure-neon-auth.session_token=signedvalue; Domain=neon.tech; Path=/; Max-Age=600'}});
 });
 assert.equal(res.code,200);assert.equal(res.value.data.token,undefined);
 assert.equal(res.headers['Set-Cookie'],'__Secure-petita-session=signedvalue; Path=/petita-auth; Secure; HttpOnly; SameSite=Strict; Max-Age=600');
});
test('token forwards only provider session and returns signed JWT',async()=>{
 const res=response();
 await webAuthProxy(req({cookie:'other=secret; __Secure-petita-session=signedvalue'}),res,'token',{},env,async(u,o)=>{
  assert.equal(o.headers.Cookie,'__Secure-neon-auth.session_token=signedvalue');
  return new Response(JSON.stringify({user:{id:'x'},session:{token:'opaque'}}),{headers:{'set-auth-jwt':'abc.def.ghi'}});
 });
 assert.equal(res.code,200);assert.equal(res.value.data.token,'abc.def.ghi');
});
test('rejects other origins and unrecognized fields',async()=>{
 const fetcher=()=>{throw Error('must not fetch');};
 for(const [r,action,body,status] of [[req({origin:'https://evil.example'}),'session',{},403],[req(),'login',{email:'a',password:'b',callbackURL:'https://evil.example'},400],[req(),'__proto__',{},404],[req(),'token',{},401]]){
  const res=response();await webAuthProxy(r,res,action,body,env,fetcher);assert.equal(res.code,status);
 }
});
test('logout clears local cookie even when upstream fails',async()=>{
 const res=response();await webAuthProxy(req({cookie:'__Secure-petita-session=signedvalue'}),res,'logout',{},env,async()=>{throw Error('network');});
 assert.equal(res.code,503);assert.match(res.headers['Set-Cookie'],/Max-Age=0$/);
});
