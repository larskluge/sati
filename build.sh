#!/bin/bash
set -euo pipefail

# Kill running instance if any
pkill -x Sati 2>/dev/null && sleep 0.5 || true

echo "Building Sati..."

xcodebuild -project Sati/Sati.xcodeproj \
  -scheme Sati \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' \
  ENABLE_APP_SANDBOX=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  2>&1 | tail -20

APP_PATH="$(find build/DerivedData -name 'Sati.app' -path '*/Release/*' | head -1)"

if [ -z "$APP_PATH" ]; then
  echo "Build failed — Sati.app not found"
  exit 1
fi

# Register with LaunchServices so macOS picks up the app icon for notifications
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"

echo "Done! Launching Sati..."
open "$APP_PATH"
