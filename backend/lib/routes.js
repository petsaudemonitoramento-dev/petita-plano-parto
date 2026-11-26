// HTTP contract for the canonical petita/petita_private migrations 001–003.
export function problem(status, message) { return Object.assign(new Error(message), { status }); }
const invalid = () => { throw problem(400, 'Dados inválidos. Revise os campos.'); };
const text = (v, min, max) => { if (typeof v !== 'string' || v.trim().length < min || v.trim().length > max) invalid(); return v.trim(); };
const uuid = v => { if (typeof v !== 'string' || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(v)) invalid(); return v; };
const noBody = b => { if (b && Object.keys(b).length) invalid(); };
const only = (b, keys) => { if (!b || Array.isArray(b) || typeof b !== 'object' || Object.keys(b).some(k=>!keys.includes(k))) invalid(); };
const q = (sql, params = [], isPublic = false) => ({sql, params, isPublic});
export function route(method, path, body = {}) {
  if (method === 'GET' && path === '/api/ubs') { noBody(body); return q('select code,name,city,state from petita.ubs where active order by name', [], true); }
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
