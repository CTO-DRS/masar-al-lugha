#!/usr/bin/env bash
# v5.10 — prepare the REAL Play signing setup (Phase 5/3).
# The keystore NEVER enters the repository (hard invariant: no secrets in
# the repo). This script generates it locally and wires android/key.properties
# (gitignored). CI keeps using the debug-signed artifact; Play uploads are
# signed locally with this keystore, or later via GitHub Secrets.
set -euo pipefail
cd "$(dirname "$0")/.."

KS_PATH="android/app/masar-upload.jks"
PROPS="android/key.properties"

if [ -f "$KS_PATH" ]; then
  echo "✔ keystore already exists: $KS_PATH (nothing generated)"
else
  echo "→ generating upload keystore (validity 30 years)…"
  keytool -genkeypair -v \
    -keystore "$KS_PATH" \
    -alias masar-upload \
    -keyalg RSA -keysize 2048 -validity 10950 \
    -storepass "${MASAR_KS_PASS:?set MASAR_KS_PASS first}" \
    -keypass "${MASAR_KS_PASS:?set MASAR_KS_PASS first}" \
    -dname "CN=Masar Al-Lugha, OU=Masar, O=Masar, C=SA"
fi

if [ -f "$PROPS" ]; then
  echo "✔ $PROPS already exists"
else
  cat > "$PROPS" <<PROPS
storePassword=$MASAR_KS_PASS
keyPassword=$MASAR_KS_PASS
keyAlias=masar-upload
storeFile=masar-upload.jks
PROPS
  echo "→ wrote $PROPS"
fi

# hard safety: these must never be committed
if ! grep -qx "key.properties" .gitignore; then echo "key.properties" >> .gitignore; fi
if ! grep -qx "*.jks" .gitignore; then echo "*.jks" >> .gitignore; fi

cat <<'GUIDE'

Next steps (Play Console):
1. Play Console → Setup → App signing → choose "Java Keystore" upload key and
   upload masar-upload.jks (or enroll in Play App Signing with the upload key).
2. For CI release signing later: store MASAR_KS_PASS + a base64 of the keystore
   as GitHub Secrets (KEYSTORE_BASE64, KEYSTORE_PASSWORD, KEY_ALIAS) and decode
   at build time — the file itself never enters the repo.
3. Keep an offline backup of the keystore — losing it means losing the ability
   to update the app under the same applicationId.
GUIDE
