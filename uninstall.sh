#!/usr/bin/env bash
# Remove the installed .app and unregister the Login Item.
set -euo pipefail

APP_NAME="swift-translate"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"

echo "==> Stopping any running instance"
pkill -x "$APP_NAME" 2>/dev/null || true

echo "==> Removing Login Item"
/usr/bin/osascript <<OSA >/dev/null
tell application "System Events"
    try
        delete (every login item whose name is "$APP_NAME")
    end try
end tell
OSA

echo "==> Removing bundle"
rm -rf "$APP_BUNDLE"
# Clean up any legacy bare-binary install from v0.1.
rm -f "$HOME/Applications/$APP_NAME"

echo
echo "Uninstalled. Note: API key still lives in Keychain under service"
echo "'com.swifttranslate.app'. Remove it manually with Keychain Access if desired."
