#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="LassoCropper App Store"
ARCHIVE_PATH="${TMPDIR%/}/LassoCropper-MAS.xcarchive"
EXPORT_DIR="${TMPDIR%/}/LassoCropper-MAS-Export"

if [[ ! -d LassoCropper.xcodeproj ]]; then
  if command -v xcodegen >/dev/null 2>&1 && [[ -f project.yml ]]; then
    xcodegen generate --spec project.yml
  else
    echo "missing LassoCropper.xcodeproj (and xcodegen/project.yml)" >&2
    exit 1
  fi
fi

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

echo "archiving $SCHEME ..."
xcodebuild \
  -project LassoCropper.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=QZZ878S3NS

echo "exporting for App Store Connect ..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist Scripts/export-mas.plist

echo "Archive: $ARCHIVE_PATH"
echo "Export:  $EXPORT_DIR"
echo "Upload via Xcode Organizer, or:"
echo "  xcrun altool --upload-app -f <pkg> -t macos ..."
echo "  or Transporter.app"
