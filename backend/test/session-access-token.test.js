import test from 'node:test';
import assert from 'node:assert/strict';
import {sessionAccessToken} from '../src/session-access-token.js';
const jwt='fixture.header.signature';
test('uses SDK session JWT without calling token endpoint', async()=>{
  const result=await sessionAccessToken({getSession:async()=>({data:{user:{id:'a'},session:{token:jwt}}}),token:async()=>{throw Error('must not call');}});
  assert.equal(result.data.token,jwt);
});
test('does not leak opaque session credential; uses JWT endpoint instead',async()=>{
  const result=await sessionAccessToken({getSession:async()=>({data:{user:{id:'a'},session:{token:'opaque'}}}),token:async()=>({data:{token:jwt}})});
  assert.equal(result.data.token,jwt);
});
test('fails closed without authenticated user or valid JWT',async()=>{
  assert.equal((await sessionAccessToken({getSession:async()=>({data:null}),token:async()=>{throw Error('must not call');}})).error.status,401);
  assert.equal((await sessionAccessToken({getSession:async()=>({data:{user:{id:'a'},session:{token:'opaque'}}}),token:async()=>({data:{token:'opaque'}})})).error.status,503);
});
test('preserves provider error',async()=>{
  assert.equal((await sessionAccessToken({getSession:async()=>({error:{status:429}})})).error.status,429);
});
