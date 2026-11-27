import 'screens/institutional/account_screen.dart';
import 'screens/institutional/area_screen.dart';
import 'package:flutter/material.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'screens/about/about_screen.dart';
import 'screens/birth_plan/birth_plan_summary_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/consent/consent_gate_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/terms/terms_screen.dart';

class PlanoPartoPetSaudeApp extends StatelessWidget {
  const PlanoPartoPetSaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plano de Parto PET Saúde',
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.chat: (_) => const ConsentRequiredScreen(child: ChatScreen()),
        AppRoutes.summary: (_) => const ConsentRequiredScreen(child: BirthPlanSummaryScreen()),
        AppRoutes.terms: (_) => const TermsScreen(initialAsset: 'assets/legal/termos_uso.md', title: 'Termos de Uso'),
        AppRoutes.initialScience: (_) => const TermsScreen(initialAsset: 'assets/legal/termo_ciencia_inicial.md', title: 'Ciência inicial'),
        AppRoutes.privacy: (_) => const TermsScreen(initialAsset: 'assets/legal/politica_privacidade.md', title: 'Política de Privacidade'),
        AppRoutes.responsibility: (_) => const TermsScreen(initialAsset: 'assets/legal/aviso_responsabilidade.md', title: 'Responsabilidade em Saúde'),
        AppRoutes.about: (_) => const AboutScreen(),
        AppRoutes.institutional: (_) => const ConsentRequiredScreen(child: InstitutionalAccountScreen()),
        AppRoutes.planSync: (_) => const ConsentRequiredScreen(child: InstitutionalAccountScreen(syncOnly: true)),
        AppRoutes.professionalAccount: (_) => const InstitutionalAccountScreen(professional: true),
        AppRoutes.profile: (_) => const ConsentRequiredScreen(child: ProfileScreen()),
        AppRoutes.ubs: (_) => const InstitutionalAreaScreen(),
        AppRoutes.admin: (_) => const InstitutionalAreaScreen(adminOnly: true),
        AppRoutes.myQuestions: (_) => const ConsentRequiredScreen(child: InstitutionalAreaScreen(myQuestions:true)),
      },
    );
  }
}
