#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen missing. Install with: brew install xcodegen" >&2
  exit 1
fi

rm -rf build Payload SW2HIDBridge-unsigned.ipa
xcodegen generate

xcodebuild \
  -project SW2HIDBridge.xcodeproj \
  -scheme SW2HIDBridge \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP="$(find build -type d -path '*/Release-iphoneos/SW2HIDBridge.app' | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "Built .app not found" >&2
  exit 1
fi

mkdir -p Payload
cp -R "$APP" Payload/SW2HIDBridge.app
zip -qry SW2HIDBridge-unsigned.ipa Payload
echo "OK: $(pwd)/SW2HIDBridge-unsigned.ipa"
