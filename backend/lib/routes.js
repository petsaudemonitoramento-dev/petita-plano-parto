// HTTP contract for the canonical petita/petita_private migrations 001–003.
export function problem(status, message) { return Object.assign(new Error(message), { status }); }
const invalid = () => { throw problem(400, 'Dados inválidos. Revise os campos.'); };
const text = (v, min, max) => { if (typeof v !== 'string' || v.trim().length < min || v.trim().length > max) invalid(); return v.trim(); };
const uuid = v => { if (typeof v !== 'string' || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(v)) invalid(); return v; };
const noBody = b => { if (b && Object.keys(b).length) invalid(); };
const only = (b, keys) => { if (!b || Array.isArray(b) || typeof b !== 'object' || Object.keys(b).some(k=>!keys.includes(k))) invalid(); };
const q = (sql, params = [], isPublic = false) => ({sql, params, isPublic});
const consentVersion='2026-10-21-v1';
const allowedAnswers=new Set(["nome_gestante","dpp","semanas_gestacao","ubs_referencia","cenario_parto","prioridade_parto","acompanhante_principal","doula","apoio_comunicacao","acompanhamento_continuo","comunicacao_equipe","movimentacao","posicao_contracoes","alimentacao","ambiente","informacao_procedimentos","alivio_dor","posicao_nascimento","episiotomia","toque_vaginal","kristeller","cordao_umbilical","bebe_primeira_hora","cuidados_nao_urgentes","alojamento_conjunto","orientacoes_posparto","cesarea","privacidade","registros_fotograficos","preferencias_culturais","observacoes_finais"]);
function answers(v) {
  if (!v || typeof v!=='object' || Array.isArray(v) || Object.keys(v).some(k=>!allowedAnswers.has(k))) invalid();
  for (const values of Object.values(v)) {
    if(!Array.isArray(values)||values.length>30||values.some(x=>typeof x!=='string'||x.length>1500)) invalid();
  }
  if(Buffer.byteLength(JSON.stringify(v))>12000) invalid();
  return JSON.stringify(v);
}
const nullableText=(v,max)=>v==null?null:text(v,1,max);
function isoDate(v) {
  if(v==null) return null;
  if(typeof v!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v)) invalid();
  const d=new Date(v+'T00:00:00Z');
  if(Number.isNaN(d.getTime())||d.toISOString().slice(0,10)!==v) invalid();
  return v;
}
export function route(method, path, body = {}) {
  if (method==='GET' && path==='/api/consent') { noBody(body); return q('select terms_version,action,created_at from petita.sync_consent_events order by id desc limit 1'); }
  if (method==='POST' && (path==='/api/consent' || path==='/api/consent/withdraw')) {
    const grant=path==='/api/consent';
    const flags=['accepted_terms','accepted_privacy','accepted_responsibility','accepted_plan_science','accepted_health_data','accepted_online_sync'];
    only(body,grant?['operation_id','terms_version',...flags]:['operation_id','terms_version']);
    if(body.terms_version!==consentVersion || (grant && flags.some(k=>body[k]!==true))) invalid();
    return {...q("insert into petita.sync_consent_events(patient_id,terms_version,operation_id,action) values(petita_private.actor_id(),$1,$2::uuid,$3) on conflict(patient_id,operation_id) do nothing returning terms_version,action,created_at",[consentVersion,uuid(body.operation_id),grant?'grant':'withdraw']), requireRow:true, actorLock:true};
  }
  if (method==='GET' && path==='/api/plans') {
    noBody(body); return q('select id,patient_name,dpp,companion,answers_json,revision,updated_at from petita.birth_plans order by updated_at desc limit 25');
  }
  if (method==='POST' && path==='/api/plans') {
    only(body,['id','expected_revision','patient_name','dpp','companion','answers']);
    const rev=body.expected_revision;
    if(!Number.isInteger(rev)||rev<0||rev>2147483646) invalid();
    const params=[uuid(body.id),nullableText(body.patient_name,240),isoDate(body.dpp),nullableText(body.companion,240),answers(body.answers)];
    if(rev===0) return {...q('insert into petita.birth_plans(id,patient_id,ubs_code,patient_name,dpp,companion,answers_json) values($1::uuid,petita_private.actor_id(),petita_private.actor_ubs(),$2,$3::date,$4,$5::jsonb) on conflict(id) do nothing returning id,revision,updated_at',params), requireRow:true, actorLock:true};
    return {...q('update petita.birth_plans set patient_name=$2,dpp=$3::date,companion=$4,answers_json=$5::jsonb,ubs_code=petita_private.actor_ubs(),revision=revision+1 where id=$1::uuid and revision=$6 returning id,revision,updated_at',[...params,rev]),requireRow:true,actorLock:true};
  }
  if (method === 'GET' && path === '/api/ubs') { noBody(body); return q('select code,name,city,state from petita.ubs where active order by name', [], true); }
  if (method === 'POST' && path === '/api/profile') { noBody(body); return {...q('select petita.ensure_patient_profile() as id'), enrollment:true}; }
  if (method === 'GET' && path === '/api/me') { noBody(body); return q('select id,display_name,role,ubs_code from petita.profiles where id=petita_private.actor_id()'); }
  if (method === 'GET' && path === '/api/questions/mine') { noBody(body); return q('select * from petita.list_my_patient_questions(50,null,null)'); }
  if (method === 'GET' && path === '/api/team/queue') { noBody(body); return q('select * from petita.list_team_patient_questions(50,null,null)'); }
  if (method === 'GET' && path === '/api/admin/team-requests') { noBody(body); return q('select * from petita.list_team_access_requests(50)'); }
  if (method === 'POST' && path === '/api/questions') {
    only(body,['idempotency_key','ubs_code','category','question_text','self_risk_level','warning_signs','confirmou_nao_urgencia','confirmou_resposta_facultativa','confirmou_visibilidade_anonimizada','confirmou_ubs_exclusiva']);
    const message=text(body.question_text,5,1500);
    const category=text(body.category,2,80);
    if (!['low','medium'].includes(body.self_risk_level) || !Array.isArray(body.warning_signs) || body.warning_signs.length !== 0)
      throw problem(400,'Canal não urgente. Procure atendimento presencial se houver sinais de alerta.');
    if (['confirmou_nao_urgencia','confirmou_resposta_facultativa','confirmou_visibilidade_anonimizada','confirmou_ubs_exclusiva'].some(k=>body[k]!==true)) invalid();
    if (/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(message) || /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/.test(message))
      throw problem(400,'Remova identificadores pessoais da mensagem.');
    return q('select petita.submit_patient_question($1::uuid,$2,$3,$4,$5,$6::text[],$7,$8) as result',[uuid(body.idempotency_key),text(body.ubs_code,1,80),category,message,body.self_risk_level,[],false,true]);
  }
  if (method==='POST' && path==='/api/team/access-request') {
    only(body,['ubs_code','idempotency_key']);
    return q('select petita.request_ubs_team_access($1,$2::uuid) as result',[text(body.ubs_code,1,80),uuid(body.idempotency_key)]);
  }
  let m=path.match(/^\/api\/team\/questions\/([^/]+)\/answer$/);
  if(method==='POST' && m) {
    only(body,['answer_text','idempotency_key']);
    return q('select petita.respond_to_patient_question($1::uuid,$2,$3::uuid) as result',[uuid(m[1]),text(body.answer_text,3,6000),uuid(body.idempotency_key)]);
  }
  m=path.match(/^\/api\/admin\/team-requests\/([^/]+)\/(approve|reject)$/);
  if(method==='POST' && m) { noBody(body); return q('select petita.decide_team_access_request($1::uuid,$2::boolean) as result',[uuid(m[1]),m[2]==='approve']); }
  m=path.match(/^\/api\/admin\/team-members\/([^/]+)\/revoke$/);
  if(method==='POST' && m) { only(body,['reason']); return q('select petita.revoke_ubs_team_access($1::uuid,$2) as result',[uuid(m[1]),text(body.reason,3,1000)]); }
  // No generic SQL endpoint, no fallback to legacy schema, no privilege elevation.
  throw problem(404,'Rota indisponível nesta homologação.');
}
export function publicError(err) {
  const status = [400,401,403,404,405,409,413,415,503].includes(err.status) ? err.status : ({'42501':403,'22023':400,'23505':409,'P0001':409}[err.code] || 503);
  return {status, message: ({400:'Dados inválidos.',401:'Autenticação necessária.',403:'Acesso não autorizado.',404:'Rota indisponível.',405:'Método não permitido.',409:'Conflito na operação.',413:'Requisição muito grande.',415:'Formato não aceito.',503:'Serviço indisponível.'})[status]};
}
