import test from 'node:test';
import assert from 'node:assert/strict';
import {route,publicError} from '../lib/routes.js';
const id='00000000-0000-4000-8000-000000000010';
const body={idempotency_key:id,ubs_code:'UBS-EV-001',category:'Teste',question_text:'Pergunta fictícia de teste',self_risk_level:'low',warning_signs:[],confirmou_nao_urgencia:true,confirmou_resposta_facultativa:true,confirmou_visibilidade_anonimizada:true,confirmou_ubs_exclusiva:true};
test('catálogo público usa schema canônico',()=>{const r=route('GET','/api/ubs');assert.equal(r.isPublic,true);assert.match(r.sql,/petita\.ubs/);});
test('rotas privadas e funções canônicas',()=>{for(const [path,fn] of [['/api/me','actor_id'],['/api/questions/mine','list_my_patient_questions'],['/api/team/queue','list_team_patient_questions'],['/api/admin/team-requests','list_team_access_requests']]){const r=route('GET',path);assert.equal(r.isPublic,false);assert.ok(r.sql.includes(fn));}});
test('envio parametrizado sem dados interpolados',()=>{const r=route('POST','/api/questions',body);assert.ok(r.sql.includes('petita.submit_patient_question'));assert.equal(r.params[0],id);assert.equal(r.params[3],body.question_text);assert.ok(!r.sql.includes(body.question_text));assert.equal(r.isPublic,false);});
test('alto risco e sinais de alerta bloqueados',()=>{for(const change of [{self_risk_level:'high'},{warning_signs:['alerta']}])assert.throws(()=>route('POST','/api/questions',{...body,...change}),{status:400});});
test('cada aviso é obrigatório',()=>{for(const k of Object.keys(body).filter(k=>k.startsWith('confirmou_')))assert.throws(()=>route('POST','/api/questions',{...body,[k]:false}),{status:400});});
test('não aceita identidade ou papel arbitrários',()=>{for(const k of ['patient_id','role','subject','issuer'])assert.throws(()=>route('POST','/api/questions',{...body,[k]:'forjado'}),{status:400});});
test('identificadores evidentes bloqueados',()=>{assert.throws(()=>route('POST','/api/questions',{...body,question_text:'Teste usuario@example.invalid'}),{status:400});});
test('solicitação, resposta, decisão e revogação usam funções seguras',()=>{for(const [path,b,fn] of [['/api/team/access-request',{ubs_code:'UBS-EV-001',idempotency_key:id},'request_ubs_team_access'],['/api/team/questions/'+id+'/answer',{answer_text:'Resposta fictícia',idempotency_key:id},'respond_to_patient_question'],['/api/admin/team-requests/'+id+'/approve',{},'decide_team_access_request'],['/api/admin/team-members/'+id+'/revoke',{reason:'Teste'},'revoke_ubs_team_access']]){const r=route('POST',path,b);assert.ok(r.sql.includes('petita.'+fn));assert.equal(r.isPublic,false);}});
test('sem rota genérica ou legado',()=>{for(const path of ['/api/sql','/api/admin/overview','/api/patient/ubs-request','/api/team/questions/'+id+'/close'])assert.throws(()=>route('POST',path,{}),{status:404});});
test('não revela erro interno',()=>{assert.deepEqual(publicError({code:'42501',message:'segredo'}),{status:403,message:'Acesso não autorizado.'});assert.equal(publicError(new Error('segredo')).status,503);});

test('cadastro usa identidade autenticada, sem campos de privilégio',()=>{const r=route('POST','/api/profile',{});assert.equal(r.isPublic,false);assert.equal(r.enrollment,true);assert.match(r.sql,/petita\.ensure_patient_profile/);assert.throws(()=>route('POST','/api/profile',{role:'admin'}),{status:400});});

