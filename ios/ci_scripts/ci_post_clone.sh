#!/bin/sh
# Prepare generated Flutter iOS files before Xcode Cloud resolves packages.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}
FLUTTER_VERSION=${FLUTTER_VERSION:-3.47.2}
FLUTTER_ROOT=${FLUTTER_ROOT:-"$HOME/flutter-$FLUTTER_VERSION"}

cd "$REPOSITORY_ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
    echo "Installing Flutter $FLUTTER_VERSION..."
    git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
  fi
  PATH="$FLUTTER_ROOT/bin:$PATH"
  export PATH
fi

echo "Using $(flutter --version | head -n 1)"
flutter config --enable-swift-package-manager
flutter precache --ios
flutter pub get

# Generates ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage,
# which Xcode Cloud tries to resolve before running the archive action.
flutter build ios --release --config-only --no-codesign

# The workspace also contains CocoaPods dependencies that aren't committed.
if [ -f ios/Podfile ]; then
  (cd ios && pod install)
fi

test -f ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift

echo "Xcode Cloud post-clone preparation complete."
