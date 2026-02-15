#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.0.0}"
ARCH="${2:-$(uname -m)}"
APP_NAME="GitTracker.app"
DIST_DIR="$ROOT_DIR/dist/$ARCH"
APP_DIR="$DIST_DIR/$APP_NAME"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
EXECUTABLE_PATH="$APP_DIR/Contents/MacOS/GitTracker"
ZIP_PATH="$DIST_DIR/GitTracker-${ARCH}.zip"
SHA_PATH="$DIST_DIR/GitTracker-${ARCH}.sha256"

swift build -c release --arch "$ARCH" >/dev/null
BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
BIN_PATH="$BIN_DIR/GitTracker"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected executable not found at $BIN_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$EXECUTABLE_PATH"
chmod +x "$EXECUTABLE_PATH"

cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>GitTracker</string>
    <key>CFBundleExecutable</key>
    <string>GitTracker</string>
    <key>CFBundleIdentifier</key>
    <string>com.ruiperes.gittracker</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GitTracker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Re-sign the bundle so Gatekeeper can validate it after Homebrew install.
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$ZIP_PATH" "$SHA_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" | awk '{print $1}' >"$SHA_PATH"

echo "Packaged: $ZIP_PATH"
echo "SHA256: $(cat "$SHA_PATH")"
