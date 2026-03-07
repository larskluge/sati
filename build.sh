#!/bin/bash
set -euo pipefail

# Kill running instance if any
pkill -x Sati 2>/dev/null && sleep 0.5 || true

echo "Building Sati..."

swiftc -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  -framework ServiceManagement \
  -target arm64-apple-macosx13.0 \
  -swift-version 5 \
  -O \
  Sati/SatiApp.swift \
  Sati/ReminderManager.swift \
  Sati/VLCMonitor.swift \
  Sati/SettingsView.swift \
  Sati/BuddhaIcon.swift \
  -o Sati_binary

APP_DIR="build/Sati.app/Contents"
rm -rf build/Sati.app
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources/Sounds"

cp Sati_binary "$APP_DIR/MacOS/Sati"
cp Sati/Sounds/bowl.aif "$APP_DIR/Resources/Sounds/bowl.aif"
cp Sati/Sounds/bowl.aif "$APP_DIR/Resources/bowl.aif"
cp Sati/Resources/buddha.png "$APP_DIR/Resources/buddha.png"
cp Sati/Resources/buddha@2x.png "$APP_DIR/Resources/buddha@2x.png"

cat > "$APP_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Sati</string>
	<key>CFBundleIdentifier</key>
	<string>com.sati.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Sati</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
EOF

codesign --force --sign - "build/Sati.app"
rm -f Sati_binary

echo "Done! Launching Sati..."
open build/Sati.app
