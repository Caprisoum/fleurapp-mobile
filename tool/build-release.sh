#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(dirname "$PROJECT_ROOT")"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
API_BASE_URL="${API_BASE_URL:-https://api.fleurapp.fr}"
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
"$FLUTTER_BIN" clean
"$FLUTTER_BIN" pub get --offline
"$FLUTTER_BIN" build apk --config-only --flavor production \
  --dart-define="API_BASE_URL=${API_BASE_URL%/}" \
  --dart-define="ALLOW_SERVER_CONFIGURATION=false"
"$FLUTTER_BIN" build apk --release --flavor production --split-per-abi --no-pub \
  --dart-define="API_BASE_URL=${API_BASE_URL%/}" \
  --dart-define="ALLOW_SERVER_CONFIGURATION=false"

mapfile -t RELEASE_APKS < <(find build/app/outputs/flutter-apk -maxdepth 1 -type f -name 'app-*-production-release.apk' -print | sort)
if [[ ${#RELEASE_APKS[@]} -eq 0 ]]; then
  echo "Aucun APK release n’a été produit." >&2
  exit 1
fi

for apk in "${RELEASE_APKS[@]}"; do
  "$APKSIGNER_BIN" verify --verbose --print-certs "$apk"
done

ARM64_APK="build/app/outputs/flutter-apk/app-arm64-v8a-production-release.apk"
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

APK_SHA256="$(sha256sum "$FINAL_APK" | awk '{print $1}')"
BUILD_COMMIT="$(git rev-parse HEAD)"
BUILD_BRANCH="$(git rev-parse --abbrev-ref HEAD | sed 's/["\\]/_/g')"
if [[ -n "$(git status --porcelain)" ]]; then BUILD_DIRTY=true; else BUILD_DIRTY=false; fi
BUILD_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BUILD_MANIFEST="${FINAL_APK%.apk}.build.json"
printf '%s\n' \
  '{' \
  '  "schemaVersion": 1,' \
  "  \"generatedAt\": \"${BUILD_TIMESTAMP}\"," \
  "  \"apk\": \"$(basename "$FINAL_APK")\"," \
  "  \"apkSha256\": \"${APK_SHA256}\"," \
  "  \"versionName\": \"${VERSION_NAME}\"," \
  "  \"versionCode\": \"${VERSION_CODE}\"," \
  "  \"gitCommit\": \"${BUILD_COMMIT}\"," \
  "  \"gitBranch\": \"${BUILD_BRANCH}\"," \
  "  \"gitDirty\": ${BUILD_DIRTY}," \
  "  \"apiOrigin\": \"${API_BASE_URL%/}\"" \
  '}' > "$BUILD_MANIFEST"
chmod 600 "$BUILD_MANIFEST"

echo
echo "APK release signé et vérifié :"
ls -lh "$FINAL_APK"
sha256sum "$FINAL_APK"
echo "Copie stable : $LATEST_APK"
echo "Attestation de build : $BUILD_MANIFEST"
