#!/usr/bin/env bash
# Build swift-translate, install it to ~/Applications, and register a Login Item.
set -euo pipefail

APP_NAME="swift-translate"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/Applications"
DEST_BIN="$DEST_DIR/$APP_NAME"

echo "==> Building release binary…"
cd "$SRC_DIR"
swift build -c release

echo "==> Installing to $DEST_BIN"
mkdir -p "$DEST_DIR"
cp -f ".build/release/$APP_NAME" "$DEST_BIN"
chmod +x "$DEST_BIN"

echo "==> Registering Login Item"
# Remove any existing entry first so re-running this script stays idempotent.
/usr/bin/osascript <<OSA >/dev/null
tell application "System Events"
    try
        delete (every login item whose name is "$APP_NAME")
    end try
    make login item at end with properties {path:"$DEST_BIN", hidden:true, name:"$APP_NAME"}
end tell
OSA

echo
echo "Installed: $DEST_BIN"
echo "It will start automatically at next login."
echo
echo "Start it now?  [y/N]"
read -r reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
    # Fully detach so this shell can exit.
    nohup "$DEST_BIN" >/dev/null 2>&1 &
    disown || true
    echo "Started. Look for the 🌐 icon in your menu bar."
    echo "First run asks for Accessibility permission + OpenAI API key."
fi
