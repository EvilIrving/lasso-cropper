#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="LassoCropper.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ICON_PNG="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [[ ! -f "$ICON_PNG" ]]; then
  echo "missing app icon: $ICON_PNG" >&2
  exit 1
fi
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for px in 16 32 128 256 512; do
  sips -z $px $px "$ICON_PNG" --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
done
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cp -f Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$APP/Contents/Info.plist" 2>/dev/null || true
cp -f .build/release/LassoCropper "$APP/Contents/MacOS/LassoCropper"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/LassoCropper"
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/LassoCropper" >/dev/null
codesign --force --sign - --timestamp=none "$APP" >/dev/null
xattr -cr "$APP"
# Bump Finder/Dock icon cache for this bundle path.
touch "$APP"
echo "built $PWD/$APP"
