#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(dirname "$PROJECT_ROOT")"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
API_BASE_URL="${API_BASE_URL:-https://fleurapp-ksay.onrender.com}"
KEY_PROPERTIES="${PROJECT_ROOT}/android/key.properties"
RELEASES_DIR="${WORKSPACE_ROOT}/releases"

if [[ -z "$FLUTTER_BIN" && -x /home/ipsoum/development/flutter/bin/flutter ]]; then
  FLUTTER_BIN=/home/ipsoum/development/flutter/bin/flutter
fi
if [[ -z "$FLUTTER_BIN" ]]; then
  echo "Flutter est introuvable. Définissez FLUTTER_BIN=/chemin/vers/flutter." >&2
  exit 1
fi

if [[ ! "$API_BASE_URL" =~ ^https://[^/]+/?$ ]]; then
  echo "API_BASE_URL doit être une origine HTTPS, sans chemin : $API_BASE_URL" >&2
  exit 1
fi

if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "Signature absente. Lancez d’abord : ./tool/setup-release-signing.sh" >&2
  exit 1
fi

KEYSTORE_PATH="$(sed -n 's/^storeFile=//p' "$KEY_PROPERTIES" | tail -n 1)"
if [[ -z "$KEYSTORE_PATH" || ! -f "$KEYSTORE_PATH" ]]; then
  echo "Le keystore référencé par android/key.properties est introuvable." >&2
  exit 1
fi

APKSIGNER_BIN="$(find /home/ipsoum/Android/Sdk/build-tools -mindepth 2 -maxdepth 2 -type f -name apksigner -print 2>/dev/null | sort -V | tail -n 1)"
if [[ -z "$APKSIGNER_BIN" ]]; then
  echo "apksigner est introuvable dans le SDK Android." >&2
  exit 1
fi
AAPT_BIN="$(dirname "$APKSIGNER_BIN")/aapt"
if [[ ! -x "$AAPT_BIN" ]]; then
  echo "aapt est introuvable à côté de apksigner : $AAPT_BIN" >&2
  exit 1
fi

cd "$PROJECT_ROOT"
"$FLUTTER_BIN" pub get --offline
"$FLUTTER_BIN" build apk --release --split-per-abi --no-pub \
  --dart-define="API_BASE_URL=${API_BASE_URL%/}"

mapfile -t RELEASE_APKS < <(find build/app/outputs/flutter-apk -maxdepth 1 -type f -name 'app-*-release.apk' -print | sort)
if [[ ${#RELEASE_APKS[@]} -eq 0 ]]; then
  echo "Aucun APK release n’a été produit." >&2
  exit 1
fi

for apk in "${RELEASE_APKS[@]}"; do
  "$APKSIGNER_BIN" verify --verbose --print-certs "$apk"
done

ARM64_APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [[ ! -f "$ARM64_APK" ]]; then
  echo "L’APK arm64-v8a destiné au Poco est introuvable." >&2
  exit 1
fi

APK_PACKAGE_INFO="$("$AAPT_BIN" dump badging "$ARM64_APK" | sed -n '1p')"
VERSION_NAME="$(sed -n "s/.*versionName='\([^']*\)'.*/\1/p" <<< "$APK_PACKAGE_INFO")"
VERSION_CODE="$(sed -n "s/.*versionCode='\([^']*\)'.*/\1/p" <<< "$APK_PACKAGE_INFO")"
if [[ -z "$VERSION_NAME" || -z "$VERSION_CODE" ]]; then
  echo "Impossible de lire la version Android dans l’APK release." >&2
  exit 1
fi

mkdir -p "$RELEASES_DIR"
FINAL_APK="${RELEASES_DIR}/FleurApp-beta-v${VERSION_NAME}-${VERSION_CODE}-arm64-release.apk"
LATEST_APK="${RELEASES_DIR}/FleurApp-beta-latest-arm64-release.apk"
install -m 644 "$ARM64_APK" "$FINAL_APK"
install -m 644 "$ARM64_APK" "$LATEST_APK"

echo
echo "APK release signé et vérifié :"
ls -lh "$FINAL_APK"
sha256sum "$FINAL_APK"
echo "Copie stable : $LATEST_APK"
