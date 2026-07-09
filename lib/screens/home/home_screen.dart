import 'package:flutter/material.dart';
import '../../config/app_info.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  bool _hasConsent = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final value = await _storage.hasConsent();
    if (mounted) setState(() => _hasConsent = value);
  }

  Future<void> _startChat() async {
    if (!_hasConsent) {
      final accepted = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ConsentGateScreen()));
      if (accepted != true) return;
      await _loadConsent();
    }
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.chat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset('assets/images/pet_saude_avatar.png', height: 52),
                      Image.asset('assets/images/ufcg_logo.png', height: 58),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    child: Column(
                      children: [
                        Image.asset('assets/images/petita.png', height: 220),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue),
                            children: [
                              TextSpan(text: 'Plano de Parto\n'),
                              TextSpan(text: 'PET ', style: TextStyle(color: AppColors.petOrange)),
                              TextSpan(text: 'Saúde', style: TextStyle(color: AppColors.petBlue)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Construa seu plano de parto com informação, acolhimento e cuidado. A Petita vai te guiar passo a passo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textPrimary, height: 1.35),
                        ),
                        const SizedBox(height: 18),
                        AppButton(label: 'Começar com a Petita', icon: Icons.favorite, onPressed: _startChat),
                        const SizedBox(height: 10),
                        AppButton(label: 'Ver meu plano', icon: Icons.description_outlined, outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.summary)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: AppButton(label: 'Termos', outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.terms))),
                      const SizedBox(width: 10),
                      Expanded(child: AppButton(label: 'Equipe UBS', outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.ubs))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton(label: 'Sobre o aplicativo', outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.about)),
                  const SizedBox(height: 20),
                  Text('${AppInfo.institution} • ${AppInfo.version} • Desenvolvido por ${AppInfo.developer}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.petDarkBlue)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConsentGateScreen extends StatefulWidget {
  const ConsentGateScreen({super.key});

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _responsibility = false;
  final _storage = StorageService();

  bool get _canContinue => _terms && _privacy && _responsibility;

  Future<void> _accept() async {
    await _storage.setConsentAccepted(true);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consentimento')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Antes de começar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.petDarkBlue)),
              const SizedBox(height: 10),
              const Text('Leia e confirme os termos para usar o app com segurança. Este aplicativo é educativo e não substitui atendimento profissional.'),
              const SizedBox(height: 20),
              _checkTile('Li e aceito os Termos de Uso', _terms, (v) => setState(() => _terms = v ?? false), AppRoutes.terms),
              _checkTile('Li a Política de Privacidade', _privacy, (v) => setState(() => _privacy = v ?? false), AppRoutes.privacy),
              _checkTile('Entendo a isenção de responsabilidade em saúde', _responsibility, (v) => setState(() => _responsibility = v ?? false), AppRoutes.responsibility),
              const Spacer(),
              AppButton(label: 'Aceitar e continuar', onPressed: _canContinue ? _accept : () {}, icon: Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkTile(String title, bool value, ValueChanged<bool?> onChanged, String route) {
    return Card(
      color: Colors.white,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryPink,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: TextButton(onPressed: () => Navigator.pushNamed(context, route), child: const Text('Ver documento')),
      ),
    );
  }
}
