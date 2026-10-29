import 'package:flutter/material.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'screens/about/about_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/birth_plan/birth_plan_summary_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/consent/consent_gate_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/questions/my_questions_screen.dart';
import 'screens/terms/terms_screen.dart';
import 'screens/ubs/ubs_team_screen.dart';
import 'config/build_mode.dart';

class PlanoPartoPetSaudeApp extends StatelessWidget {
  const PlanoPartoPetSaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plano de Parto PET Saúde',
      theme: AppTheme.light,
      builder: (context, child) => BuildMode.internalTest
          ? Banner(
              message: 'TESTE INTERNO',
              location: BannerLocation.topEnd,
              color: Colors.deepOrange,
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.chat: (_) => const ConsentRequiredScreen(child: ChatScreen()),
        AppRoutes.summary: (_) =>
            const ConsentRequiredScreen(child: BirthPlanSummaryScreen()),
        AppRoutes.terms: (_) => const TermsScreen(
            initialAsset: 'assets/legal/termos_uso.md', title: 'Termos de Uso'),
        AppRoutes.initialScience: (_) => const TermsScreen(
            initialAsset: 'assets/legal/termo_ciencia_inicial.md',
            title: 'Ciência inicial'),
        AppRoutes.privacy: (_) => const TermsScreen(
            initialAsset: 'assets/legal/politica_privacidade.md',
            title: 'Política de Privacidade'),
        AppRoutes.responsibility: (_) => const TermsScreen(
            initialAsset: 'assets/legal/aviso_responsabilidade.md',
            title: 'Responsabilidade em Saúde'),
        AppRoutes.about: (_) => const AboutScreen(),
        AppRoutes.profile: (_) =>
            const ConsentRequiredScreen(child: ProfileScreen()),
        AppRoutes.ubs: (_) => const UbsTeamScreen(),
        AppRoutes.admin: (_) => const AdminScreen(),
        AppRoutes.myQuestions: (_) =>
            const ConsentRequiredScreen(child: MyQuestionsScreen()),
      },
    );
  }
}
