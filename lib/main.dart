import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/institutional/secret_vault.dart';
import 'services/institutional/protected_patient_store.dart';
import 'services/institutional/runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The institutional candidate never initializes/contact the legacy Supabase.
  runApp(const _ProtectionBootstrap());
}

class _ProtectionBootstrap extends StatefulWidget {
  const _ProtectionBootstrap();
  @override
  State<_ProtectionBootstrap> createState() => _ProtectionBootstrapState();
}

class _ProtectionBootstrapState extends State<_ProtectionBootstrap> {
  Future<void>? _work;
  late Future<void> _visible;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _initialize() async {
    StorageService.protectionRequired = true;
    final store = ProtectedPatientStore(
        const DeviceSecretVault(), await SharedPreferences.getInstance());
    await store.initialize();
    StorageService.protectedStore = store;
    await InstitutionalRuntime.initialize();
  }

  void _start() {
    // Retry shares an unfinished operation; it must not race key creation.
    _work ??= _initialize().catchError((Object error, StackTrace stack) {
      _work = null;
      Error.throwWithStackTrace(error, stack);
    });
    _visible = _work!.timeout(const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
      future: _visible,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) return const PlanoPartoPetSaudeApp();
        return MaterialApp(
            home: Scaffold(
                body: SafeArea(
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Petita',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  if (snapshot.hasError) ...[
                                    const Text(
                                        'Não foi possível abrir a proteção local. Desbloqueie o aparelho e tente novamente. Os dados existentes foram preservados.'),
                                    FilledButton(
                                        onPressed: () => setState(_start),
                                        child: const Text('Tentar novamente')),
                                  ] else
                                    const CircularProgressIndicator(
                                        semanticsLabel:
                                            'Preparando proteção local'),
                                ]))))));
      });
}
