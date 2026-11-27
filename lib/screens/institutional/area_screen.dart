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
  final _category = TextEditingController(), _question = TextEditingController(), _keywords = TextEditingController(), _educationalAnswer = TextEditingController();
  final Map<String, String> _operations = {};
  String? _message, _code;
  bool _busy = false;
  bool _requestSent = false;
  String? _subject;
  bool get _verified => runtime?.auth.user?['emailVerified'] == true;
  @override
  void initState() {
    super.initState();
    _run(_load);
  }

  @override
  void dispose() {
    _member.dispose();
    _reason.dispose();
    _category.dispose();
    _question.dispose();
    _keywords.dispose();
    _educationalAnswer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = runtime;
    if (r == null) throw const NeonApiException(503);
    await r.auth.restore();
    if (!r.auth.signedIn) {
      if (mounted) setState(() { _profile = null; _questions = []; _team = []; _patients = []; _ubs = []; _code = null; _subject = null; _requestSent = false; });
      return;
    }
    if (_subject != r.auth.subject) {
      _subject = r.auth.subject;
      _requestSent = false;
      _code = null;
      _operations.clear();
    }
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
    } else if (_verified) {
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
              : _profile?['role'] == 'admin' ? 'Administração' : 'Equipe UBS')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.myQuestions) const SectionCard(
            child: Text(
                'Canal não urgente. As respostas dependem da disponibilidade da UBS. Em caso de sinais de alerta, procure atendimento presencial.')),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        if (!widget.myQuestions && (_profile == null || (_profile?['role'] == 'patient' && !_verified)))
          SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_profile == null ? 'Acesso da equipe de saúde' : 'Confirme seu e-mail', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_profile == null
                ? 'Entre com sua conta profissional ou crie uma para solicitar acesso à sua UBS.'
                : 'Esta conta ainda não possui acesso profissional. Se você faz parte de uma equipe de saúde, confirme seu e-mail para solicitar acesso.'),
            button(_profile == null ? 'Entrar ou criar conta profissional' : 'Verificar e-mail ou trocar de conta', () async {
              await Navigator.pushNamed(context, AppRoutes.professionalAccount);
              await _load();
            }),
          ])),
        if (widget.myQuestions || _profile?['role'] == 'admin' || _profile?['role'] == 'ubs_team') ...[
          if (!widget.myQuestions)
            SectionCard(child: Text(_profile?['role'] == 'admin'
                ? 'Administração PET Saúde • Gerencie as solicitações de acesso e a base educativa.'
                : 'Equipe UBS • Responda às dúvidas encaminhadas à sua unidade de saúde.')),
          TextButton(onPressed: _busy ? null : () => _run(_load), child: const Text('Atualizar')),
          TextButton(onPressed: _busy ? null : () => _run(() async {
            await Navigator.pushNamed(context, widget.myQuestions ? AppRoutes.institutional : AppRoutes.professionalAccount);
            await _load();
          }), child: const Text('Minha conta')),
        ],
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
        if (!widget.myQuestions && _profile?['role'] == 'patient' && _verified)
          SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text('Etapa 3 de 3 • Acesso à UBS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_requestSent ? 'Solicitação enviada. Aguarde a aprovação da administração do PET Saúde.' : 'Informe a UBS onde você trabalha. A administração do PET Saúde analisará sua solicitação antes de liberar o acesso às dúvidas.'),
                if (!_requestSent) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _code,
                    decoration: const InputDecoration(
                        labelText: 'UBS de atuação profissional'),
                    items: _ubs
                        .map((u) => DropdownMenuItem(
                            value: u['code'] as String,
                            child: Text('${u['name']}', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: _busy ? null : (v) => setState(() => _code = v)),
                button('Solicitar acesso profissional', () async {
                  if (_code == null) throw const NeonApiException(400);
                  final op =
                      _operations.putIfAbsent('team:$_code', newOperationId);
                  await runtime!.api.requestTeamAccess(_code!, op);
                  if (mounted) setState(() => _requestSent = true);
                }),
                ],
                TextButton(onPressed: _busy ? null : () => _run(() async {
                  await Navigator.pushNamed(context, AppRoutes.professionalAccount);
                  await _load();
                }), child: const Text('Gerenciar conta')),
              ])),
        if (!widget.myQuestions && _profile?['role'] == 'admin') ...[
          SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Base educativa da Petita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Publique apenas orientações educativas revisadas pela equipe, sem informações pessoais de gestantes. As respostas são exibidas no chat.'),
            const SizedBox(height: 12),
            TextField(controller: _category, maxLength: 80, decoration: const InputDecoration(labelText: 'Categoria')),
            button('Cadastrar categoria', () async {
              if (_category.text.trim().length < 2) throw const NeonApiException(400);
              await runtime!.api.addKnowledgeCategory(_category.text.trim());
            }),
            const SizedBox(height: 12),
            TextField(controller: _question, maxLength: 240, decoration: const InputDecoration(labelText: 'Pergunta educativa')),
            TextField(controller: _keywords, decoration: const InputDecoration(labelText: 'Palavras-chave separadas por vírgula')),
            TextField(controller: _educationalAnswer, maxLength: 6000, maxLines: 5, decoration: const InputDecoration(labelText: 'Resposta revisada')),
            button('Publicar resposta educativa', () async {
              if (!await _confirm('Publicar orientação educativa?')) throw _Cancelled();
              await runtime!.api.addKnowledgeItem(category: _category.text.trim(), question: _question.text.trim(), keywords: _keywords.text.split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList(), answer: _educationalAnswer.text.trim());
              _question.clear(); _keywords.clear(); _educationalAnswer.clear();
            }),
          ])),
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
