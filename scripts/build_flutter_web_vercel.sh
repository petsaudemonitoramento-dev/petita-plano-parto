#!/usr/bin/env bash
# Build da demonstracao Web da Petita, sem interferir no GitHub Pages nem no APK.
set -euo pipefail

FLUTTER_SDK_DIR="${TMPDIR:-/tmp}/petita-flutter-3.44.0"
if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  git clone --quiet --depth 1 --branch 3.44.0 \
    https://github.com/flutter/flutter.git "$FLUTTER_SDK_DIR"
fi
export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test/chat_responsive_test.dart test/chat_flow_test.dart test/consultation_offline_test.dart --reporter expanded
flutter build web --release --base-href "/" --pwa-strategy=none \
  --no-wasm-dry-run --dart-define=PETITA_INTERNAL_TEST=true --no-pub
test -s build/web/index.html
echo "PREVIEW_WEB_OK: build/web/index.html"
