#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ClaudeUsageBar"
BUNDLE_ID="com.bilalahmad.claudeusagebar"
VERSION="1.0"

echo "▶ Building release binary…"
swift build -c release

BIN=".build/release/${APP_NAME}"
APP="${APP_NAME}.app"
CONTENTS="${APP}/Contents"

echo "▶ Assembling ${APP}…"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp "${BIN}" "${CONTENTS}/MacOS/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>Claude Usage</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

echo "▶ Code-signing (ad-hoc)…"
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1 || true

echo ""
echo "✅ Built ${APP}"
echo "   Run now:   open ${APP}"
echo "   Install:   mv ${APP} /Applications/  (then open it once so 'Launch at login' sticks)"
