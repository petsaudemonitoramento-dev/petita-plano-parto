import 'package:flutter/material.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../services/storage_service.dart';

/// Impede acesso por links diretos e pelos botões da tela inicial antes do aceite.
class ConsentRequiredScreen extends StatefulWidget {
  const ConsentRequiredScreen({super.key, required this.child});
  final Widget child;

  @override
  State<ConsentRequiredScreen> createState() => _ConsentRequiredScreenState();
}

class _ConsentRequiredScreenState extends State<ConsentRequiredScreen> {
  late Future<bool> _consentStatus;

  @override
  void initState() {
    super.initState();
    _consentStatus = StorageService().hasConsent();
  }

  void _onAccepted() {
    setState(() => _consentStatus = Future<bool>.value(true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _consentStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) return widget.child;
        return ConsentGateScreen(onAccepted: _onAccepted);
      },
    );
  }
}

class ConsentGateScreen extends StatefulWidget {
  const ConsentGateScreen({super.key, required this.onAccepted});
  final VoidCallback onAccepted;

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  final _storage = StorageService();
  bool _science = false;
  bool _terms = false;
  bool _privacy = false;
  bool _healthData = false;
  bool _responsibility = false;
  bool _saving = false;
  String? _error;

  bool get _canContinue =>
      _science && _terms && _privacy && _healthData && _responsibility;

  Future<void> _accept() async {
    if (!_canContinue || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _storage.saveConsentAcknowledgements();
      if (mounted) widget.onAccepted();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível registrar seu aceite. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _checkTile({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    String? route,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: _saving ? null : onChanged,
        activeColor: AppColors.primaryPink,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: route == null
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, route),
                  child: const Text('Ler documento completo'),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de começar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    children: [
                      Center(child: Image.asset('assets/images/petita.png', height: 110)),
                      const SizedBox(height: 6),
                      const Text(
                        'Sua voz faz parte do seu plano de parto',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'A Petita ajuda você a registrar suas escolhas e preferências. Elas devem ser consideradas pela equipe de saúde quando clinicamente possíveis. O plano não garante um procedimento e não substitui o cuidado profissional.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Em caso de urgência ou sinais de alerta, procure atendimento imediatamente. O canal de dúvidas não é um serviço de emergência.',
                        style: TextStyle(color: AppColors.petDarkBlue, fontWeight: FontWeight.w700, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      _checkTile(
                        title: 'Li e compreendi o Termo de Ciência Inicial e sei que o plano registra minhas preferências, sem substituir as decisões compartilhadas com a equipe.',
                        value: _science,
                        onChanged: (v) => setState(() => _science = v ?? false),
                        route: AppRoutes.initialScience,
                      ),
                      _checkTile(
                        title: 'Li e aceito os Termos de Uso da Petita.',
                        value: _terms,
                        onChanged: (v) => setState(() => _terms = v ?? false),
                        route: AppRoutes.terms,
                      ),
                      _checkTile(
                        title: 'Li a Política de Privacidade.',
                        value: _privacy,
                        onChanged: (v) => setState(() => _privacy = v ?? false),
                        route: AppRoutes.privacy,
                      ),
                      _checkTile(
                        title: 'Concordo com o tratamento das informações pessoais e de saúde que eu preencher, para construir e guardar meu plano neste dispositivo.',
                        value: _healthData,
                        onChanged: (v) => setState(() => _healthData = v ?? false),
                      ),
                      _checkTile(
                        title: 'Estou ciente de que a Petita é educativa, pode cometer erros e não substitui atendimento profissional nem situações de urgência.',
                        value: _responsibility,
                        onChanged: (v) => setState(() => _responsibility = v ?? false),
                        route: AppRoutes.responsibility,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _canContinue && !_saving ? _accept : null,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Concordar e começar'),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.maybePop(context),
                        child: const Text('Voltar sem aceitar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
