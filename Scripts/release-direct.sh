#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="LassoCropper Direct"
ARCHIVE_PATH="${TMPDIR%/}/LassoCropper-Direct.xcarchive"
EXPORT_DIR="${TMPDIR%/}/LassoCropper-Direct-Export"
DIST_DIR="$PWD/dist"
APP_NAME="LassoCropper.app"

if [[ ! -d LassoCropper.xcodeproj ]]; then
  if command -v xcodegen >/dev/null 2>&1 && [[ -f project.yml ]]; then
    xcodegen generate --spec project.yml
  else
    echo "missing LassoCropper.xcodeproj (and xcodegen/project.yml)" >&2
    exit 1
  fi
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$DIST_DIR"

echo "archiving $SCHEME ..."
xcodebuild \
  -project LassoCropper.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=QZZ878S3NS

echo "exporting Developer ID app ..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist Scripts/export-direct.plist

if [[ ! -d "$EXPORT_DIR/$APP_NAME" ]]; then
  echo "export missing $APP_NAME under $EXPORT_DIR" >&2
  ls -la "$EXPORT_DIR" >&2 || true
  exit 1
fi

ZIP="$DIST_DIR/LassoCropper-direct.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$EXPORT_DIR/$APP_NAME" "$ZIP"
echo "zipped $ZIP"

if command -v xcrun >/dev/null 2>&1; then
  echo "submitting to notarytool (needs Apple ID keychain profile or API key) ..."
  if xcrun notarytool submit "$ZIP" --keychain-profile "AC_NOTARY" --wait; then
    xcrun stapler staple "$EXPORT_DIR/$APP_NAME"
    ditto -c -k --keepParent "$EXPORT_DIR/$APP_NAME" "$ZIP"
    echo "notarized + stapled: $ZIP"
  else
    echo "notarytool failed. Create a keychain profile first, e.g.:" >&2
    echo "  xcrun notarytool store-credentials AC_NOTARY --apple-id YOU@email --team-id QZZ878S3NS" >&2
    echo "Unsigned/un-notarized export remains at: $EXPORT_DIR/$APP_NAME" >&2
    exit 1
  fi
fi

cp -R "$EXPORT_DIR/$APP_NAME" "$DIST_DIR/$APP_NAME"
echo "done: $DIST_DIR/$APP_NAME"
