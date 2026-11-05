import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plano_parto_pet_saude/services/app_bootstrap.dart';
import 'package:plano_parto_pet_saude/services/supabase_service.dart';

void main() {
  test('online initialization success remains available', () async {
    expect(await initializeOnlineSafely(() async {}), isTrue);
  });
  test('unavailable backend does not throw into offline startup', () async {
    expect(
        await initializeOnlineSafely(
            () async => throw StateError('synthetic failure')),
        isFalse);
    expect(SupabaseService().isLoggedIn, isFalse);
  });
  test('backend initialization has a bounded waiting time', () async {
    final pending = Completer<void>();
    expect(
        await initializeOnlineSafely(() => pending.future,
            timeout: const Duration(milliseconds: 1)),
        isFalse);
    pending.complete();
  });
}
