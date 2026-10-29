import { randomUUID } from 'node:crypto';
import { neon } from '@neondatabase/serverless';
import { identify } from '../lib/auth.js';
import { forbid, requireRole, requireOwnUbs, validateQuestion } from '../lib/policy.js';

// Deploy isolado (root directory "backend" na Vercel), nao no site de download.
function send(res, status, payload) {
  res.status(status).setHeader('Cache-Control', 'no-store');
  return res.json(payload);
}
function bad(message, status = 400) {
  throw Object.assign(new Error(message), { status });
}
function readBody(req) {
  const b = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body;
  if (!b || typeof b !== 'object' || Array.isArray(b)) bad('JSON invalido');
  return b;
}
async function account(sql, user) {
  // O JWT verificado e a unica fonte do ID. Nunca usar usuario_id da requisicao.
  await sql`INSERT INTO petita_atendimento.acessos(usuario_id,papel)
    VALUES (${user},'gestante') ON CONFLICT(usuario_id) DO NOTHING`;
  const rows = await sql`SELECT usuario_id,papel,ativo FROM petita_atendimento.acessos
    WHERE usuario_id=${user} LIMIT 1`;
  if (!rows[0]?.ativo) forbid('Conta bloqueada');
  return rows[0];
}
async function patientUbs(sql, user) {
  const rows = await sql`SELECT ubs_codigo FROM petita_privado.vinculos_gestantes
    WHERE usuario_id=${user} LIMIT 1`;
  return rows[0]?.ubs_codigo ?? null;
}
async function teamUbs(sql, user) {
  const rows = await sql`SELECT ubs_codigo, ativo FROM petita_atendimento.vinculos_equipes
    WHERE usuario_id=${user} LIMIT 1`;
  return rows[0] ?? null;
}
function match(path, pattern) {
  return path.match(pattern);
}

