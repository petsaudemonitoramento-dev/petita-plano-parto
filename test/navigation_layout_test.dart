import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/app.dart';
import 'package:plano_parto_pet_saude/config/app_routes.dart';
import 'package:plano_parto_pet_saude/models/user_profile.dart';
import 'package:plano_parto_pet_saude/screens/about/about_screen.dart';
import 'package:plano_parto_pet_saude/screens/admin/admin_screen.dart';
import 'package:plano_parto_pet_saude/screens/birth_plan/birth_plan_summary_screen.dart';
import 'package:plano_parto_pet_saude/screens/chat/chat_screen.dart';
import 'package:plano_parto_pet_saude/screens/consent/consent_gate_screen.dart';
import 'package:plano_parto_pet_saude/screens/home/home_screen.dart';
import 'package:plano_parto_pet_saude/screens/profile/profile_screen.dart';
import 'package:plano_parto_pet_saude/screens/questions/my_questions_screen.dart';
import 'package:plano_parto_pet_saude/screens/terms/terms_screen.dart';
import 'package:plano_parto_pet_saude/screens/ubs/ubs_team_screen.dart';
import 'package:plano_parto_pet_saude/services/birth_plan_flow_service.dart';
import 'package:plano_parto_pet_saude/services/storage_service.dart';

import 'support/offline_helpers.dart';

