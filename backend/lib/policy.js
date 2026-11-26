export function forbid(message = 'Acesso nao autorizado') {
  throw Object.assign(new Error(message), { status: 403 });
}

export function requireRole(account, role) {
  if (!account?.ativo || account.papel !== role) forbid();
}

export function requireOwnUbs(account, membership, requestedUbs) {
  requireRole(account, 'equipe_ubs');
  if (!membership?.ativo || !membership.ubs_codigo) forbid();
  if (requestedUbs && requestedUbs !== membership.ubs_codigo) forbid();
  return membership.ubs_codigo;
}

export function validateQuestion(body) {
  const text = String(body?.texto ?? '').trim();
  const category = String(body?.categoria ?? '').trim();
  const risk = String(body?.nivel_percebido ?? '');
  const signs = body?.sinais_alerta;
  if (text.length < 5 || text.length > 2000 || category.length < 2 || category.length > 80) {
    throw Object.assign(new Error('Revise o texto e a categoria'), { status: 400 });
  }
  if (!['baixo', 'moderado'].includes(risk) || !Array.isArray(signs) || signs.length) {
    throw Object.assign(new Error('Sinais de alerta: procure atendimento presencial; nao envie por este canal'), { status: 400 });
  }
  // Evita identificadores obvios. Nao substitui revisao do texto e consentimento.
  if (/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(text) ||
      /\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/.test(text)) {
    throw Object.assign(new Error('Remova e-mail, telefone ou CPF da mensagem'), { status: 400 });
  }
  const acknowledgements = [
    'confirmou_nao_urgencia', 'confirmou_resposta_facultativa',
    'confirmou_visibilidade_anonimizada', 'confirmou_ubs_exclusiva',
  ];
  if (acknowledgements.some(field => body?.[field] !== true)) {
    throw Object.assign(new Error('Leia e confirme todos os avisos antes de enviar'), { status: 400 });
  }
  return { text, category, risk, signs, version: '2026-10-29' };
}
