#!/usr/bin/env bash
# Build swift-translate, wrap the binary in a proper .app bundle, install it
# to ~/Applications, and register a Login Item.
set -euo pipefail

APP_NAME="swift-translate"
BUNDLE_ID="com.swifttranslate.app"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/Applications"
APP_BUNDLE="$DEST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"

echo "==> Building release binary…"
cd "$SRC_DIR"
swift build -c release

echo "==> Assembling $APP_BUNDLE"
# Clean any stale install first so reruns are idempotent.
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp -f ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>swift-translate</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>0.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc sign the bundle so macOS treats it as a stable identity for things
# like Accessibility permission. Without this, permission can get revoked on
# every rebuild.
echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Registering Login Item"
/usr/bin/osascript <<OSA >/dev/null
tell application "System Events"
    try
        delete (every login item whose name is "$APP_NAME")
    end try
    make login item at end with properties {path:"$APP_BUNDLE", hidden:true, name:"$APP_NAME"}
end tell
OSA

echo
echo "Installed: $APP_BUNDLE"
echo "It will start automatically at next login."
echo
echo "Start it now?  [y/N]"
read -r reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    open "$APP_BUNDLE"
    echo "Started. Look for the 🌐 icon in your menu bar (top-right)."
    echo
    echo "First-run checklist:"
    echo "  1. Grant Accessibility in System Settings → Privacy & Security"
    echo "     → Accessibility, then quit & relaunch this app."
    echo "  2. Paste your OpenAI API key in the prompt that appears."
fi
