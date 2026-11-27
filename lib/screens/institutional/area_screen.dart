import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../services/institutional/runtime.dart';
import '../../services/institutional/plan_sync_controller.dart';
import '../../services/neon_api_client.dart';
import '../../widgets/section_card.dart';
import '../../widgets/account_header_menu.dart';

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
  String _adminSection = 'professionals';
  String? _subject;
  @override
  void initState() {
    super.initState();
    runtime?.auth.addListener(_authChanged);
    _run(_load);
  }

  void _authChanged() {
    if (!mounted) return;
    if (runtime?.auth.signedIn != true || (_subject != null && runtime?.auth.subject != _subject)) {
      setState(() { _profile = null; _questions = []; _team = []; _patients = []; _ubs = []; _subject = null; });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    runtime?.auth.removeListener(_authChanged);
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
    if (!mounted) return;
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
    final subject = r.auth.subject;
    final profile = (await r.api.loadProfile()).single;
    if (!mounted || !r.auth.signedIn || r.auth.subject != subject) return;
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
      team = await r.api.listProfessionalApprovals();
      patients = await r.api.listPatientUbsRequests();
    } else if (profile['role'] == 'ubs_team') {
      questions = await r.api.listTeamQueue();
    } else if (profile['role'] == 'professional_pending') {
      ubs = await r.api.listUbs();
      final own = await r.api.listMyProfessionalRequests();
      if (mounted) setState(() => _requestSent = own.any((r) => r['status'] == 'pending'));
    }
    if (mounted && r.auth.signedIn && r.auth.subject == subject)
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

  Widget _adminOverview() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF492777), Color(0xFF8042B6)]),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.shield_outlined, color: Colors.white, size: 19), SizedBox(width: 8), Expanded(child: Text('PET SAÚDE • GESTÃO INSTITUCIONAL', style: TextStyle(color: Color(0xFFE9D8FF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .4)))]),
      const SizedBox(height: 14),
      const Text('Painel de administração', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Acompanhe as solicitações e gerencie os acessos e conteúdos da Petita.', style: TextStyle(color: Color(0xFFF3E9FF), height: 1.4)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withAlpha(28), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.pending_actions_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(_busy ? 'Consultando solicitações…' : '${_team.length + _patients.length} solicitações pendentes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ])),
    ]),
  );

  Widget _adminTile(String key, String label, String description, IconData icon, double width, {int? count}) {
    final selected = _adminSection == key;
    final color = selected ? const Color(0xFF6332AB) : const Color(0xFF665777);
    return SizedBox(width: width, child: Material(
      color: selected ? const Color(0xFFF0E4FF) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: selected ? const Color(0xFF9B59DA) : const Color(0xFFE5DAEF))),
      child: InkWell(borderRadius: BorderRadius.circular(18),
        onTap: _busy ? null : () => setState(() => _adminSection = key),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFECE1FA), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 21)),
            const Spacer(),
            if (count != null) Text('$count', style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w900)),
            if (count == null && selected) Icon(Icons.check_circle, color: color, size: 18),
          ]),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF6C607B))),
        ])),
      ),
    ));
  }

  Widget _emptyQueue(String message) => SectionCard(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(13), decoration: const BoxDecoration(color: Color(0xFFEDE6FA), shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, color: Color(0xFF6332AB), size: 28)),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      const Text('Novas solicitações aparecerão aqui.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6C607B), fontSize: 13)),
    ]),
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.myQuestions
              ? 'Minhas dúvidas'
              : _profile?['role'] == 'admin' ? 'Administração' : 'Equipe UBS'),
          actions: [
            if (runtime?.auth.signedIn == true) ...[
              IconButton(tooltip: 'Atualizar painel', onPressed: _busy ? null : () => _run(_load), icon: const Icon(Icons.refresh)),
              AccountHeaderMenu(auth: runtime?.auth, professional: !widget.myQuestions, busy: _busy,
                roleLabel: _profile?['role'] == 'admin' ? 'Administração PET Saúde' : widget.myQuestions ? 'Plano de parto' : 'Equipe UBS',
                onRefresh: () => _run(_load)),
            ],
          ]),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.myQuestions) const SectionCard(
            child: Text(
                'Canal não urgente. As respostas dependem da disponibilidade da UBS. Em caso de sinais de alerta, procure atendimento presencial.')),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
        if (!widget.myQuestions && (_profile == null || _profile?['role'] == 'patient'))
          SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_profile == null ? 'Acesso da equipe de saúde' : 'Conta de gestante', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_profile == null
                ? 'Entre com sua conta profissional ou crie uma para solicitar acesso à sua UBS.'
                : 'Esta conta pertence à área da gestante. Entre com uma conta profissional ou crie uma conta específica.'),
            button(_profile == null ? 'Entrar na conta profissional' : 'Trocar de conta', () async {
              await Navigator.pushNamed(context, AppRoutes.professionalAccount, arguments: 'login');
              if (mounted) await _load();
            }),
            if (_profile == null)
              OutlinedButton(onPressed: _busy ? null : () => _run(() async {
                await Navigator.pushNamed(context, AppRoutes.professionalAccount, arguments: 'signup');
                if (mounted) await _load();
              }), child: const Text('Criar perfil profissional')),
          ])),
        if (!widget.myQuestions && _profile?['role'] == 'ubs_team')
          const SectionCard(child: Text('Equipe UBS • Responda às dúvidas encaminhadas à sua unidade de saúde.')),
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
        if (!widget.myQuestions && _profile?['role'] == 'professional_pending')
          SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text('Etapa 2 de 2 • Acesso à UBS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                  await _load();
                }),
                ],
              ])),
        if (!widget.myQuestions && _profile?['role'] == 'admin') ...[
          _adminOverview(),
          const SizedBox(height: 18),
          const Text('Gerenciar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF38205D))),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              _adminTile('professionals', 'Aprovar profissionais', 'Solicitações de acesso', Icons.badge_outlined, width, count: _team.length),
              _adminTile('patients', 'Vínculos de gestantes', 'Solicitações de UBS', Icons.link, width, count: _patients.length),
              _adminTile('knowledge', 'Base educativa', 'Conteúdo do chat', Icons.menu_book_outlined, width),
              _adminTile('access', 'Revogar acessos', 'Permissões e vínculos', Icons.admin_panel_settings_outlined, width),
            ]);
          }),
          const SizedBox(height: 22),
          if (_adminSection == 'knowledge') SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          if (_adminSection == 'professionals') ...[
          const SizedBox(height: 12),
          const Text('Solicitações profissionais pendentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (_team.isEmpty) _emptyQueue('Nenhuma solicitação profissional pendente.'),
          for (final request in _team)
            SectionCard(
                child: Column(children: [
              Text(
                  '${request['display_name'] ?? request['requester_id']} • UBS ${request['requested_ubs_code']}'),
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
          ],
          if (_adminSection == 'patients') ...[
          const Text('Vínculos de gestantes pendentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (_patients.isEmpty) _emptyQueue('Nenhum vínculo de gestante pendente.'),
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
          ],
          if (_adminSection == 'access') SectionCard(
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