export default async function handler(req, res) {
  const path = new URL(req.url || '/', 'https://petita.local').pathname.replace(/\/$/, '');
  const method = (req.method || 'GET').toUpperCase();
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  const origin = process.env.PETITA_WEB_ORIGIN;
  if (origin && req.headers.origin === origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  }
  if (method === 'OPTIONS') return send(res, 204, {});
  if (method === 'GET' && path === '/api/health') return send(res, 200, { status: 'ok', mode: 'homologacao' });
  try {
    if (!process.env.DATABASE_URL) bad('Servico indisponivel', 503);
    const sql = neon(process.env.DATABASE_URL);
    if (method === 'GET' && path === '/api/ubs') {
      const rows = await sql`SELECT code,name FROM public.ubs WHERE active IS TRUE ORDER BY name`;
      return send(res, 200, { unidades: rows });
    }

    const user = await identify(req);
    const me = await account(sql, user);

    if (method === 'GET' && path === '/api/me') {
      const ubs = me.papel === 'gestante' ? await patientUbs(sql, user)
        : me.papel === 'equipe_ubs' ? (await teamUbs(sql, user))?.ubs_codigo : null;
      return send(res, 200, { papel: me.papel, ubs_codigo: ubs, ubs_confirmada: !!ubs });
    }

    if (method === 'POST' && path === '/api/patient/ubs-request') {
      requireRole(me, 'gestante');
      if (await patientUbs(sql, user)) bad('UBS ja confirmada; contate a administracao para correcao', 409);
      const b = readBody(req);
      const code = String(b.ubs_codigo || '');
      const rows = await sql`INSERT INTO petita_privado.solicitacoes_vinculo_gestantes
        (usuario_id,ubs_codigo)
        SELECT ${user},code FROM public.ubs WHERE code=${code} AND active IS TRUE
        ON CONFLICT DO NOTHING RETURNING id`;
      if (!rows.length) bad('UBS invalida ou solicitacao pendente', 409);
      return send(res, 201, { status: 'pendente', solicitacao_id: rows[0].id });
    }

    if (method === 'POST' && path === '/api/questions') {
      requireRole(me, 'gestante');
      const ubs = await patientUbs(sql, user);
      if (!ubs) forbid('Aguarde a confirmacao de sua UBS antes de enviar');
      const b = readBody(req);
      const q = validateQuestion(b);
      const id = randomUUID();
      const [created] = await sql.transaction([
        sql`INSERT INTO petita_atendimento.duvidas
          (id,ubs_codigo,categoria,texto,nivel_percebido,sinais_alerta,
           versao_termo,confirmou_nao_urgencia,confirmou_resposta_facultativa,
           confirmou_visibilidade_anonimizada,confirmou_ubs_exclusiva)
          VALUES (${id},${ubs},${q.category},${q.text},${q.risk},
           ARRAY[]::text[],${q.version},true,true,true,true)
          RETURNING id,codigo_publico,situacao`,
        sql`INSERT INTO petita_privado.autoria_duvidas(duvida_id,gestante_usuario_id)
          VALUES (${id},${user})`,
      ]);
      return send(res, 201, { duvida: created[0] });
    }

    if (method === 'GET' && path === '/api/questions/mine') {
      requireRole(me, 'gestante');
      const rows = await sql`SELECT d.id,d.codigo_publico,d.categoria,d.texto,
        d.ubs_codigo,d.situacao,d.criada_em,r.texto AS resposta,r.respondida_em
        FROM petita_privado.autoria_duvidas a
        JOIN petita_atendimento.duvidas d ON d.id=a.duvida_id
        LEFT JOIN petita_atendimento.respostas r ON r.duvida_id=d.id
        WHERE a.gestante_usuario_id=${user}
        ORDER BY d.criada_em DESC LIMIT 100`;
      return send(res, 200, { duvidas: rows });
    }

    if (method === 'POST' && path === '/api/team/access-request') {
      requireRole(me, 'gestante');
      const code = String(readBody(req).ubs_codigo ?? '');
      const rows = await sql`INSERT INTO petita_atendimento.solicitacoes_acesso
        (usuario_id,ubs_codigo)
        SELECT ${user},code FROM public.ubs WHERE code=${code} AND active IS TRUE
        ON CONFLICT DO NOTHING RETURNING id`;
      if (!rows.length) bad('UBS invalida ou solicitacao pendente', 409);
      return send(res, 201, { status: 'pendente', solicitacao_id: rows[0].id });
    }

    if (method === 'GET' && path === '/api/team/queue') {
      const ubs = requireOwnUbs(me, await teamUbs(sql, user));
      // Nao consultar petita_privado nem devolver identificadores das autoras.
      const rows = await sql`SELECT id,codigo_publico,ubs_codigo,categoria,texto,
        nivel_percebido,situacao,criada_em
        FROM petita_atendimento.fila_anonima
        WHERE ubs_codigo=${ubs} ORDER BY criada_em DESC LIMIT 100`;
      return send(res, 200, { ubs_codigo: ubs, duvidas: rows });
    }

    const answerMatch = match(path, /^\/api\/team\/questions\/([0-9a-f-]{36})\/answer$/i);
    if (method === 'POST' && answerMatch) {
      const ubs = requireOwnUbs(me, await teamUbs(sql, user));
      const id = answerMatch[1];
      const body = readBody(req);
      const text = String(body.texto ?? '').trim();
      if (text.length < 3 || text.length > 4000) bad('Resposta de tamanho invalido');
      const rows = await sql`WITH changed AS (
        UPDATE petita_atendimento.duvidas SET situacao='respondida',atualizada_em=now()
        WHERE id=${id} AND ubs_codigo=${ubs} AND situacao='pendente'
        RETURNING id
      ), response AS (
        INSERT INTO petita_atendimento.respostas(duvida_id,texto,respondida_por)
        SELECT id,${text},${user} FROM changed RETURNING duvida_id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'duvida_respondida',duvida_id FROM response
      )
      SELECT duvida_id FROM response`;
      if (!rows.length) bad('Duvida indisponivel ou de outra UBS', 409);
      return send(res, 200, { situacao: 'respondida' });
    }

    const closeMatch = match(path, /^\/api\/team\/questions\/([0-9a-f-]{36})\/close$/i);
    if (method === 'POST' && closeMatch) {
      const ubs = requireOwnUbs(me, await teamUbs(sql, user));
      const rows = await sql`WITH changed AS (
        UPDATE petita_atendimento.duvidas
        SET situacao='encerrada_sem_resposta',atualizada_em=now()
        WHERE id=${closeMatch[1]} AND ubs_codigo=${ubs} AND situacao='pendente'
        RETURNING id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'duvida_encerrada',id FROM changed
      ) SELECT id FROM changed`;
      if (!rows.length) bad('Duvida indisponivel ou de outra UBS', 409);
      return send(res, 200, { situacao: 'encerrada_sem_resposta' });
    }

    if (path.startsWith('/api/admin/')) requireRole(me, 'administrador');

    if (method === 'GET' && path === '/api/admin/requests') {
      const teams = await sql`SELECT id,usuario_id,ubs_codigo,justificativa,
        situacao,solicitado_em FROM petita_atendimento.solicitacoes_acesso
        WHERE situacao='pendente' ORDER BY solicitado_em ASC LIMIT 100`;
      const patients = await sql`SELECT id,usuario_id,ubs_codigo,situacao,
        solicitado_em FROM petita_privado.solicitacoes_vinculo_gestantes
        WHERE situacao='pendente' ORDER BY solicitado_em ASC LIMIT 100`;
      return send(res, 200, { equipes: teams, vinculos_gestantes: patients });
    }

    const teamApprove = match(path, /^\/api\/admin\/team-requests\/([0-9a-f-]{36})\/approve$/i);
    if (method === 'POST' && teamApprove) {
      const rows = await sql`WITH candidate AS (
        SELECT r.id,r.usuario_id,r.ubs_codigo
        FROM petita_atendimento.solicitacoes_acesso r
        JOIN petita_atendimento.acessos a ON a.usuario_id=r.usuario_id
        WHERE r.id=${teamApprove[1]} AND r.situacao='pendente'
          AND a.papel='gestante' AND a.ativo IS TRUE
      ), promoted AS (
        UPDATE petita_atendimento.acessos SET papel='equipe_ubs',atualizado_em=now()
        WHERE usuario_id IN (SELECT usuario_id FROM candidate)
        RETURNING usuario_id
      ), granted AS (
        INSERT INTO petita_atendimento.vinculos_equipes
          (usuario_id,ubs_codigo,autorizado_por,ativo)
        SELECT p.usuario_id,c.ubs_codigo,${user},true
        FROM candidate c JOIN promoted p USING (usuario_id)
        ON CONFLICT(usuario_id) DO UPDATE SET
          ubs_codigo=excluded.ubs_codigo,autorizado_por=excluded.autorizado_por,
          autorizado_em=now(),ativo=true RETURNING usuario_id
      ), finalized AS (
        UPDATE petita_atendimento.solicitacoes_acesso
        SET situacao='aprovada',decidido_por=${user},decidido_em=now()
        WHERE id IN (SELECT id FROM candidate)
          AND usuario_id IN (SELECT usuario_id FROM granted)
        RETURNING id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'solicitacao_aprovada',id FROM finalized
      )
      SELECT id FROM finalized`;
      if (!rows.length) bad('Solicitacao nao autorizada ou ja decidida', 409);
      return send(res, 200, { situacao: 'aprovada' });
    }

    const patientApprove = match(path, /^\/api\/admin\/patient-ubs-requests\/([0-9a-f-]{36})\/approve$/i);
    if (method === 'POST' && patientApprove) {
      // Admin deve confirmar o vinculo com a UBS por procedimento institucional,
      // fora deste endpoint; ele nao recebe o conteudo das duvidas da paciente.
      const rows = await sql`WITH candidate AS (
        SELECT r.id,r.usuario_id,r.ubs_codigo
        FROM petita_privado.solicitacoes_vinculo_gestantes r
        JOIN petita_atendimento.acessos a ON a.usuario_id=r.usuario_id
        WHERE r.id=${patientApprove[1]} AND r.situacao='pendente'
          AND a.papel='gestante' AND a.ativo IS TRUE
      ), linked AS (
        INSERT INTO petita_privado.vinculos_gestantes(usuario_id,ubs_codigo)
        SELECT usuario_id,ubs_codigo FROM candidate
        ON CONFLICT(usuario_id) DO UPDATE SET
          ubs_codigo=excluded.ubs_codigo,confirmado_em=now()
        RETURNING usuario_id
      ), finalized AS (
        UPDATE petita_privado.solicitacoes_vinculo_gestantes
        SET situacao='aprovada',decidido_por=${user},decidido_em=now()
        WHERE id IN (SELECT id FROM candidate)
          AND usuario_id IN (SELECT usuario_id FROM linked)
        RETURNING id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'ubs_vinculada',id FROM finalized
      ) SELECT id FROM finalized`;
      if (!rows.length) bad('Solicitacao nao autorizada ou ja decidida', 409);
      return send(res, 200, { situacao: 'aprovada' });
    }

    const rejectTeam = match(path, /^\/api\/admin\/team-requests\/([0-9a-f-]{36})\/reject$/i);
    if (method === 'POST' && rejectTeam) {
      const rows = await sql`WITH changed AS (
        UPDATE petita_atendimento.solicitacoes_acesso
        SET situacao='recusada',decidido_por=${user},decidido_em=now()
        WHERE id=${rejectTeam[1]} AND situacao='pendente' RETURNING id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'solicitacao_recusada',id FROM changed
      ) SELECT id FROM changed`;
      if (!rows.length) bad('Solicitacao indisponivel', 409);
      return send(res, 200, { situacao: 'recusada' });
    }

    const rejectPatient = match(path, /^\/api\/admin\/patient-ubs-requests\/([0-9a-f-]{36})\/reject$/i);
    if (method === 'POST' && rejectPatient) {
      const rows = await sql`WITH changed AS (
        UPDATE petita_privado.solicitacoes_vinculo_gestantes
        SET situacao='recusada',decidido_por=${user},decidido_em=now()
        WHERE id=${rejectPatient[1]} AND situacao='pendente' RETURNING id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'solicitacao_recusada',id FROM changed
      ) SELECT id FROM changed`;
      if (!rows.length) bad('Solicitacao indisponivel', 409);
      return send(res, 200, { situacao: 'recusada' });
    }

    if (method === 'POST' && path === '/api/admin/team/disable') {
      const target = String(readBody(req).usuario_id ?? '');
      if (!/^[0-9a-f-]{36}$/i.test(target) || target === user) bad('Usuario invalido');
      const rows = await sql`WITH demoted AS (
        UPDATE petita_atendimento.acessos
        SET papel='gestante',atualizado_em=now()
        WHERE usuario_id=${target} AND papel='equipe_ubs' RETURNING usuario_id
      ), disabled AS (
        UPDATE petita_atendimento.vinculos_equipes
        SET ativo=false WHERE usuario_id IN (SELECT usuario_id FROM demoted)
        RETURNING usuario_id
      ), audit AS (
        INSERT INTO petita_atendimento.eventos_auditoria(ator_usuario_id,acao,referencia_id)
        SELECT ${user},'equipe_desativada',usuario_id FROM disabled
      ) SELECT usuario_id FROM disabled`;
      if (!rows.length) bad('Equipe nao encontrada', 409);
      return send(res, 200, { status: 'revogado' });
    }

    if (method === 'GET' && path === '/api/admin/overview') {
      // Informacoes operacionais agregadas, sem texto ou nome de gestantes.
      const rows = await sql`SELECT u.name AS ubs, u.code AS ubs_codigo,
        count(d.id)::integer AS total,
        count(d.id) FILTER (WHERE d.situacao='pendente')::integer AS pendentes,
        count(d.id) FILTER (WHERE d.situacao='respondida')::integer AS respondidas,
        count(d.id) FILTER (WHERE d.situacao='encerrada_sem_resposta')::integer AS encerradas
        FROM public.ubs u
        LEFT JOIN petita_atendimento.duvidas d ON d.ubs_codigo=u.code
        GROUP BY u.name,u.code ORDER BY u.name`;
      return send(res, 200, { unidades: rows });
    }

    return send(res, 404, { erro: 'Rota nao encontrada' });
  } catch (e) {
    const status = [400,401,403,404,409,503].includes(e?.status) ? e.status : 500;
    // Nao incluir mensagens internas do Postgres, SQL, payloads ou dados pessoais no erro.
    return send(res, status, { erro: status === 500 ? 'Falha interna no atendimento da solicitacao' : e.message });
  }
}
