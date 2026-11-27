import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../services/institutional/runtime.dart';
import '../../services/institutional/auth_transport.dart';
import '../../services/institutional/plan_sync_controller.dart';
import '../../services/storage_service.dart';
import '../../services/neon_api_client.dart';
import '../../widgets/section_card.dart';

class _ActionCancelled implements Exception {}

class InstitutionalAccountScreen extends StatefulWidget {
  final InstitutionalRuntime? runtime;
  final bool professional, syncOnly;
  const InstitutionalAccountScreen({super.key, this.runtime, this.professional = false, this.syncOnly = false});
  @override
  State<InstitutionalAccountScreen> createState() =>
      _InstitutionalAccountScreenState();
}

class _InstitutionalAccountScreenState extends State<InstitutionalAccountScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _otp = TextEditingController();
  final _choices = <String, bool>{};
  static const _unregisteredUbs = '__not_registered__';
  bool _consentKnown = false, _ubsKnown = false, _ubsChoiceSaved = false;
  bool get _acceptedAll => _choices.length == 6 && _choices.values.every((v) => v);
  String? get _approvedUbs => _profile?['ubs_code'] as String?;
  bool get _hasPendingUbs => _requests.any((r) => r['status'] == 'pending');
  InstitutionalRuntime? get _runtime =>
      widget.runtime ?? InstitutionalRuntime.instance;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _plans = [], _units = [], _requests = [];
  bool _busy = false;
  String _mode = 'login';
  bool _routeRead = false, _resetRequested = false;
  String? _localEmail, _localUbs;
  bool _localPrefill = false;
  String? _message, _ubs, _loadedSubject;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run(() async {
      try {
        final local = widget.professional ? null : await StorageService().loadProfile().timeout(const Duration(seconds: 5));
        if (mounted && local != null) {
          _name.text = local.name;
          _email.text = local.email;
          _localEmail = local.email;
          _localUbs = local.ubsCode;
          _localPrefill = true;
        }
      } catch (_) { /* Do not overwrite local storage or prevent account access. */ }
      await _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeRead) return;
    _routeRead = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg == 'signup') _mode = 'signup';
  }

  void _switchMode(String mode) {
    setState(() {
      _mode = mode;
      _resetRequested = false;
      _message = null;
      _password.clear();
      _otp.clear();
    });
  }

  bool _validEmail() => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_busy &&
        _runtime?.auth.signedIn == true) {
      _run(() async {
        await _runtime!.sync.retryPending();
        await _load();
      }, success: 'Conexão verificada.');
    }
  }

  Future<void> _load() async {
    final runtime = _runtime;
    if (runtime == null) return;
    await runtime.auth.restore();
    if (!mounted) return;
    final subject = runtime.auth.signedIn ? runtime.auth.subject : null;
    if (_loadedSubject != subject || subject == null) {
      setState(() {
        _profile = null;
        _plans = [];
        _units = [];
        _requests = [];
        _choices.clear();
        _ubs = null;
        _consentKnown = false;
        _ubsKnown = false;
        _ubsChoiceSaved = false;
        _loadedSubject = subject;
      });
    }
    if (subject == null) return;
    if (_profile == null) {
      if (widget.professional) { await runtime.api.enrollProfessionalProfile(); }
      else { await runtime.api.enrollProfile(); }
    }
    final rows = await runtime.api.loadProfile();
    if (!mounted || runtime.auth.subject != subject) return;
    setState(() => _profile = rows.single);
    if (rows.single['role'] != 'patient' || widget.professional) return;
    var failed = false;
    // Refresh independent sections without clearing the entire account.
    await Future.wait<void>([
      () async {
        try {
          await runtime.sync.refreshConsent();
          if (mounted && runtime.auth.subject == subject) {
            setState(() => _consentKnown = true);
          }
        } catch (_) {
          failed = true;
          if (mounted && runtime.auth.subject == subject) {
            setState(() => _consentKnown = false);
          }
        }
      }(),
      () async {
        try {
          final plans = await runtime.api.listPlans();
          if (mounted && runtime.auth.subject == subject) {
            setState(() => _plans = plans);
          }
        } catch (_) { failed = true; }
      }(),
      () async {
        try {
          final units = await runtime.api.listUbs();
          final requests = await runtime.api.listMyUbsRequests();
          String? preference;
          bool choiceSaved = false;
          try {
            choiceSaved = (await runtime.api.getUbsPreference()).isNotEmpty;
          } catch (_) { /* Older API or network failure; never grants access. */ }
          try {
            preference = await runtime.sync.vault.read('petita.ubs.preference:$subject');
          } catch (_) { /* Local preference is optional. */ }
          if (!mounted || runtime.auth.subject != subject) return;
          setState(() {
            _units = units;
            _requests = requests;
            _ubsKnown = true;
            _ubsChoiceSaved = choiceSaved || preference == _unregisteredUbs;
            if (_approvedUbs != null) {
              _ubs = _approvedUbs;
            } else if (_ubs == null && !_hasPendingUbs) {
              if (_ubsChoiceSaved) {
                _ubs = _unregisteredUbs;
              } else if (_localEmail != null &&
                  '${runtime.auth.user?['email']}'.toLowerCase() == _localEmail!.toLowerCase() &&
                  units.any((u) => u['code'] == _localUbs)) {
                _ubs = _localUbs;
              }
            }
            if (_hasPendingUbs && _ubs == _unregisteredUbs) _ubs = null;
          });
        } catch (_) {
          failed = true;
          if (mounted && runtime.auth.subject == subject) {
            setState(() => _ubsKnown = false);
          }
        }
      }(),
    ]);
    if (failed) throw const NeonApiException(503);
  }

  Future<void> _enterConversation() async {
    if (!mounted || widget.professional) return;
    final runtime = _runtime;
    if (runtime == null || !runtime.auth.signedIn) return;
    if (_profile?['role'] == 'patient' && _ubsKnown &&
        _approvedUbs == null && _requests.isEmpty && !_ubsChoiceSaved) {
      String? selected = _units.any((u) => u['code'] == _ubs) ? _ubs : null;
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('Qual é sua UBS?'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escolha sua unidade de saúde uma única vez. Isso permite solicitar acesso ao envio de dúvidas para a equipe.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Sua UBS'),
                items: [
                  ..._units.map((u) => DropdownMenuItem<String>(value: u['code'] as String, child: Text('${u['name']}', overflow: TextOverflow.ellipsis))),
                  const DropdownMenuItem(value: _unregisteredUbs, child: Text('Minha UBS não está cadastrada', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => update(() => selected = value),
              ),
              const SizedBox(height: 8),
              Text(selected == _unregisteredUbs
                ? 'Você poderá usar e sincronizar seu plano normalmente. O envio de dúvidas à UBS ficará indisponível.'
                : 'A equipe só receberá suas dúvidas depois que a administração aprovar o vínculo. Você pode usar o plano enquanto aguarda.'),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
            FilledButton(onPressed: selected == null ? null : () => Navigator.pop(ctx, selected), child: const Text('Continuar')),
          ],
        )),
      );
      if (choice == null || !mounted) return;
      if (choice == _unregisteredUbs) {
        await runtime.api.saveNoUbsPreference();
        await _chooseUbs(choice);
        _ubsChoiceSaved = true;
      } else {
        if (!_units.any((u) => u['code'] == choice)) throw const NeonApiException(400);
        await runtime.api.requestPatientUbs(choice, newOperationId());
        _ubs = choice;
      }
    }
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.chat);
  }

  Future<void> _finishLogin() async {
    try {
      await _load();
    } catch (_) {
      // A partial profile/connection failure must be shown; don't force onboarding.
      if (_profile == null) rethrow;
    }
    if (!widget.professional && !widget.syncOnly && _profile?['role'] == 'patient') {
      await _enterConversation();
    }
  }

  Future<void> _syncPlan(InstitutionalRuntime runtime) async {
    if (!_consentKnown) {
      await runtime.sync.refreshConsent();
      if (mounted) setState(() => _consentKnown = true);
      return;
    }
    if (!runtime.sync.consentActive) {
      if (!_acceptedAll) throw const NeonApiException(400);
      await runtime.sync.grantConsent(_choices);
      if (mounted) setState(() => _choices.clear());
    }
    final answers = await StorageService().loadAnswers();
    final hadPending = runtime.sync.pending;
    if (answers.isNotEmpty || hadPending) {
      if (answers.isEmpty) {
        await runtime.sync.retryPending();
      } else {
        await runtime.sync.synchronize(answers);
      }
      final plans = await runtime.api.listPlans();
      if (mounted) setState(() => _plans = plans);
    }
    if (mounted) {
      setState(() => _consentKnown = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        answers.isEmpty && !hadPending ? 'Sincronização ativada. Seu plano poderá ser salvo online quando estiver preenchido.' : 'Plano salvo online com sucesso.',
      )));
    }
  }

  Future<void> _openLocalProfile() async {
    final user = _runtime?.auth.user;
    final data = <String, String>{};
    if (_profile?['role'] == 'patient' && user != null) {
      if (user['name'] is String) data['name'] = user['name'] as String;
      if (user['email'] is String) data['email'] = user['email'] as String;
      if (_approvedUbs != null) data['ubsCode'] = _approvedUbs!;
    }
    await Navigator.pushNamed(context, AppRoutes.profile, arguments: data);
    if (!mounted) return;
    try {
      final local = await StorageService().loadProfile().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _localEmail = local?.email;
        _localUbs = local?.ubsCode;
        _localPrefill = local != null;
        if (local != null && _runtime?.auth.signedIn != true) {
          _name.text = local.name;
          _email.text = local.email;
        }
        if (_approvedUbs == null && !_hasPendingUbs && _ubs != _unregisteredUbs &&
            local != null && local.email.toLowerCase() == '${_runtime?.auth.user?['email']}'.toLowerCase() &&
            _units.any((u) => u['code'] == local.ubsCode)) {
          _ubs = local.ubsCode;
        }
      });
    } catch (_) { /* Local editing remains accessible without a network connection. */ }
  }

  Future<void> _chooseUbs(String? value) async {
    setState(() => _ubs = value);
    final runtime = _runtime;
    final subject = runtime?.auth.subject;
    if (runtime == null || subject == null) return;
    try {
      final key = 'petita.ubs.preference:$subject';
      if (value == _unregisteredUbs) {
        await runtime.sync.vault.write(key, _unregisteredUbs);
      } else {
        await runtime.sync.vault.delete(key);
      }
    } catch (_) { /* Selection still works this visit; no fake link is sent. */ }
  }

  String _safe(Object error) {
    if (widget.professional && error is NeonApiException) {
      return 'Não foi possível confirmar o acesso profissional. Verifique sua conexão e tente novamente.';
    }
    if (error is InstitutionalAuthException || error is PlanConflict)
      return '$error';
    if (error is NeonApiException && error.status == 409)
      return 'A operação mudou em outro acesso. Seus dados locais foram mantidos. Atualize e confira as versões.';
    if (_runtime?.auth.signedIn == true && _profile == null) {
      return 'Você entrou na sua conta, mas ainda não conseguimos carregar o perfil online. Seu plano neste aparelho está seguro. Toque em Tentar carregar perfil novamente ou continue sem internet.';
    }
    return 'Não foi possível concluir a operação. O plano local foi mantido. Tente novamente quando houver conexão.';
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } on _ActionCancelled {
      /* No success message for a cancelled operation. */
    } catch (e) {
      if (mounted) {
        setState(() => _message = _safe(e));
        if (_profile != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_safe(e))));
        }
      }
    } finally {
      if (mounted) {
        _password.clear();
        _otp.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(message), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirmar')),
              ])) ??
      false;
  Widget _button(String label, Future<void> Function() action,
          {String? success}) =>
      Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(
              onPressed: _busy ? null : () => _run(action, success: success),
              child: Text(label)));
  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    return Scaffold(
        appBar: AppBar(title: Text(widget.professional ? 'Acesso profissional' : widget.syncOnly ? 'Meu plano online' : 'Minha conta')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          if (!widget.professional && !widget.syncOnly)
            SectionCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Meus dados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Edite seu perfil e sua UBS para o plano de parto, mesmo sem internet. Não é necessário criar uma conta.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openLocalProfile,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar meus dados')),
              ],
            )),
          if (runtime == null)
            const SectionCard(
                child: Text(
                    'A conexão institucional ainda não está disponível nesta versão. O plano offline continua disponível.')),
          if (_message != null)
            SectionCard(
                child: Semantics(liveRegion: true, child: Text(_message!))),
          if (_busy)
            const LinearProgressIndicator(
                semanticsLabel: 'Concluindo operação'),
          if (runtime != null) ...[
            if (widget.syncOnly && runtime.auth.signedIn && _profile == null)
              _button('Tentar carregar perfil novamente', _load),
            if (widget.syncOnly && !runtime.auth.signedIn)
              const SectionCard(child: Text('Entre em sua conta para salvar ou recuperar seu plano online. O plano local continua disponível.')),
            if (!runtime.auth.signedIn)
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    _mode == 'signup' ? (widget.professional ? 'Etapa 1 de 2 • Criar conta profissional' : 'Crie sua conta') : _mode == 'reset' ? 'Recupere sua senha' : 'Entre na sua conta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_mode == 'signup'
                      ? (widget.professional ? 'Crie sua conta profissional e escolha a UBS onde atua. A administração precisa aprovar sua solicitação.' : 'Crie uma conta para guardar uma cópia online do seu plano e enviar dúvidas à UBS. É opcional e precisa de internet.')
                      : _mode == 'reset'
                          ? 'Informe o e-mail da sua conta para receber um código de recuperação.'
                          : (widget.professional ? 'Entre com seu e-mail e senha. O acesso à equipe depende da aprovação institucional.' : 'Use o e-mail e a senha da sua conta online. Seu plano salvo neste aparelho continua disponível.')),
                  if (_localPrefill && _mode == 'signup') ...[
                    const SizedBox(height: 12),
                    const Text('Aproveitamos seu nome e e-mail do cadastro neste aparelho. Confira se estão corretos.'),
                  ],
                  const SizedBox(height: 16),
                  if (_mode == 'signup') ...[
                    TextField(controller: _name, textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(labelText: widget.professional ? 'Nome do profissional' : 'Nome da gestante')),
                    const SizedBox(height: 12),
                  ],
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress,
                      autocorrect: false, decoration: const InputDecoration(labelText: 'E-mail')),
                  if (_mode != 'reset' || _resetRequested) ...[
                    const SizedBox(height: 12),
                    if (_mode == 'reset') ...[
                      TextField(controller: _otp, keyboardType: TextInputType.number,
                          autocorrect: false, enableSuggestions: false,
                          decoration: const InputDecoration(labelText: 'Código recebido por e-mail')),
                      const SizedBox(height: 12),
                    ],
                    TextField(controller: _password, obscureText: true,
                        enableSuggestions: false, autocorrect: false,
                        decoration: InputDecoration(
                          labelText: _mode == 'reset' ? 'Nova senha' : 'Senha',
                          helperText: _mode == 'signup' || _mode == 'reset' ? 'Use pelo menos 8 caracteres.' : null)),
                  ],
                  const SizedBox(height: 8),
                  if (_mode == 'signup') ...[
                    _button('Criar minha conta', () async {
                      if (_name.text.trim().isEmpty || !_validEmail() || _password.text.length < 8) {
                        setState(() => _message = 'Informe seu nome, um e-mail válido e uma senha de pelo menos 8 caracteres.');
                        throw _ActionCancelled();
                      }
                      final email = _email.text.trim(), password = _password.text;
                      await runtime.auth.signup(_name.text, email, password);
                      if (!mounted) return;
                      setState(() {
                        _mode = 'login';
                        _message = 'Conta criada. Agora vamos entrar com seus dados.';
                      });
                      try {
                        await runtime.auth.login(email, password);
                      } catch (_) {
                        if (mounted) setState(() => _message = 'Sua conta foi criada. Digite sua senha e toque em Entrar para continuar.');
                        throw _ActionCancelled();
                      }
                      await _finishLogin();
                    }, success: widget.professional ? 'Conta criada. Escolha sua UBS para solicitar acesso.' : 'Conta criada e perfil carregado. Bem-vinda à Petita!'),
                    TextButton(onPressed: _busy ? null : () => _switchMode('login'),
                        child: const Text('Já tenho uma conta')),
                  ] else if (_mode == 'login') ...[
                    _button('Entrar', () async {
                      if (!_validEmail() || _password.text.isEmpty) {
                        setState(() => _message = 'Informe seu e-mail e sua senha.');
                        throw _ActionCancelled();
                      }
                      await runtime.auth.login(_email.text, _password.text);
                      await _finishLogin();
                    }, success: 'Você entrou na sua conta.'),
                    TextButton(onPressed: _busy ? null : () => _switchMode('reset'),
                        child: const Text('Esqueci minha senha')),
                    const Divider(),
                    OutlinedButton(onPressed: _busy ? null : () => _switchMode('signup'),
                        child: const Text('Criar conta')),
                  ] else ...[
                    if (!_resetRequested)
                      _button('Enviar código de recuperação', () async {
                        if (!_validEmail()) {
                          setState(() => _message = 'Informe um e-mail válido.');
                          throw _ActionCancelled();
                        }
                        await runtime.auth.requestReset(_email.text.trim());
                        if (mounted) setState(() => _resetRequested = true);
                      }, success: 'Se houver uma conta cadastrada, o código chegará ao seu e-mail.')
                    else
                      _button('Salvar nova senha', () async {
                        if (!_validEmail() || _otp.text.trim().isEmpty || _password.text.length < 8) {
                          setState(() => _message = 'Informe o código recebido e uma nova senha de pelo menos 8 caracteres.');
                          throw _ActionCancelled();
                        }
                        await runtime.auth.reset(_email.text, _otp.text, _password.text);
                        if (mounted) _switchMode('login');
                      }, success: 'Senha alterada. Entre com a nova senha.'),
                    TextButton(onPressed: _busy ? null : () => _switchMode('login'),
                        child: const Text('Voltar para entrar')),
                  ],
                ])),
            if (runtime.auth.user != null && !widget.syncOnly)
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text(widget.professional ? 'Sua conta' : 'Você está conectada', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('Conta: ${runtime.auth.user!['email'] ?? ''}'),
                    if (_profile == null)
                      Text(widget.professional ? 'Ainda não foi possível confirmar suas permissões.' : 'O perfil online ainda não foi carregado. Você pode usar o plano neste aparelho normalmente.'),
                    if (widget.professional && _profile != null) ...[
                      const SizedBox(height: 12),
                      Text(_profile?['role'] == 'admin' ? 'Acesso administrativo liberado' : _profile?['role'] == 'ubs_team' ? 'Acesso profissional liberado' : _profile?['role'] == 'professional_pending' ? 'Etapa 2 de 2 • Solicitar acesso à UBS' : 'Esta conta é de gestante', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      if (_profile?['role'] == 'professional_pending')
                        const Text('Escolha sua UBS. A administração precisa aprovar seu cadastro antes de liberar o acesso às dúvidas.'),
                      if (_profile?['role'] == 'patient')
                        const Text('Saia desta conta e crie uma conta profissional com outro e-mail.'),
                    ],
                    if (!widget.professional && _profile != null)
                      Text('UBS aprovada: ${_profile!['ubs_code'] ?? 'ainda sem vínculo'}'),
                    if (_profile == null || widget.professional)
                      _button(_profile == null ? 'Tentar carregar perfil novamente' : 'Atualizar situação', _load,
                          success: 'Situação atualizada.'),
                    if (!widget.professional && _profile?['role'] == 'patient')
                      _button('Conversar com a Petita', _enterConversation),
                    if (_profile != null && !widget.professional)
                      TextButton(onPressed: _busy ? null : () => _run(_load, success: 'Situação atualizada.'), child: const Text('Atualizar conta')),
                    _button('Sair da conta', () async {
                      if (!await _confirm('Encerrar sessão?',
                          'A sessão e os tokens deste acesso serão encerrados. O plano offline deste aparelho permanece salvo; para apagá-lo, use a ação de limpeza local.'))
                        throw _ActionCancelled();
                      try {
                        await runtime.auth.logout();
                      } finally {
                        if (mounted)
                          setState(() {
                            _profile = null;
                            _plans = [];
                            _requests = [];
                            _choices.clear();
                            _units = [];
                            _ubs = null;
                            _loadedSubject = null;
                            _consentKnown = false;
                            _ubsKnown = false;
                            _ubsChoiceSaved = false;
                          });
                      }
                    },
                        success:
                            'Sessão encerrada. O plano offline permanece neste aparelho.'),
                  ])),
            if (!widget.professional && _profile?['role'] == 'patient' && runtime.auth.signedIn) ...[
              if (widget.syncOnly) SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Sincronização online opcional',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text(
                        'Você pode continuar sem sincronizar. O envio pode incluir informações pessoais e de saúde deste plano e ficará associado à conta institucional acima.'),
                    if (_consentKnown && !runtime.sync.consentActive) Material(
                      type: MaterialType.transparency,
                      child: Column(children: [
                        for (final item in (const {
                          'terms': 'Li os Termos de Uso',
                          'privacy': 'Li a Política de Privacidade',
                          'responsibility':
                              'Li o aviso de responsabilidade em saúde',
                          'planScience': 'Li a ciência do Plano de Parto',
                          'healthData':
                              'Concordo com o tratamento das informações de saúde fornecidas',
                          'onlineSync':
                              'Autorizo a sincronização online deste plano'
                        }).entries)
                          CheckboxListTile(
                              value: _choices[item.key] ?? false,
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(
                                      () => _choices[item.key] = v == true),
                              title: Text(item.value)),
                      ]),
                    ),
                    if (_consentKnown && !runtime.sync.consentActive)
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.privacy),
                        child: const Text('Ler documentos de privacidade')),
                    const SizedBox(height: 8),
                    Text(!_consentKnown
                        ? 'Não foi possível confirmar a situação online.'
                        : runtime.sync.consentActive
                            ? 'Sincronização ativada'
                            : 'Sincronização desativada',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_consentKnown && !runtime.sync.consentActive && !_acceptedAll)
                      const Text('Marque todos os itens para autorizar a sincronização.'),
                    if (runtime.sync.pending && _consentKnown && runtime.sync.consentActive)
                      const Text('Há um envio pendente. Seus dados continuam salvos neste aparelho.'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy || (_consentKnown && !runtime.sync.consentActive && !_acceptedAll)
                          ? null
                          : () => _run(() => _syncPlan(runtime)),
                      child: Text(!_consentKnown
                          ? 'Verificar conexão'
                          : !runtime.sync.consentActive
                              ? 'Autorizar e sincronizar'
                              : runtime.sync.pending
                                  ? 'Tentar sincronizar novamente'
                                  : 'Sincronizar meu plano')),
                    if (_consentKnown && runtime.sync.consentActive)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _run(() async {
                          if (!await _confirm('Desativar sincronização?',
                              'Novos envios serão bloqueados. Isso não apaga automaticamente os registros já enviados.')) {
                            throw _ActionCancelled();
                          }
                          await runtime.sync.withdrawConsent();
                          if (mounted) setState(() => _choices.clear());
                        }, success: 'Sincronização desativada.'),
                        child: const Text('Desativar sincronização')),
                  ])),
              if (widget.syncOnly) SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Planos da sua conta', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (_plans.isEmpty) const Text('Nenhum plano online disponível.'),
                    for (final plan in _plans)
                      _button('Recuperar plano — revisão ${plan['revision']}',
                          () async {
                        if (!await _confirm('Recuperar plano salvo?',
                            'A versão da nuvem substituirá o plano aberto. Uma cópia local protegida será guardada antes da alteração.'))
                          throw _ActionCancelled();
                        await runtime.sync.restorePlan(plan['id'] as String,
                            confirmedReplace: true);
                      },
                          success:
                              'Plano recuperado. Abra Meu Plano de Parto para revisar e gerar o PDF.'),
                  ])),
              if (!widget.syncOnly) SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Sua UBS de referência', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (!_ubsKnown)
                      const Text('Não foi possível verificar sua UBS. Atualize a conta.')
                    else if (_approvedUbs != null)
                      Text('Vínculo aprovado: ${_units.where((u) => u['code'] == _approvedUbs).map((u) => u['name']).firstOrNull ?? _approvedUbs}')
                    else if (_hasPendingUbs)
                      const Text('Seu vínculo está em análise. Você pode sincronizar o plano, mas só poderá enviar dúvidas após a aprovação.')
                    else ...[
                      const Text('Escolha sua UBS para solicitar acesso ao envio de dúvidas. Esta escolha é opcional.'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_ubs),
                        isExpanded: true,
                        initialValue: _ubs == _unregisteredUbs || _units.any((u) => u['code'] == _ubs) ? _ubs : null,
                        decoration: const InputDecoration(labelText: 'Selecione sua UBS'),
                        items: [
                          ..._units.map((u) => DropdownMenuItem(
                              value: u['code'] as String,
                              child: Text('${u['name']}', overflow: TextOverflow.ellipsis))),
                          const DropdownMenuItem(value: _unregisteredUbs, child: Text('Minha UBS não está cadastrada', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: _busy ? null : (value) => _run(() async {
                          if (value == _unregisteredUbs) {
                            await runtime.api.saveNoUbsPreference();
                            _ubsChoiceSaved = true;
                          }
                          await _chooseUbs(value);
                        })),
                      if (_ubs == _unregisteredUbs)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.info_outline),
                              SizedBox(width: 10),
                              Expanded(child: Text('Você pode salvar e sincronizar seu plano online normalmente. O envio de dúvidas à equipe ficará indisponível até que sua UBS esteja cadastrada e seu vínculo seja aprovado.')),
                            ]),
                          ),
                        )
                      else if (_units.any((u) => u['code'] == _ubs))
                        _button('Solicitar vínculo à UBS', () async {
                          if (!_units.any((u) => u['code'] == _ubs)) throw const NeonApiException(400);
                          await runtime.api.requestPatientUbs(_ubs!, newOperationId());
                          await _load();
                        }, success: 'Solicitação enviada. Aguarde a aprovação do vínculo.'),
                    ],
                    for (final request in _requests)
                      Text('Solicitação ${request['ubs_code']}: ${request['status']}'),
                  ])),
            ],
            if (widget.professional && runtime.auth.signedIn && ['admin','ubs_team','professional_pending'].contains(_profile?['role']))
              _button(_profile?['role'] == 'admin' ? 'Abrir administração' : _profile?['role'] == 'ubs_team' ? 'Abrir painel da equipe' : 'Escolher minha UBS', () async {
                await Navigator.pushNamed(context, _profile?['role'] == 'admin' ? AppRoutes.admin : AppRoutes.ubs);
              }),
          ],
        ])));
  }
}
