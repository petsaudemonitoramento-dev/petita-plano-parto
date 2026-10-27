import 'package:flutter/material.dart';
import '../../config/app_info.dart';
import '../../config/app_routes.dart';
import '../../services/storage_service.dart';
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
      backgroundColor: const Color(0xFFF9F6FF),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 46, height: 46, padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Image.asset('assets/images/pet_saude_avatar.png')),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PETITA', style: TextStyle(fontSize: 19, letterSpacing: 2, fontWeight: FontWeight.w900, color: Color(0xFF4E237F))),
                Text('Seu espaço de cuidado', style: TextStyle(fontSize: 11, color: Color(0xFF806D98))),
              ])),
              Container(width: 46, height: 46, padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Image.asset('assets/images/ufcg_avatar.png', fit: BoxFit.contain)),
            ]),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF6332AB), Color(0xFF9B4DE0), Color(0xFFF268AA)]),
                borderRadius: BorderRadius.circular(34),
                boxShadow: [BoxShadow(color: const Color(0xFF8C46C9).withAlpha((255 * 0.27).round()),
                  blurRadius: 32, offset: const Offset(0, 15))],
              ),
              child: Stack(children: [
                Positioned(right: -38, top: -38, child: Container(width: 155, height: 155,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha((255 * 0.10).round())))),
                Positioned(left: -50, bottom: 20, child: Container(width: 115, height: 115,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha((255 * 0.08).round())))),
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white.withAlpha((255 * 0.9).round())),
                      const SizedBox(width: 7),
                      const Text('SUA JORNADA COMEÇA AQUI', style: TextStyle(
                        color: Colors.white, fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800)),
                    ]),
                    const PetitaAnimatedMascot(size: 168),
                    const SizedBox(height: 2),
                    const Text('Olá, eu sou a Petita!', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Seu plano de parto,\ncom carinho.', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, height: 1.08, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Um espaço seguro para conhecer suas opções e construir seu plano de parto com carinho.',
                      textAlign: TextAlign.center, style: TextStyle(
                        fontSize: 14, height: 1.5, color: Colors.white.withAlpha((255 * 0.95).round()))),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _startChat,
                      style: FilledButton.styleFrom(backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7133B6),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
                      icon: const Icon(Icons.favorite_rounded, size: 20),
                      label: const Text('Criar meu plano de parto',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    )),
                    const SizedBox(height: 12),
                    const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shield_outlined, color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Flexible(child: Text('Suas escolhas são respeitadas', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12))),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('O que vamos fazer hoje?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF422467))),
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
          border: Border.all(color: const Color(0xFFEDE3F8))),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF2E7FF), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFF8E45CD))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF422467))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF637584))),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFE85880)),
        ]),
      )),
  );
}
