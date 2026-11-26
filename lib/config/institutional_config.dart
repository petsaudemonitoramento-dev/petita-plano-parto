class InstitutionalConfig {
  static const enabled = bool.fromEnvironment('PETITA_NEON_ENABLED');
  static const apiUrl = String.fromEnvironment('PETITA_API_ORIGIN');
  static const authUrl = String.fromEnvironment('PETITA_AUTH_URL');
  static bool get configured {
    final api = Uri.tryParse(apiUrl), auth = Uri.tryParse(authUrl);
    bool safe(Uri? u) =>
        u != null &&
        u.scheme == 'https' &&
        u.hasAuthority &&
        u.userInfo.isEmpty &&
        !u.hasQuery &&
        !u.hasFragment;
    return enabled &&
        safe(api) &&
        (api!.path.isEmpty || api.path == '/') &&
        safe(auth) &&
        auth!.host.endsWith('.neon.tech');
  }
}
