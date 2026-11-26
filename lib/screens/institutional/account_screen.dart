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
  final _choices = <String, bool>{};
  InstitutionalRuntime? get _runtime =>
      widget.runtime ?? InstitutionalRuntime.instance;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _plans = [], _units = [], _requests = [];
  bool _busy = false;
  String? _message, _ubs, _loadedSubject;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run(_load);
  }

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
        _runtime?.auth.verified == true) {
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
        if (!runtime.auth.verified) {
          if (mounted)
            setState(() => _message =
                'Confirme seu e-mail para habilitar os serviços institucionais.');
          return;
        }
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
                  TextField(
                      controller: _otp,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                          labelText:
                              'Código de verificação recebido por e-mail')),
                  _button(
                      'Criar conta',
                      () => runtime.auth
                          .signup(_name.text, _email.text, _password.text),
                      success:
                          'Cadastro solicitado. Confirme o código enviado ao seu e-mail.'),
                  _button('Confirmar e-mail',
                      () => runtime.auth.verify(_email.text, _otp.text),
                      success: 'E-mail confirmado. Entre para continuar.'),
                  _button(
                      'Reenviar código', () => runtime.auth.resend(_email.text),
                      success:
                          'Solicitação de código concluída. Confira seu e-mail.'),
                  _button('Entrar', () async {
                    await runtime.auth.login(_email.text, _password.text);
                    await _load();
                  },
                      success:
                          'Sessão verificada. Confira a situação do perfil abaixo.'),
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
                    Text(
                        'E-mail ${runtime.auth.verified ? 'verificado' : 'aguardando confirmação'}'),
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
            if (_profile?['role'] == 'patient' && runtime.auth.verified) ...[
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
            if (runtime.auth.verified && _profile != null)
              _button('Área profissional e administrativa', () async {
                await Navigator.pushNamed(context, AppRoutes.ubs);
              }),
          ],
        ])));
  }
}
