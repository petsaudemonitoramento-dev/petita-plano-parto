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
  void _startChat() {
    Navigator.pushNamed(context, AppRoutes.chat);
  }

  Future<void> _removeConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar aceite e apagar dados locais?'),
        content: const Text(
          'O perfil e as respostas do Plano de Parto salvos neste dispositivo serão apagados. '
          'Será necessário aceitar novamente os termos para preencher o aplicativo. '
          'Isso não apaga dados que já foram sincronizados com serviços online.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar aceite e apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService().revokeConsentAndClearPatientData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aceite retirado e dados locais do plano e perfil apagados.')),
    );
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
                        AppButton(label: 'Perfil da gestante', icon: Icons.person_outline, outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.profile)),
                        const SizedBox(height: 10),
                        AppButton(label: 'Ver meu plano', icon: Icons.description_outlined, outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.summary)),
                        const SizedBox(height: 10),
                        AppButton(label: 'Minhas dúvidas', icon: Icons.forum_outlined, outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.myQuestions)),
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
                  Row(
                    children: [
                      Expanded(child: AppButton(label: 'Admin', outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.admin))),
                      const SizedBox(width: 10),
                      Expanded(child: AppButton(label: 'Sobre', outlined: true, onPressed: () => Navigator.pushNamed(context, AppRoutes.about))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _removeConsent,
                    icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                    label: const Text('Retirar aceite e apagar dados locais'),
                  ),
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

