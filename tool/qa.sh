#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$FLUTTER_BIN" && -x /home/ipsoum/development/flutter/bin/flutter ]]; then
  FLUTTER_BIN=/home/ipsoum/development/flutter/bin/flutter
fi
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "Flutter est introuvable. Définissez FLUTTER_BIN=/chemin/vers/flutter." >&2
  exit 1
fi
DART_BIN="${DART_BIN:-$(dirname "$FLUTTER_BIN")/dart}"
ADB_BIN="${ADB_BIN:-$(command -v adb || true)}"
if [[ -z "$ADB_BIN" && -x /home/ipsoum/Android/Sdk/platform-tools/adb ]]; then
  ADB_BIN=/home/ipsoum/Android/Sdk/platform-tools/adb
fi

cd "$PROJECT_ROOT"

unit_tests() {
  "$FLUTTER_BIN" pub get --offline
  "$DART_BIN" format --output=none --set-exit-if-changed lib test integration_test
  "$FLUTTER_BIN" analyze
  "$FLUTTER_BIN" test
}

static_security() {
  systemctl --user start podman.socket
  podman run --rm --security-opt label=disable \
    -v "$PROJECT_ROOT:/src:ro" -w /src \
    docker.io/semgrep/semgrep:latest \
    semgrep scan --config auto --error --no-git-ignore \
    --exclude .dart_tool --exclude build --exclude ios/Pods --exclude android/.gradle
}

build_apk() {
  "$FLUTTER_BIN" build apk --debug --flavor qa --no-pub
}

build_release() {
  "$PROJECT_ROOT/tool/build-release.sh"
}

integration_tests() {
  local device_id="$1"
  local qa_package="fr.fleurapp.fleurapp_mobile.qa"

  set +e
  "$FLUTTER_BIN" test integration_test/app_full_test.dart \
    --flavor qa -d "$device_id"
  local test_status=$?
  set -e

  if [[ -n "$ADB_BIN" ]]; then
    "$ADB_BIN" -s "$device_id" uninstall "$qa_package" >/dev/null 2>&1 || true
  fi
  return "$test_status"
}

case "${1:-all}" in
  unit)
    unit_tests
    ;;
  security)
    static_security
    ;;
  integration)
    if [[ $# -lt 2 ]]; then
      echo "Usage : tool/qa.sh integration ID_TELEPHONE" >&2
      exit 2
    fi
    integration_tests "$2"
    ;;
  apk)
    build_apk
    ;;
  release)
    build_release
    ;;
  all)
    unit_tests
    static_security
    build_apk
    ;;
  *)
    echo "Usage : tool/qa.sh [unit|security|integration ID_TELEPHONE|apk|release|all]" >&2
    exit 2
    ;;
esac
