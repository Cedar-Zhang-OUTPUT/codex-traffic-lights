#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_NAME="CodexLight"
BUNDLE="$ROOT_DIR/dist/Codex Light.app"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN_DIR/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CodexLight</string>
<key>CFBundleIdentifier</key><string>local.cedar.CodexLight</string>
<key>CFBundleName</key><string>Codex Light</string>
<key>CFBundleDisplayName</key><string>Codex Light</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$BUNDLE"
case "$MODE" in
  --build-only) exit 0 ;;
  --install)
    ditto "$BUNDLE" "/Applications/Codex Light.app"
    "/Applications/Codex Light.app/Contents/MacOS/CodexLight" --install-hooks
    /usr/bin/open "/Applications/Codex Light.app"
    ;;
  --debug) lldb -- "$BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry)
    /usr/bin/open -n "$BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "CodexLight"'
    ;;
  --verify)
    /usr/bin/open -n "$BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  run) /usr/bin/open -n "$BUNDLE" ;;
  *) echo "Usage: $0 [--install|--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
