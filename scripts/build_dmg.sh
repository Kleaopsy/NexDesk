#!/bin/bash
set -e

APP_NAME="NexDesk"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_DIR="dist/macos"

mkdir -p "$DMG_DIR"

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 150 185 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 450 185 \
  "$DMG_DIR/$DMG_NAME" \
  "$APP_PATH"

echo "✅ DMG created: $DMG_DIR/$DMG_NAME"