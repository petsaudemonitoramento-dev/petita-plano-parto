import 'package:flutter/material.dart';
import '../../config/app_info.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/petita_animated_mascot.dart';

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
      backgroundColor: const Color(0xFFFFFAFB),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Image.asset('assets/images/pet_saude_avatar.png', height: 42),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF8DAE3))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_rounded, color: Color(0xFFF15A82), size: 15),
                  SizedBox(width: 6), Text('Feita com cuidado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF29435C))),
                ])),
              Image.asset('assets/images/ufcg_logo.png', height: 42),
            ]),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFFFEDF2), Color(0xFFFFF8FA), Colors.white]),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFFFE0E8)),
                boxShadow: [BoxShadow(color: const Color(0xFFE98BA4).withOpacity(0.13), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: Column(children: [
                const PetitaAnimatedMascot(size: 170),
                const SizedBox(height: 2),
                const Text('OLÁ, EU SOU A PETITA', style: TextStyle(fontSize: 11, letterSpacing: 2.1,
                  fontWeight: FontWeight.w900, color: Color(0xFFE85A81))),
                const SizedBox(height: 10),
                const Text('Seu plano de parto,\ndo seu jeito.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 31, height: 1.12, fontWeight: FontWeight.w900, color: Color(0xFF1E3B55))),
                const SizedBox(height: 12),
                const Text('Vamos conversar sobre suas escolhas para o nascimento do seu bebê? Eu explico tudo, passo a passo, sem palavras difíceis.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.48, color: Color(0xFF4D6070))),
                const SizedBox(height: 22),
                AppButton(label: 'Começar meu plano', icon: Icons.arrow_forward_rounded, onPressed: _startChat),
                const SizedBox(height: 12),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline, size: 15, color: Color(0xFF587284)),
                  SizedBox(width: 5),
                  Flexible(child: Text('Suas escolhas ficam salvas neste dispositivo', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF587284)))),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Seu espaço de cuidado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E3B55))),
            const SizedBox(height: 12),
            _HomeAction(icon: Icons.description_outlined, title: 'Meu plano de parto',
              subtitle: 'Veja suas escolhas e gere o PDF', onTap: () => Navigator.pushNamed(context, AppRoutes.summary)),
            const SizedBox(height: 10),
            _HomeAction(icon: Icons.person_outline_rounded, title: 'Meu perfil',
              subtitle: 'Informações da gestante', onTap: () => Navigator.pushNamed(context, AppRoutes.profile)),
            const SizedBox(height: 10),
            _HomeAction(icon: Icons.chat_bubble_outline_rounded, title: 'Minhas dúvidas',
              subtitle: 'Informações e perguntas frequentes', onTap: () => Navigator.pushNamed(context, AppRoutes.myQuestions)),
            const SizedBox(height: 18),
            Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
              TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.terms), child: const Text('Termos')),
              TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.about), child: const Text('Sobre')),
              TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.ubs), child: const Text('Equipe UBS')),
              TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.admin), child: const Text('Administração')),
            ]),
            TextButton.icon(onPressed: _removeConsent, icon: const Icon(Icons.privacy_tip_outlined, size: 17),
              label: const Text('Retirar aceite e apagar dados locais')),
            const SizedBox(height: 12),
            Text('${AppInfo.institution} • ${AppInfo.version} • Desenvolvido por ${AppInfo.developer}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF687C8A))),
          ]),
        ),
      ))),
    );
  }
}


class _HomeAction extends StatelessWidget {
  const _HomeAction({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(20),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF5E3E8))),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFFFEAF0), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFFE85880))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E3B55))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF637584))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFE85880)),
        ]),
      )),
  );
}
