#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.0.0"
    exit 1
fi

VERSION="$1"
APP_NAME="Philips Monitor Control"
BUNDLE_ID="com.n14395.monitorcontrol"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$SRC_DIR/MacOS"
APP_DIR="$SRC_DIR/${APP_NAME}.app"
DMG="$SRC_DIR/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} v${VERSION}..."

# ── Build Swift binary ───────────────────────────────────────────────────────
cd "$MACOS_DIR"
swift build -c release

# ── Assemble .app bundle ────────────────────────────────────────────────────
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

# Binary
cp "$MACOS_DIR/.build/release/PhilipsMultiView" "$APP_DIR/Contents/MacOS/"

# Info.plist — stamp version and bundle ID
sed \
    -e "s|<string>com.philips.multiview</string>|<string>${BUNDLE_ID}</string>|" \
    -e "s|<string>1.0</string>|<string>${VERSION}</string>|" \
    -e "s|<string>1</string><!-- build -->|<string>${VERSION}</string>|" \
    "$MACOS_DIR/Info.plist" > "$APP_DIR/Contents/Info.plist"

# If sed didn't catch the build number (no comment marker), do a second pass
# to ensure CFBundleVersion is set. The plist has two <string>1...</string>
# entries — CFBundleShortVersionString (already handled) and CFBundleVersion.
# We use a Python one-liner to stamp both reliably.
python3 -c "
import plistlib, sys
p = '$APP_DIR/Contents/Info.plist'
with open(p, 'rb') as f: d = plistlib.load(f)
d['CFBundleIdentifier'] = '$BUNDLE_ID'
d['CFBundleShortVersionString'] = '$VERSION'
d['CFBundleVersion'] = '$VERSION'
with open(p, 'wb') as f: plistlib.dump(d, f)
"

# ── Generate .icns from SVG ─────────────────────────────────────────────────
SVG="$SRC_DIR/assets/${BUNDLE_ID}.svg"
ICONSET="$(mktemp -d)/AppIcon.iconset"

if [ -f "$SVG" ] && command -v rsvg-convert &>/dev/null && command -v iconutil &>/dev/null; then
    echo "==> Generating AppIcon.icns..."
    mkdir -p "$ICONSET"
    for SIZE in 16 32 128 256 512; do
        rsvg-convert -w $SIZE -h $SIZE "$SVG" -o "$ICONSET/icon_${SIZE}x${SIZE}.png"
        DOUBLE=$((SIZE * 2))
        rsvg-convert -w $DOUBLE -h $DOUBLE "$SVG" -o "$ICONSET/icon_${SIZE}x${SIZE}@2x.png"
    done
    iconutil -c icns -o "$APP_DIR/Contents/Resources/AppIcon.icns" "$ICONSET"
    rm -rf "$(dirname "$ICONSET")"
else
    echo "    (skipping icon — install librsvg for .icns generation)"
fi

echo "==> App bundle: $APP_DIR"

# ── Create DMG ───────────────────────────────────────────────────────────────
if command -v hdiutil &>/dev/null; then
    echo "==> Creating DMG..."
    rm -f "$DMG"

    DMG_STAGE="$(mktemp -d)"
    cp -R "$APP_DIR" "$DMG_STAGE/"
    ln -s /Applications "$DMG_STAGE/Applications"

    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGE" \
        -ov -format UDZO \
        "$DMG"
    rm -rf "$DMG_STAGE"

    echo ""
    echo "  Done: $DMG"
else
    echo ""
    echo "  Done: $APP_DIR"
    echo "  (run on macOS with hdiutil to create a DMG)"
fi