test('consentimento online é distinto e exige todos os aceites',()=>{const b={operation_id:id,terms_version:'2026-10-21-v1',accepted_terms:true,accepted_privacy:true,accepted_responsibility:true,accepted_plan_science:true,accepted_health_data:true,accepted_online_sync:true};const r=route('POST','/api/consent',b);assert.equal(r.actorLock,true);assert.equal(r.params[2],'grant');for(const k of Object.keys(b).filter(k=>k.startsWith('accepted_')))assert.throws(()=>route('POST','/api/consent',{...b,[k]:false}),{status:400});assert.equal(route('POST','/api/consent/withdraw',{operation_id:id,terms_version:'2026-10-21-v1'}).params[2],'withdraw');});
test('sincronização inicial e atualização usam revisão otimista',()=>{const p={id,expected_revision:0,patient_name:'Teste fictício',dpp:'2027-01-01',companion:null,answers:{nome_gestante:['Teste fictício']}};const create=route('POST','/api/plans',p);assert.equal(create.requireRow,true);assert.ok(create.sql.includes('petita_private.actor_id()'));assert.equal(route('POST','/api/plans',{...p,expected_revision:1}).params[5],1);for(const b of [{...p,expected_revision:-1},{...p,patient_id:id},{...p,answers:{unexpected:['x']}},{...p,dpp:'2027-02-31'}])assert.throws(()=>route('POST','/api/plans',b),{status:400});});


test('vinculação da gestante usa funções restritas e nunca aceita identidade ou papel do cliente',()=>{
  const r=route('POST','/api/patient/ubs-requests',{ubs_code:'TEST-A',operation_id:id});
  assert.equal(r.isPublic,false);assert.deepEqual(r.params,['TEST-A',id]);assert.match(r.sql,/petita.request_patient_ubs/);
  for(const field of ['role','patient_id','approved','subject','issuer'])assert.throws(()=>route('POST','/api/patient/ubs-requests',{ubs_code:'TEST-A',operation_id:id,[field]:'forged'}),{status:400});
  for(const [method,path,b,fn] of [
    ['GET','/api/patient/ubs-requests',{},'list_my_ubs_requests'],
    ['GET','/api/admin/patient-ubs-requests',{},'list_patient_ubs_requests'],
    ['POST',`/api/admin/patient-ubs-requests/${id}/approve`,{},'decide_patient_ubs'],
    ['POST',`/api/admin/patient-ubs-members/${id}/revoke`,{reason:'Synthetic revocation'},'revoke_patient_ubs'],
  ]){const op=route(method,path,b);assert.equal(op.isPublic,false);assert.ok(op.sql.includes(fn));}
});

test('educational knowledge is read-only for anonymous clients; publishing is authenticated and parameterized',()=>{
 assert.equal(route('GET','/api/knowledge').isPublic,true);
 assert.equal(route('GET','/api/knowledge/categories').isPublic,true);
 const r=route('POST','/api/admin/knowledge',{category:'Teste',question:'Pergunta sintética',keywords:['teste'],answer:'Resposta sintética para teste'});
 assert.equal(r.isPublic,false);assert.equal(r.params[1],'Pergunta sintética');assert.match(r.sql,/petita\.knowledge_base/);
 assert.equal(route('POST','/api/admin/knowledge/categories',{name:'Teste'}).isPublic,false);
 assert.throws(()=>route('POST','/api/admin/knowledge',{category:'Teste',question:'Pergunta',keywords:[],answer:'Resposta sintética'}),{status:400});
});

test('optional UBS preference is authenticated and actor-scoped',()=>{const get=route('GET','/api/patient/ubs-preference');const post=route('POST','/api/patient/ubs-preference',{});assert.equal(get.isPublic,false);assert.equal(post.isPublic,false);assert.match(post.sql,/actor_id\(\)/);assert.throws(()=>route('POST','/api/patient/ubs-preference',{patient_id:'other'}),{status:400});});

test('professional enrollment has its own route and cannot assign privileged roles',()=>{const r=route('POST','/api/professional/profile',{});assert.equal(r.enrollment,true);assert.match(r.sql,/ensure_professional_profile/);assert.throws(()=>route('POST','/api/professional/profile',{role:'admin'}),{status:400});assert.equal(route('GET','/api/admin/professional-approvals').isPublic,false);});
