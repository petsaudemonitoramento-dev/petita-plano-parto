// Live smoke test for the isolated homologation only. Never prints credentials or tokens.
import assert from 'node:assert/strict';
import { randomUUID, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
const cfg=JSON.parse(readFileSync(new URL('../config/homologacao.json',import.meta.url)));
const api=cfg.PETITA_API_ORIGIN,auth=cfg.PETITA_AUTH_URL;
const origin='https://petita-flutter-web-homologacao.vercel.app';
assert.equal(api,'https://petita-api-neon-homologacao-petsaudemonitoramento-devs-projects.vercel.app');
assert.equal(auth,'https://ep-calm-night-b61u6bdb.neonauth.c-2.sa-east-1.aws.neon.tech/neondb/auth');
async function req(base,path,method='GET',body,token,requestOrigin=origin,expected=200){
  const headers={'Accept':'application/json','Origin':requestOrigin};
  if(token)headers.Authorization='Bearer '+token;
  if(body!==undefined)headers['Content-Type']='application/json';
  const r=await fetch(base+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),redirect:'manual',signal:AbortSignal.timeout(15000)});
  const raw=await r.text();
  let json;try{json=JSON.parse(raw);}catch{json=null;}
  if(r.status!==expected)throw Error(method+' '+path+' expected '+expected+' got '+r.status+' code '+(typeof json?.code==='string'&&/^[A-Z_]+$/.test(json.code)?json.code:'unknown'));
  if(expected===200&&!json)throw Error(path+' expected JSON');
  if(base===api&&expected===200)assert.equal(r.headers.get('access-control-allow-origin'),origin,'CORS');
  console.log('PASS',method,path,r.status);
  return {json,jwt:r.headers.get('set-auth-jwt')};
}
const run=async()=>{
  await req(api,'/api/health');
  const units=await req(api,'/api/ubs');
  assert.equal(units.json.data.length,3);
  await req(api,'/api/me','GET',undefined,undefined,origin,401);
  const cors=await fetch(api+'/api/profile',{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'authorization,content-type'},redirect:'manual',signal:AbortSignal.timeout(15000)});
  assert.equal(cors.status,204);assert.equal(cors.headers.get('access-control-allow-origin'),origin);
  await req(api,'/api/ubs','GET',undefined,undefined,'https://untrusted.example.invalid',403);
  async function account(){
    const email='petita-smoke-'+randomUUID()+'@example.com', password='Test!'+randomBytes(24).toString('hex');
    const data={name:'SYNTHETIC HOMOLOGATION',email,password};
    await req(auth,'/sign-up/email','POST',data,undefined,api);
    const login=await req(auth,'/sign-in/email','POST',{email,password},undefined,api);
    assert.ok(typeof login.json.token==='string'&&login.json.token.length>0,'native credential missing');
    const credential=login.json.token;
    const session=await req(auth,'/get-session','GET',undefined,credential,api);
    assert.equal(session.json.user?.emailVerified,false);
    const candidate=session.jwt??session.json.session?.token;
    const jwt=typeof candidate==='string'&&candidate.split('.').length===3?candidate:(await req(auth,'/token','GET',undefined,credential,api)).json.token;
    assert.ok(typeof jwt==='string'&&jwt.split('.').length===3,'JWT unavailable');
    await req(api,'/api/profile','POST',{},jwt);
    const profile=(await req(api,'/api/me','GET',undefined,jwt)).json.data[0];
    assert.equal(profile.role,'patient');
    return {jwt,credential,profile};
  }
  const first=await account(),second=await account();
  assert.notEqual(first.profile.id,second.profile.id);
  const consent={operation_id:randomUUID(),terms_version:'2026-10-21-v1',accepted_terms:true,accepted_privacy:true,accepted_responsibility:true,accepted_plan_science:true,accepted_health_data:true,accepted_online_sync:true};
  await req(api,'/api/consent','POST',consent,first.jwt);
  const plan={id:randomUUID(),expected_revision:0,patient_name:'SYNTHETIC',answers:{nome_gestante:['SYNTHETIC']}};
  await req(api,'/api/plans','POST',plan,first.jwt);
  const own=(await req(api,'/api/plans','GET',undefined,first.jwt)).json.data;
  const other=(await req(api,'/api/plans','GET',undefined,second.jwt)).json.data;
  assert.ok(own.some(p=>p.id===plan.id));assert.ok(!other.some(p=>p.id===plan.id));
  await req(api,'/api/admin/team-requests','GET',undefined,first.jwt,origin,403);
  await req(auth,'/sign-out','POST',{},first.credential,api);
  await req(auth,'/sign-out','POST',{},second.credential,api);
  console.log('PASS isolation and logout; synthetic records retained in homologation.');
};
run().catch(e=>{console.error('SMOKE_FAILED:',e instanceof Error?e.message:'unknown');process.exitCode=1;});
