class BuildMode {
  // Internal APKs never initialize or contact the legacy backend.
  static const internalTest = bool.fromEnvironment('PETITA_INTERNAL_TEST');
}
