#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.0.0"
    exit 1
fi

VERSION="$1"
APP_ID="com.n14395.monitorcontrol"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$SRC_DIR/assets/${APP_ID}.yml"
BUILD_DIR="$SRC_DIR/flatpak-build"
REPO_DIR="$SRC_DIR/flatpak-repo"
BUNDLE="$SRC_DIR/${APP_ID}-${VERSION}.flatpak"
METAINFO="$SRC_DIR/assets/${APP_ID}.metainfo.xml"

# Stamp version into metainfo
sed -i "s/@VERSION@/$VERSION/; s/@DATE@/$(date +%Y-%m-%d)/" "$METAINFO"

# Ensure runtime is available
echo "==> Ensuring GNOME 50 SDK is installed..."
flatpak install --user --noninteractive \
    flathub org.gnome.Platform//50 \
    org.gnome.Sdk//50 || true

# Build and export
echo "==> Building..."
flatpak-builder --user --repo="$REPO_DIR" --force-clean "$BUILD_DIR" "$MANIFEST"

# Bundle
echo "==> Bundling ${APP_ID} v${VERSION}..."
flatpak build-bundle "$REPO_DIR" "$BUNDLE" "$APP_ID"

# Restore metainfo placeholders
sed -i "s/$VERSION/@VERSION@/; s/$(date +%Y-%m-%d)/@DATE@/" "$METAINFO"

echo ""
echo "  Done: $BUNDLE"
echo "  Install:  flatpak install --user $BUNDLE"
echo "  Run:      flatpak run $APP_ID"
