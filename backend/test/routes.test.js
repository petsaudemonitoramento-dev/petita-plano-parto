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
