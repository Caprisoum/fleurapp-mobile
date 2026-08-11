#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_ROOT="/home/ipsoum/.sdkman/candidates/java/current"
KEYTOOL_BIN="${KEYTOOL_BIN:-${JAVA_ROOT}/bin/keytool}"
CONFIG_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}/fleurapp"
KEYSTORE_PATH="${CONFIG_ROOT}/upload-keystore.jks"
PROPERTIES_PATH="${PROJECT_ROOT}/android/key.properties"
KEY_ALIAS="fleurapp-upload"

if [[ ! -x "$KEYTOOL_BIN" ]]; then
  echo "keytool est introuvable : $KEYTOOL_BIN" >&2
  exit 1
fi

if [[ -e "$KEYSTORE_PATH" || -e "$PROPERTIES_PATH" ]]; then
  echo "Une configuration de signature existe déjà." >&2
  echo "Keystore : $KEYSTORE_PATH" >&2
  echo "Propriétés : $PROPERTIES_PATH" >&2
  echo "Aucun fichier n’a été remplacé." >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "Lancez ce script dans un terminal interactif pour saisir le mot de passe." >&2
  exit 1
fi

echo "Création de l’identité Android de production FleurApp."
echo "Le mot de passe ne sera ni affiché ni enregistré dans Git."
read -r -s -p "Mot de passe de signature (16 caractères minimum) : " FLEURAPP_SIGNING_PASSWORD
echo
read -r -s -p "Confirmez le mot de passe : " FLEURAPP_SIGNING_PASSWORD_CONFIRM
echo

if [[ ${#FLEURAPP_SIGNING_PASSWORD} -lt 16 ]]; then
  echo "Le mot de passe doit contenir au moins 16 caractères." >&2
  exit 1
fi

if [[ "$FLEURAPP_SIGNING_PASSWORD" != "$FLEURAPP_SIGNING_PASSWORD_CONFIRM" ]]; then
  echo "Les deux mots de passe sont différents." >&2
  exit 1
fi

unset FLEURAPP_SIGNING_PASSWORD_CONFIRM
export FLEURAPP_ANDROID_STORE_PASSWORD="$FLEURAPP_SIGNING_PASSWORD"
trap 'unset FLEURAPP_SIGNING_PASSWORD FLEURAPP_ANDROID_STORE_PASSWORD' EXIT

umask 077
mkdir -p "$CONFIG_ROOT"

"$KEYTOOL_BIN" -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -storetype PKCS12 \
  -storepass:env FLEURAPP_ANDROID_STORE_PASSWORD \
  -keypass:env FLEURAPP_ANDROID_STORE_PASSWORD \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -alias "$KEY_ALIAS" \
  -dname "CN=FleurApp, OU=Application mobile, O=FleurApp, L=France, C=FR"

PROPERTIES_TEMP="$(mktemp "${PROPERTIES_PATH}.tmp.XXXXXX")"
trap 'rm -f "${PROPERTIES_TEMP:-}"; unset FLEURAPP_SIGNING_PASSWORD FLEURAPP_ANDROID_STORE_PASSWORD' EXIT
{
  printf 'storePassword=%s\n' "$FLEURAPP_SIGNING_PASSWORD"
  printf 'keyPassword=%s\n' "$FLEURAPP_SIGNING_PASSWORD"
  printf 'keyAlias=%s\n' "$KEY_ALIAS"
  printf 'storeFile=%s\n' "$KEYSTORE_PATH"
} > "$PROPERTIES_TEMP"
install -m 600 "$PROPERTIES_TEMP" "$PROPERTIES_PATH"
rm -f "$PROPERTIES_TEMP"

echo
echo "Signature Android créée avec succès."
echo "Keystore privé : $KEYSTORE_PATH"
echo "Configuration locale : $PROPERTIES_PATH"
echo
echo "Sauvegardez le keystore et son mot de passe dans deux emplacements chiffrés."
echo "La perte de cette clé empêcherait la publication de mises à jour compatibles."
