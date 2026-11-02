#!/bin/bash -e
# CI build: compile, Developer ID sign with hardened runtime, notarize, staple
# and zip. Without the secrets it falls back to an ad-hoc signed, unnotarized app.
#
# Secrets (GitHub Actions):
#   APPLICATION   base64 of the Developer ID Application .p12
#   P12_PASSWORD  password protecting that .p12
#   APPLE_USER    Apple ID used for notarization
#   APPLE_PASS    app-specific password for that Apple ID
set +x

ROOT=$(cd "$(dirname "$0")/.."; pwd)
cd "$ROOT"
APP_NAME="Crossbow"
TEAM_ID="${TEAM_ID:-3FS7DJDG38}"
DEV_APP_ID="${DEV_APP_ID:-Developer ID Application: Roland Rabien (${TEAM_ID})}"

#
# Bootstrap a throwaway keychain from the base64 p12 secret when running in CI.
#
if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "${APPLICATION:-}" ]; then
  if [ -z "${P12_PASSWORD:-}" ]; then
    echo "APPLICATION is set but P12_PASSWORD is not"; exit 1
  fi
  KC_PASS=$(openssl rand -hex 16)
  KC="$RUNNER_TEMP/keys.keychain-db"

  security create-keychain -p "$KC_PASS" "$KC"
  echo "$APPLICATION" | base64 -D -o "$RUNNER_TEMP/Application.p12"
  security import "$RUNNER_TEMP/Application.p12" -k "$KC" -P "$P12_PASSWORD" -A -T /usr/bin/codesign
  rm -f "$RUNNER_TEMP/Application.p12"
  security list-keychains -d user -s "$KC" login.keychain
  security default-keychain -s "$KC"
  security unlock-keychain -p "$KC_PASS" "$KC"
  security set-keychain-settings -l -u -t 13600 "$KC"
  security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PASS" "$KC" >/dev/null
fi

#
# Build unsigned; signing happens below so the same script works locally.
#
rm -rf "$ROOT/ci/bin" "$ROOT/ci/build"
mkdir -p "$ROOT/ci/bin"

xcodebuild -project Crossbow.xcodeproj -scheme Crossbow -configuration Release \
  -derivedDataPath "$ROOT/ci/build" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build

cp -R "$ROOT/ci/build/Build/Products/Release/$APP_NAME.app" "$ROOT/ci/bin/"
cd "$ROOT/ci/bin"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_NAME.app/Contents/Info.plist")

#
# Sign: embedded frameworks first, then the app with its sandbox entitlements.
#
if security find-identity -v -p codesigning | grep -q "$DEV_APP_ID"; then
  for fw in "$APP_NAME.app"/Contents/Frameworks/*.framework; do
    codesign -s "$DEV_APP_ID" --options=runtime --timestamp --force -v "$fw"
  done
  codesign -s "$DEV_APP_ID" --options=runtime --timestamp --force \
    --entitlements "$ROOT/Resources/Crossbow.entitlements" -v "$APP_NAME.app"
  codesign --verify --deep --strict -v "$APP_NAME.app"
else
  echo "Skipping Developer ID signing - certificate not in keychain, ad-hoc signing instead"
  codesign --force --deep --sign - --entitlements "$ROOT/Resources/Crossbow.entitlements" "$APP_NAME.app"
fi

#
# Notarize and staple
#
if [ -n "${APPLE_USER:-}" ] && [ -n "${APPLE_PASS:-}" ]; then
  ditto -c -k --keepParent "$APP_NAME.app" notarize.zip
  xcrun notarytool submit notarize.zip --apple-id "$APPLE_USER" --password "$APPLE_PASS" \
    --team-id "$TEAM_ID" --wait --timeout 30m
  rm notarize.zip
  xcrun stapler staple "$APP_NAME.app"
  spctl --assess --type execute -v "$APP_NAME.app"
else
  echo "Skipping notarization - APPLE_USER / APPLE_PASS not set"
fi

#
# Package
#
ditto -c -k --keepParent "$APP_NAME.app" "${APP_NAME}_${VERSION}_macOS.zip"
rm -rf "$APP_NAME.app"
ls -l
