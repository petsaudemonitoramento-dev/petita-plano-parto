import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/config/app_routes.dart';
import 'package:plano_parto_pet_saude/screens/home/home_screen.dart';

void main() {
  testWidgets('account entry is directly visible above the home hero on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: const HomeScreen(),
      routes: {
        AppRoutes.institutional: (context) {
          expect(ModalRoute.of(context)?.settings.arguments, 'login');
          return const Scaffold(body: Text('Tela de conta'));
        },
      },
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final account = find.text('Minha conta');
    expect(account, findsOneWidget);
    expect(tester.getRect(account).top, lessThan(240));
    await tester.tap(account);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Tela de conta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
