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
  const InstitutionalAccountScreen({super.key, this.runtime});
  @override
  State<InstitutionalAccountScreen> createState() =>
      _InstitutionalAccountScreenState();
}

class _InstitutionalAccountScreenState extends State<InstitutionalAccountScreen>
    with WidgetsBindingObserver {
  final _name = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _otp = TextEditingController();
  final _professionalOtp = TextEditingController();
  final _choices = <String, bool>{};
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
        final local = await StorageService().loadProfile().timeout(const Duration(seconds: 5));
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

  bool _validEmail() => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _professionalOtp.dispose();
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
    try {
      await runtime.auth.restore();
      if (mounted)
        setState(() {
          _profile = null;
          _plans = [];
          _requests = [];
          if (_loadedSubject != runtime.auth.subject) {
            _choices.clear();
            _ubs = null;
          }
          _loadedSubject = runtime.auth.subject;
        });
      if (runtime.auth.user != null) {
        await runtime.api.enrollProfile();
        final rows = await runtime.api.loadProfile();
        final units = await runtime.api.listUbs();
        List<Map<String, dynamic>> plans = [], requests = [];
        if (rows.single['role'] == 'patient') {
          await runtime.sync.refreshConsent();
          plans = await runtime.api.listPlans();
          requests = await runtime.api.listMyUbsRequests();
        }
        if (mounted)
          setState(() {
            _profile = rows.single;
            _plans = plans;
            _units = units;
            _requests = requests;
            if (_ubs == null && _localEmail != null &&
                '${runtime.auth.user?['email']}'.toLowerCase() == _localEmail!.toLowerCase() &&
                units.any((u) => u['code'] == _localUbs)) {
              _ubs = _localUbs;
            }
          });
      }
    } catch (_) {
      rethrow;
    }
  }

  String _safe(Object error) {
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
      if (mounted) setState(() => _message = _safe(e));
    } finally {
      if (mounted) {
        _password.clear();
        _otp.clear();
        _professionalOtp.clear();
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
        appBar: AppBar(title: const Text('Minha conta')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
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
            if (!runtime.auth.signedIn)
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
                    _mode == 'signup' ? 'Crie sua conta' : _mode == 'reset' ? 'Recupere sua senha' : 'Entre na sua conta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_mode == 'signup'
                      ? 'Crie uma conta para guardar uma cópia online do seu plano e enviar dúvidas à UBS. É opcional e precisa de internet.'
                      : _mode == 'reset'
                          ? 'Informe o e-mail da sua conta para receber um código de recuperação.'
                          : 'Use o e-mail e a senha da sua conta online. Seu plano salvo neste aparelho continua disponível.'),
                  if (_localPrefill && _mode == 'signup') ...[
                    const SizedBox(height: 12),
                    const Text('Aproveitamos seu nome e e-mail do cadastro neste aparelho. Confira se estão corretos.'),
                  ],
                  const SizedBox(height: 16),
                  if (_mode == 'signup') ...[
                    TextField(controller: _name, textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome da gestante')),
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
                      await _load();
                    }, success: 'Conta criada e perfil carregado. Bem-vinda à Petita!'),
                    TextButton(onPressed: _busy ? null : () => _switchMode('login'),
                        child: const Text('Já tenho uma conta')),
                  ] else if (_mode == 'login') ...[
                    _button('Entrar', () async {
                      if (!_validEmail() || _password.text.isEmpty) {
                        setState(() => _message = 'Informe seu e-mail e sua senha.');
                        throw _ActionCancelled();
                      }
                      await runtime.auth.login(_email.text, _password.text);
                      await _load();
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
                  TextButton(onPressed: _busy ? null : () => Navigator.maybePop(context),
                      child: const Text('Continuar sem conta online')),
                ])),
            if (runtime.auth.user != null)
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Você está conectada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('Conta: ${runtime.auth.user!['email'] ?? ''}'),
                    if (_profile == null)
                      const Text('O perfil online ainda não foi carregado. Você pode usar o plano neste aparelho normalmente.'),
                    if (runtime.auth.user?['emailVerified'] != true)
                      Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          title: const Text('Verificação para acesso profissional'),
                          children: [
                            _button('Enviar código de verificação',
                                () => runtime.auth.resend(runtime.auth.user!['email'] as String),
                                success: 'Confira seu e-mail.'),
                            TextField(
                              controller: _professionalOtp,
                              decoration: const InputDecoration(labelText: 'Código de verificação profissional'),
                            ),
                            _button('Verificar e-mail profissional', () async {
                              await runtime.auth.verify(runtime.auth.user!['email'] as String, _professionalOtp.text);
                              await _load();
                            }, success: 'E-mail verificado.'),
                          ],
                        ),
                      ),
                    if (_profile != null) ...[
                      Text('Perfil institucional: ${_profile!['role']}'),
                      Text(
                          'UBS aprovada: ${_profile!['ubs_code'] ?? 'ainda sem vínculo'}'),
                    ],
                    _button(_profile == null ? 'Tentar carregar perfil novamente' : 'Atualizar situação', _load,
                        success: 'Situação atualizada.'),
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
                          });
                      }
                    },
                        success:
                            'Sessão encerrada. O plano offline permanece neste aparelho.'),
                  ])),
            if (_profile?['role'] == 'patient' && runtime.auth.signedIn) ...[
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Sincronização online opcional',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text(
                        'Você pode continuar sem sincronizar. O envio pode incluir informações pessoais e de saúde deste plano e ficará associado à conta institucional acima.'),
                    Material(
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
                    TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.privacy),
                        child: const Text('Ler documentos de privacidade')),
                    _button('Registrar consentimento online', () async {
                      await runtime.sync.grantConsent(_choices);
                      await _load();
                    }, success: 'Consentimento online registrado.'),
                    Text(
                        'Consentimento no servidor: ${runtime.sync.consentActive ? 'ativo' : 'não ativo'}'),
                    _button('Salvar e sincronizar meu plano', () async {
                      await runtime.sync
                          .synchronize(await StorageService().loadAnswers());
                      await _load();
                    },
                        success:
                            'Plano salvo e sincronizado. Revisão confirmada pelo servidor.'),
                    _button('Tentar envio pendente novamente', () async {
                      await runtime.sync.retryPending();
                      await _load();
                    },
                        success:
                            'Envio pendente verificado. Confira a lista de planos.'),
                    _button('Retirar consentimento online', () async {
                      if (!await _confirm('Retirar consentimento online?',
                          'Novos envios serão bloqueados. Isso não apaga automaticamente os registros já enviados.'))
                        throw _ActionCancelled();
                      await runtime.sync.withdrawConsent();
                      await _load();
                    }, success: 'Consentimento online retirado.'),
                    if (runtime.sync.pending)
                      const Text(
                          'Há um envio pendente. Seus dados locais permanecem salvos.'),
                  ])),
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Planos da sua conta'),
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
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text(
                        'Sua UBS de referência'),
                    const Text('Confira a UBS e solicite o vínculo. A equipe precisa aprovar antes de receber suas dúvidas.'),
                    DropdownButtonFormField<String>(
                        key: ValueKey(_ubs),
                        initialValue: _units.any((u) => u['code'] == _ubs) ? _ubs : null,
                        decoration:
                            const InputDecoration(labelText: 'UBS solicitada'),
                        items: _units
                            .map((u) => DropdownMenuItem(
                                value: u['code'] as String,
                                child: Text('${u['name']}')))
                            .toList(),
                        onChanged:
                            _busy ? null : (v) => setState(() => _ubs = v)),
                    _button('Solicitar vínculo à UBS', () async {
                      if (_ubs == null) throw const NeonApiException(400);
                      await runtime.api
                          .requestPatientUbs(_ubs!, newOperationId());
                      await _load();
                    },
                        success:
                            'Solicitação enviada. A escolha não concede vínculo automaticamente.'),
                    for (final request in _requests)
                      Text(
                          'Solicitação ${request['ubs_code']}: ${request['status']}'),
                  ])),
            ],
            if (runtime.auth.signedIn && _profile != null)
              _button('Área profissional e administrativa', () async {
                await Navigator.pushNamed(context, AppRoutes.ubs);
              }),
          ],
        ])));
  }
}
).hasMatch(_email.text.trim());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _professionalOtp.dispose();
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
    try {
      await runtime.auth.restore();
      if (mounted)
        setState(() {
          _profile = null;
          _plans = [];
          _requests = [];
          if (_loadedSubject != runtime.auth.subject) {
            _choices.clear();
            _ubs = null;
          }
          _loadedSubject = runtime.auth.subject;
        });
      if (runtime.auth.user != null) {
        await runtime.api.enrollProfile();
        final rows = await runtime.api.loadProfile();
        final units = await runtime.api.listUbs();
        List<Map<String, dynamic>> plans = [], requests = [];
        if (rows.single['role'] == 'patient') {
          await runtime.sync.refreshConsent();
          plans = await runtime.api.listPlans();
          requests = await runtime.api.listMyUbsRequests();
        }
        if (mounted)
          setState(() {
            _profile = rows.single;
            _plans = plans;
            _units = units;
            _requests = requests;
          });
      }
    } catch (_) {
      rethrow;
    }
  }

  String _safe(Object error) {
    if (error is InstitutionalAuthException || error is PlanConflict)
      return '$error';
    if (error is NeonApiException && error.status == 409)
      return 'A operação mudou em outro acesso. Seus dados locais foram mantidos. Atualize e confira as versões.';
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
      if (mounted) setState(() => _message = _safe(e));
    } finally {
      _password.clear();
      _otp.clear();
      _professionalOtp.clear();
      if (mounted) setState(() => _busy = false);
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
        appBar: AppBar(title: const Text('Conta institucional')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
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
            SectionCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Nome para cadastro')),
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(labelText: 'E-mail da conta')),
                  TextField(
                      controller: _password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Senha')),
                  _button('Criar conta', () async {
                    await runtime.auth.signup(_name.text, _email.text, _password.text);
                  }, success: 'Cadastro solicitado. Entre com seu e-mail e senha.'),
                  _button('Entrar', () async {
                    await runtime.auth.login(_email.text, _password.text);
                    await _load();
                  },
                      success:
                          'Sessão iniciada. Confira a situação do perfil abaixo.'),
                  TextField(
                      controller: _otp,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText: 'Código de recuperação de senha')),
                  _button('Recuperar senha',
                      () => runtime.auth.requestReset(_email.text),
                      success:
                          'Se houver uma conta habilitada, confira o código de recuperação no seu e-mail.'),
                  _button(
                      'Definir nova senha com código',
                      () => runtime.auth
                          .reset(_email.text, _otp.text, _password.text),
                      success:
                          'Solicitação de troca de senha concluída. Entre novamente.'),
                ])),
            if (runtime.auth.user != null)
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('Conta: ${runtime.auth.user!['email'] ?? ''}'),
                    if (runtime.auth.user?['emailVerified'] != true)
                      Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          title: const Text('Verificação para acesso profissional'),
                          children: [
                            _button('Enviar código de verificação',
                                () => runtime.auth.resend(runtime.auth.user!['email'] as String),
                                success: 'Confira seu e-mail.'),
                            TextField(
                              controller: _professionalOtp,
                              decoration: const InputDecoration(labelText: 'Código de verificação profissional'),
                            ),
                            _button('Verificar e-mail profissional', () async {
                              await runtime.auth.verify(runtime.auth.user!['email'] as String, _professionalOtp.text);
                              await _load();
                            }, success: 'E-mail verificado.'),
                          ],
                        ),
                      ),
                    if (_profile != null) ...[
                      Text('Perfil institucional: ${_profile!['role']}'),
                      Text(
                          'UBS aprovada: ${_profile!['ubs_code'] ?? 'ainda sem vínculo'}'),
                    ],
                    _button('Atualizar situação', _load,
                        success: 'Situação atualizada.'),
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
                          });
                      }
                    },
                        success:
                            'Sessão encerrada. O plano offline permanece neste aparelho.'),
                  ])),
            if (_profile?['role'] == 'patient' && runtime.auth.signedIn) ...[
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Sincronização online opcional',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text(
                        'Você pode continuar sem sincronizar. O envio pode incluir informações pessoais e de saúde deste plano e ficará associado à conta institucional acima.'),
                    Material(
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
                    TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.privacy),
                        child: const Text('Ler documentos de privacidade')),
                    _button('Registrar consentimento online', () async {
                      await runtime.sync.grantConsent(_choices);
                      await _load();
                    }, success: 'Consentimento online registrado.'),
                    Text(
                        'Consentimento no servidor: ${runtime.sync.consentActive ? 'ativo' : 'não ativo'}'),
                    _button('Salvar e sincronizar meu plano', () async {
                      await runtime.sync
                          .synchronize(await StorageService().loadAnswers());
                      await _load();
                    },
                        success:
                            'Plano salvo e sincronizado. Revisão confirmada pelo servidor.'),
                    _button('Tentar envio pendente novamente', () async {
                      await runtime.sync.retryPending();
                      await _load();
                    },
                        success:
                            'Envio pendente verificado. Confira a lista de planos.'),
                    _button('Retirar consentimento online', () async {
                      if (!await _confirm('Retirar consentimento online?',
                          'Novos envios serão bloqueados. Isso não apaga automaticamente os registros já enviados.'))
                        throw _ActionCancelled();
                      await runtime.sync.withdrawConsent();
                      await _load();
                    }, success: 'Consentimento online retirado.'),
                    if (runtime.sync.pending)
                      const Text(
                          'Há um envio pendente. Seus dados locais permanecem salvos.'),
                  ])),
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text('Planos da sua conta'),
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
              SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const Text(
                        'Solicitar vínculo à UBS — depende de aprovação institucional'),
                    DropdownButtonFormField<String>(
                        initialValue: _ubs,
                        decoration:
                            const InputDecoration(labelText: 'UBS solicitada'),
                        items: _units
                            .map((u) => DropdownMenuItem(
                                value: u['code'] as String,
                                child: Text('${u['name']}')))
                            .toList(),
                        onChanged:
                            _busy ? null : (v) => setState(() => _ubs = v)),
                    _button('Solicitar vínculo à UBS', () async {
                      if (_ubs == null) throw const NeonApiException(400);
                      await runtime.api
                          .requestPatientUbs(_ubs!, newOperationId());
                      await _load();
                    },
                        success:
                            'Solicitação enviada. A escolha não concede vínculo automaticamente.'),
                    for (final request in _requests)
                      Text(
                          'Solicitação ${request['ubs_code']}: ${request['status']}'),
                  ])),
            ],
            if (runtime.auth.signedIn && _profile != null)
              _button('Área profissional e administrativa', () async {
                await Navigator.pushNamed(context, AppRoutes.ubs);
              }),
          ],
        ])));
  }
}
