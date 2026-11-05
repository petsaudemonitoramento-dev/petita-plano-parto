import 'dart:async';

/// Backend availability must never prevent access to local plans and PDFs.
Future<bool> initializeOnlineSafely(
  Future<void> Function() initialize, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    await initialize().timeout(timeout);
    return true;
  } catch (_) {
    // Do not log exception payloads: providers may include tokens or identifiers.
    return false;
  }
}
