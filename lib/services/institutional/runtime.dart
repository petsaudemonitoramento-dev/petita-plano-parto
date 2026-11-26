import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config/institutional_config.dart';
import '../neon_api_client.dart';
import 'auth_transport_native.dart'
    if (dart.library.js_interop) 'auth_transport_web.dart' as platform;
import 'institutional_auth.dart';
import 'secret_vault.dart';
import 'plan_sync_controller.dart';

class InstitutionalRuntime {
  static InstitutionalRuntime? instance;
  final InstitutionalAuth auth;
  final NeonApiClient api;
  final PlanSyncController sync;
  InstitutionalRuntime(this.auth, this.api, this.sync);
  static Future<void> initialize() async {
    if (!InstitutionalConfig.configured) return;
    final client = http.Client();
    const vault = DeviceSecretVault();
    final auth = InstitutionalAuth(platform.createAuthTransport(
        Uri.parse(InstitutionalConfig.authUrl), vault, client));
    final api = NeonApiClient(
        origin: Uri.parse(InstitutionalConfig.apiUrl),
        client: client,
        tokenProvider: auth.token);
    final sync = PlanSyncController(api: api, auth: auth, vault: vault);
    instance = InstitutionalRuntime(auth, api, sync);
    // A network/auth error must not prevent offline plans/PDF from opening.
    unawaited(
        auth.restore().catchError((_) {/* Login screen reports retry. */}));
  }
}
