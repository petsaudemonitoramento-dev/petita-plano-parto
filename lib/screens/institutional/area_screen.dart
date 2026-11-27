import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../services/institutional/runtime.dart';
import '../../services/institutional/plan_sync_controller.dart';
import '../../services/neon_api_client.dart';
import '../../widgets/section_card.dart';

class _Cancelled implements Exception {}

class InstitutionalAreaScreen extends StatefulWidget {
  final bool myQuestions;
  final InstitutionalRuntime? runtime;
  const InstitutionalAreaScreen(
      {super.key, this.myQuestions = false, this.runtime});
  @override
  State<InstitutionalAreaScreen> createState() =>
      _InstitutionalAreaScreenState();
}

class _InstitutionalAreaScreenState extends State<InstitutionalAreaScreen> {
  InstitutionalRuntime? get runtime =>
      widget.runtime ?? InstitutionalRuntime.instance;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _questions = [],
      _team = [],
      _patients = [],
      _ubs = [];
  final _member = TextEditingController(), _reason = TextEditingController();
  final Map<String, String> _operations = {};
  String? _message, _code;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  @override
  void dispose() {
    _member.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = runtime;
    if (r == null) throw const NeonApiException(503);
    await r.auth.restore();
    if (!r.auth.signedIn) throw const NeonApiException(401);
    final profile = (await r.api.loadProfile()).single;
    // Clear old privileged content before the next request, including role changes.
    if (mounted)
      setState(() {
        _profile = profile;
        _questions = [];
        _team = [];
        _patients = [];
      });
    List<Map<String, dynamic>> questions = [],
        team = [],
        patients = [],
        ubs = [];
    if (widget.myQuestions) {
      questions = await r.api.listMyQuestions();
    } else if (profile['role'] == 'admin') {
      team = await r.api.listTeamRequests();
      patients = await r.api.listPatientUbsRequests();
    } else if (profile['role'] == 'ubs_team') {
      questions = await r.api.listTeamQueue();
    } else {
      ubs = await r.api.listUbs();
    }
    if (mounted)
      setState(() {
        _questions = questions;
        _team = team;
        _patients = patients;
        _ubs = ubs;
      });
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } on _Cancelled {
      // A cancelled action has no success acknowledgement.
    } catch (_) {
      if (mounted)
        setState(() {
          _profile = null;
          _message =
              'Não foi possível confirmar o acesso ou concluir a operação. Entre na conta institucional e tente novamente. A aprovação depende da instituição.';
          _questions = [];
          _team = [];
          _patients = [];
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget button(String label, Future<void> Function() action) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
          onPressed: _busy
              ? null
              : () =>
                  _run(action, success: 'Operação confirmada pelo servidor.'),
          child: Text(label)));
  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: Text(title),
                  content: const Text(
                      'Confira a identidade, a UBS e a autorização institucional antes de continuar.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Confirmar'))
                  ])) ??
      false;
  Future<void> _answer(Map<String, dynamic> question) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Responder dúvida não urgente'),
                content: TextField(
                    controller: controller,
                    maxLines: 5,
                    maxLength: 6000,
                    decoration:
                        const InputDecoration(labelText: 'Resposta da equipe')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, controller.text.trim()),
                      child: const Text('Enviar resposta'))
                ]));
    // The dialog route may still animate while disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (text == null) throw _Cancelled();
    final key = '${question['id']}:$text';
    final operation = _operations.putIfAbsent(key, newOperationId);
    await runtime!.api
        .respondToQuestion(question['id'] as String, text, operation);
    _operations.remove(key);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.myQuestions
              ? 'Minhas dúvidas'
              : 'Equipe e administração institucional')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        const SectionCard(
            child: Text(
                'Canal não urgente. As respostas dependem da disponibilidade da UBS. Em caso de sinais de alerta, procure atendimento presencial.')),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        button(widget.myQuestions ? 'Abrir minha conta' : 'Entrar ou criar conta profissional', () async {
          await Navigator.pushNamed(context, widget.myQuestions ? AppRoutes.institutional : AppRoutes.professionalAccount);
          await _load();
        }),
        button('Atualizar', _load),
        if (_profile != null)
          Text(
              'Perfil confirmado: ${_profile!['role']} • UBS ${_profile!['ubs_code'] ?? 'sem vínculo'}'),
        for (final q in _questions)
          SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('${q['public_code']} • ${q['ubs_code']}'),
                Text('${q['question_text']}'),
                if (widget.myQuestions)
                  Text(
                      '${q['answer_text'] ?? 'Aguardando resposta da equipe.'}')
                else
                  button('Responder ${q['public_code']}', () => _answer(q)),
              ])),
        if (!widget.myQuestions && _profile?['role'] == 'patient')
          SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text(
                    'Profissionais: solicitem acesso para análise institucional. A solicitação não altera permissões.'),
                DropdownButtonFormField<String>(
                    initialValue: _code,
                    decoration: const InputDecoration(
                        labelText: 'UBS de atuação profissional'),
                    items: _ubs
                        .map((u) => DropdownMenuItem(
                            value: u['code'] as String,
                            child: Text('${u['name']}')))
                        .toList(),
                    onChanged: _busy ? null : (v) => setState(() => _code = v)),
                button('Solicitar acesso profissional', () async {
                  if (_code == null) throw const NeonApiException(400);
                  final op =
                      _operations.putIfAbsent('team:$_code', newOperationId);
                  await runtime!.api.requestTeamAccess(_code!, op);
                  await _load();
                }),
              ])),
        if (!widget.myQuestions && _profile?['role'] == 'admin') ...[
          const Text('Solicitações profissionais pendentes'),
          for (final request in _team)
            SectionCard(
                child: Column(children: [
              Text(
                  'Perfil ${request['requester_id']} • UBS ${request['requested_ubs_code']}'),
              button('Aprovar profissional', () async {
                if (await _confirm('Aprovar acesso profissional?')) {
                  await runtime!.api
                      .decideTeamRequest(request['id'] as String, true);
                  await _load();
                } else {
                  throw _Cancelled();
                }
              }),
              button('Recusar profissional', () async {
                if (await _confirm('Recusar solicitação?')) {
                  await runtime!.api
                      .decideTeamRequest(request['id'] as String, false);
                  await _load();
                } else {
                  throw _Cancelled();
                }
              }),
            ])),
          const Text('Vínculos de gestantes pendentes'),
          for (final request in _patients)
            SectionCard(
                child: Column(children: [
              Text(
                  '${request['display_name']} • ${request['patient_id']} • UBS ${request['ubs_code']}'),
              button('Aprovar vínculo da gestante', () async {
                if (await _confirm('Aprovar vínculo à UBS?')) {
                  await runtime!.api
                      .decidePatientUbs(request['id'] as String, true);
                  await _load();
                } else {
                  throw _Cancelled();
                }
              }),
              button('Recusar vínculo da gestante', () async {
                if (await _confirm('Recusar vínculo?')) {
                  await runtime!.api
                      .decidePatientUbs(request['id'] as String, false);
                  await _load();
                } else {
                  throw _Cancelled();
                }
              }),
            ])),
          SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text(
                    'Revogação institucional — informe o ID conferido no cadastro institucional'),
                TextField(
                    controller: _member,
                    decoration: const InputDecoration(
                        labelText: 'ID do perfil (UUID)')),
                TextField(
                    controller: _reason,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                        labelText: 'Motivo da revogação')),
                button('Revogar acesso profissional', () async {
                  if (await _confirm('Revogar acesso profissional?')) {
                    await runtime!.api.revokeTeamMember(
                        _member.text.trim(), _reason.text.trim());
                    await _load();
                  } else {
                    throw _Cancelled();
                  }
                }),
                button('Revogar vínculo da gestante', () async {
                  if (await _confirm('Revogar vínculo à UBS?')) {
                    await runtime!.api.revokePatientUbs(
                        _member.text.trim(), _reason.text.trim());
                    await _load();
                  } else {
                    throw _Cancelled();
                  }
                }),
              ])),
        ],
      ])));
}
