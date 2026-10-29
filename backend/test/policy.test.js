import test from 'node:test';
import assert from 'node:assert/strict';
import { requireRole, requireOwnUbs, validateQuestion } from '../lib/policy.js';

const base = () => ({
  texto: 'Como posso preparar meu plano de parto?',
  categoria: 'Plano de Parto', nivel_percebido: 'baixo',
  sinais_alerta: [], confirmou_nao_urgencia: true,
  confirmou_resposta_facultativa: true,
  confirmou_visibilidade_anonimizada: true,
  confirmou_ubs_exclusiva: true,
});

test('equipe aceita apenas sua UBS e vinculo ativo', () => {
  const team = { papel:'equipe_ubs', ativo:true };
  const ev = { ubs_codigo:'UBS-EV-001', ativo:true };
  assert.equal(requireOwnUbs(team,ev,'UBS-EV-001'),'UBS-EV-001');
  assert.throws(() => requireOwnUbs(team,ev,'UBS-AAV-002'), /nao autorizado/);
  assert.throws(() => requireOwnUbs(team,{...ev,ativo:false}), /nao autorizado/);
  assert.throws(() => requireOwnUbs({papel:'gestante',ativo:true},ev), /nao autorizado/);
  assert.throws(() => requireOwnUbs({papel:'administrador',ativo:true},ev), /nao autorizado/);
});

test('administrador nao e equipe; cadastro inativo nao acessa', () => {
  assert.throws(() => requireRole({papel:'administrador',ativo:true},'equipe_ubs'), /nao autorizado/);
  assert.throws(() => requireRole({papel:'gestante',ativo:false},'gestante'), /nao autorizado/);
  assert.doesNotThrow(() => requireRole({papel:'administrador',ativo:true},'administrador'));
});

test('envio exige quatro aceites explicitos', () => {
  const fields = [
    'confirmou_nao_urgencia', 'confirmou_resposta_facultativa',
    'confirmou_visibilidade_anonimizada', 'confirmou_ubs_exclusiva',
  ];
  for (const key of fields) {
    assert.throws(() => validateQuestion({...base(),[key]:false}), /confirme/);
    assert.throws(() => validateQuestion({...base(),[key]:'true'}), /confirme/);
  }
  assert.equal(validateQuestion(base()).risk,'baixo');
});

test('sinal de alerta, alto risco e dados pessoais bloqueados', () => {
  assert.throws(() => validateQuestion({...base(), nivel_percebido:'alto'}), /atendimento presencial/);
  assert.throws(() => validateQuestion({...base(), sinais_alerta:['Sangramento vaginal']}), /atendimento presencial/);
  assert.throws(() => validateQuestion({...base(), texto:'meu email e ana@exemplo.com'}), /Remova/);
  assert.throws(() => validateQuestion({...base(), texto:'Meu CPF e 123.456.789-01'}), /Remova/);
});

test('conteudo vazio, excessivo e categoria invalida sao rejeitados', () => {
  assert.throws(() => validateQuestion({...base(),texto:'    '}), /Revise/);
  assert.throws(() => validateQuestion({...base(),texto:'x'.repeat(2001)}), /Revise/);
  assert.throws(() => validateQuestion({...base(),categoria:'a'}), /Revise/);
});
