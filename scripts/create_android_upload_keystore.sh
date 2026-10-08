#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYSTORE_PATH="$ROOT_DIR/android/upload-keystore.jks"
KEY_PROPERTIES="$ROOT_DIR/android/key.properties"
ALIAS="${1:-upload}"

if [[ -f "$KEYSTORE_PATH" ]]; then
  echo "Keystore already exists: $KEYSTORE_PATH"
  echo "Use the existing keystore for app updates. Delete it only if this is a first release and you are sure."
  exit 1
fi

echo "Creating Android upload keystore."
echo "Keep the password and android/upload-keystore.jks safe. Losing them can block future app updates."
echo

keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$ALIAS"

echo
read -r -s -p "Enter keystore storePassword: " STORE_PASSWORD
echo
read -r -s -p "Enter keyPassword for alias '$ALIAS': " KEY_PASSWORD
echo

cat > "$KEY_PROPERTIES" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$ALIAS
storeFile=../upload-keystore.jks
EOF

chmod 600 "$KEY_PROPERTIES"

echo
echo "Created:"
echo "  android/upload-keystore.jks"
echo "  android/key.properties"
echo
echo "These files are ignored by git. Back them up securely."