void main() {
  setUp(resetOfflineState);

  for (final route in [
    AppRoutes.chat,
    AppRoutes.summary,
    AppRoutes.profile,
    AppRoutes.myQuestions
  ]) {
    testWidgets(
        'direct route $route requires consent and returns home without accepting',
        (tester) async {
      setViewport(tester, const Size(800, 1200));
      await tester.pumpWidget(const PlanoPartoPetSaudeApp());
      await tester.pump(const Duration(seconds: 1));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.byType(ConsentGateScreen), findsOneWidget);
      await tester.tap(find.text('Voltar sem aceitar'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await StorageService().hasConsent(), isFalse);
    });
  }

  testWidgets(
      'legal document opens and returns without losing checked acknowledgements',
      (tester) async {
    setViewport(tester, const Size(800, 1200));
    await tester.pumpWidget(const PlanoPartoPetSaudeApp());
    await tester.pump(const Duration(seconds: 1));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.profile);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.ensureVisible(find.text('Ler documento completo').first);
    await tester.tap(find.text('Ler documento completo').first);
    await tester.pumpAndSettle();
    expect(find.byType(TermsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    expect(await StorageService().hasConsent(), isFalse);
  });

  testWidgets('all public routes and consented patient routes can return home',
      (tester) async {
    setViewport(tester, const Size(1000, 1600));
    await StorageService().saveConsentAcknowledgements();
    await tester.pumpWidget(const PlanoPartoPetSaudeApp());
    await tester.pump(const Duration(seconds: 1));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    final destinations = <String, Type>{
      AppRoutes.chat: ChatScreen,
      AppRoutes.summary: BirthPlanSummaryScreen,
      AppRoutes.profile: ProfileScreen,
      AppRoutes.myQuestions: MyQuestionsScreen,
      AppRoutes.about: AboutScreen,
      AppRoutes.ubs: UbsTeamScreen,
      AppRoutes.admin: AdminScreen,
      AppRoutes.terms: TermsScreen,
      AppRoutes.initialScience: TermsScreen,
      AppRoutes.privacy: TermsScreen,
      AppRoutes.responsibility: TermsScreen,
    };
    for (final entry in destinations.entries) {
      nav.pushNamed(entry.key);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      if (entry.key == AppRoutes.chat) {
        await tester.tap(find.byIcon(Icons.arrow_back));
      } else {
        await tester.pageBack();
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(HomeScreen), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets(
      'locally forged admin profile does not unlock remote administration',
      (tester) async {
    setViewport(tester, const Size(1000, 1600));
    await StorageService().saveProfile(UserProfile(
        id: 'synthetic',
        name: 'Sintetica',
        email: 'test@example.invalid',
        role: 'admin',
        createdAt: DateTime(2026)));
    await tester.pumpWidget(const MaterialApp(home: AdminScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);
  });

  testWidgets(
      'summary empty state hides exports and clearing a populated plan recovers it',
      (tester) async {
    setViewport(tester, const Size(1000, 1600));
    await StorageService().saveAnswers(
        syntheticAnswers(await BirthPlanFlowService().loadQuestions()));
    await tester.pumpWidget(const MaterialApp(home: BirthPlanSummaryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Gerar PDF — declaração para assinatura'), findsOneWidget);
    await tester.ensureVisible(find.text('Limpar plano local'));
    await tester.tap(find.text('Limpar plano local'));
    await tester.pumpAndSettle();
    expect(await StorageService().loadAnswers(), isEmpty);
    expect(find.textContaining('Você ainda não construiu seu plano'),
        findsOneWidget);
    expect(find.text('Gerar PDF — declaração para assinatura'), findsNothing);
  });

  testWidgets(
      'consent withdrawal can be cancelled and confirmation clears data and closes access',
      (tester) async {
    setViewport(tester, const Size(800, 1200));
    final storage = StorageService();
    await storage.saveConsentAcknowledgements();
    await storage.saveAnswers(
        syntheticAnswers(await BirthPlanFlowService().loadQuestions()));
    await storage.saveProfile(UserProfile(
        id: 'synthetic',
        name: 'Sintetica',
        email: 'test@example.invalid',
        role: 'patient',
        createdAt: DateTime(2026)));
    await tester.pumpWidget(const PlanoPartoPetSaudeApp());
    await tester.pump(const Duration(seconds: 1));
    final withdraw = find.text('Retirar aceite e apagar dados locais');
    await tester.ensureVisible(withdraw);
    await tester.tap(withdraw);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await storage.hasConsent(), isTrue);
    expect(await storage.loadAnswers(), hasLength(31));
    await tester.tap(withdraw);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Retirar aceite e apagar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(await storage.hasConsent(), isFalse);
    expect(await storage.loadAnswers(), isEmpty);
    expect(await storage.loadProfile(), isNull);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.chat);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
  });

  testWidgets(
      'declining cloud synchronization preserves the complete offline plan',
      (tester) async {
    setViewport(tester, const Size(1000, 1600));
    await StorageService().saveAnswers(
        syntheticAnswers(await BirthPlanFlowService().loadQuestions()));
    await tester.pumpWidget(const MaterialApp(home: BirthPlanSummaryScreen()));
    await tester.pumpAndSettle();
    final sync = find.text('Sincronizar plano online');
    await tester.ensureVisible(sync);
    await tester.tap(sync);
    await tester.pumpAndSettle();
    expect(
        find.text('Sincronizar dados com o serviço online?'), findsOneWidget);
    await tester.tap(find.text('Manter só neste dispositivo'));
    await tester.pumpAndSettle();
    expect(await StorageService().loadAnswers(), hasLength(31));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 900)
  ]) {
    testWidgets(
        'offline screens have no layout exceptions at ${size.width}x${size.height}',
        (tester) async {
      setViewport(tester, size);
      final screens = <Widget>[
        const HomeScreen(),
        const ConsentGateScreen(onAccepted: _accepted),
        const ChatScreen(),
        const ProfileScreen(),
        const AboutScreen(),
        const BirthPlanSummaryScreen(),
        const UbsTeamScreen(),
        const AdminScreen(),
        const MyQuestionsScreen(),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(home: screen));
        // Home has a perpetual decorative animation; do not pumpAndSettle it.
        if (screen is HomeScreen) {
          await tester.pump(const Duration(seconds: 1));
        } else {
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull,
            reason: '${screen.runtimeType} at $size');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }
}

void _accepted() {}
