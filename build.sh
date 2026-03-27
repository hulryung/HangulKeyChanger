#!/bin/bash

# Build, sign, notarize, and package HangulCommandApp for distribution
# Prerequisites:
#   - Developer ID Application certificate in Keychain
#   - Notarytool credentials stored: xcrun notarytool store-credentials "HangulCommandApp" --apple-id <email> --team-id XGJ87M8ZZR

set -euo pipefail

APP_NAME="Hangul Key Changer"
SCHEME="HangulCommandApp"
PROJECT="HangulCommandApp.xcodeproj"
BUILD_DIR="$(pwd)/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
KEYCHAIN_PROFILE="HangulCommandApp"  # notarytool credential profile name

# Read version from Xcode project
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | grep MARKETING_VERSION | tr -d ' ' | cut -d= -f2)
if [ -z "$VERSION" ]; then
    echo "Failed to read version from project"
    exit 1
fi

echo "=== Building ${APP_NAME} v${VERSION} ==="

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo ""
echo "--- Step 1/5: Archive ---"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

echo "Archive created: ${ARCHIVE_PATH}"

# Step 2: Export
echo ""
echo "--- Step 2/5: Export ---"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist exportOptions.plist \
    -quiet

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
echo "Exported: ${APP_PATH}"

# Step 3: Verify code signing
echo ""
echo "--- Step 3/5: Verify signing ---"
codesign --verify --deep --strict "$APP_PATH"
echo "Code signing verified"

# Step 4: Notarize
echo ""
echo "--- Step 4/5: Notarize ---"

# Create zip for notarization submission
NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
ditto -c -k --sequesterRsrc "$APP_PATH" "$NOTARIZE_ZIP"

xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

rm -f "$NOTARIZE_ZIP"
echo "Notarization completed"

# Step 5: Staple
echo ""
echo "--- Step 5/5: Staple ---"
xcrun stapler staple "$APP_PATH"
echo "Stapling completed"

# Verify Gatekeeper acceptance
echo ""
echo "--- Verification ---"
spctl -a -v --type install "$APP_PATH"

# Package for distribution
echo ""
echo "--- Packaging ---"

# Create DMG
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_TEMP"

# Notarize and staple DMG
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
xcrun stapler staple "$DMG_PATH"

# Create zip for GitHub release
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
ditto -c -k --sequesterRsrc "$APP_PATH" "$ZIP_PATH"

echo ""
echo "=== Build complete ==="
echo "  DMG: ${DMG_PATH}"
echo "  ZIP: ${ZIP_PATH}"
ls -lh "$DMG_PATH" "$ZIP_PATH"
