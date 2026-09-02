#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="LassoCropper.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f Info.plist "$APP/Contents/Info.plist"
cp -f .build/release/LassoCropper "$APP/Contents/MacOS/LassoCropper"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/LassoCropper"
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/LassoCropper" >/dev/null
codesign --force --sign - --timestamp=none "$APP" >/dev/null
xattr -cr "$APP"
echo "built $PWD/$APP"
