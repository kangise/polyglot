#!/usr/bin/env bash
# Remove the installed binary and unregister the Login Item.
set -euo pipefail

APP_NAME="swift-translate"
DEST_BIN="$HOME/Applications/$APP_NAME"

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

echo "==> Removing binary"
rm -f "$DEST_BIN"

echo
echo "Uninstalled. Note: API key still lives in Keychain under service"
echo "'com.swifttranslate.app'. Remove it manually with Keychain Access if desired."
