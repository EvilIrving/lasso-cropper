# Lasso Export · 套索导出

<p align="center">
  <img src="website/assets/icon.png" width="128" height="128" alt="Lasso Export icon">
</p>

Native macOS tool. Draw a freehand lasso around anything on a sheet, then export every cut as a square transparent PNG in one shot.

Local-only, no account, no telemetry. Full build is free on GitHub; Mac App Store listing is planned as **free**.

[Website](https://lasso.onecat.dev/) · [Privacy](https://lasso.onecat.dev/privacy) · [Support](https://lasso.onecat.dev/support) · [Releases](https://github.com/EvilIrving/lasso-cropper/releases) · [中文说明](#中文)

## Why

Sprite sheets and model dumps pack objects too tightly for a rectangle crop. This app keeps the lasso in your hand: each closed path becomes one file, numbered in draw order.

## Install

macOS 13 or later, Swift 6 to build from source.

```bash
./build.sh
open LassoCropper.app
```

Or:

```bash
git clone https://github.com/EvilIrving/lasso-cropper.git
cd lasso-cropper
./build.sh
```

### Release builds (App Store / notarized)

```bash
xcodegen generate --spec project.yml   # if xcodeproj is missing
open LassoCropper.xcodeproj            # Archive in Organizer
# or
./Scripts/release-direct.sh            # Developer ID + notarization
./Scripts/release-mas.sh               # App Store Connect export
```

## Use

1. Open or drop an image.
2. Draw around an object. Release to keep it.
3. Repeat. The inspector shows each result on a checkerboard.
4. Export once. Files land as `01.png`, `02.png`, …

- **Canvas** is the square export size (default 512×512), not the source crop.
- **Margin** is transparent padding inside that square.
- Mouse wheel, Control+wheel, or ⌘+wheel zooms. Trackpad pans. Space drags.
- Export defaults to an app-managed folder. You can authorize any folder once; the grant is remembered.

Cuts autosave per source image.

## Privacy

- Images stay on disk locally
- No network requests
- No usage telemetry

## License

MIT. See [LICENSE](LICENSE).

## Mac App Store

Store apps must be sandboxed. This tree includes an Xcode project, App Sandbox entitlements, and security-scoped bookmarks so user-picked export folders work after one authorization. GitHub Releases plus Developer ID notarization remains a supported path.

---

## 中文

**macOS 原生套索圈选：画一圈，批量导出 1:1 透明 PNG。**

本地处理，无账号、无遥测。完整版在 GitHub 免费下载；Mac App Store 计划**免费**上架。

### 能做什么

- 打开或拖入 PNG / JPEG / HEIC / TIFF / WebP
- 徒手套索圈选，一圈一张；最后统一导出
- 画布边长 256 / 512 / 1024，可调边距
- 滚轮缩放、触控板平移、空格拖动、撤销重做
- 导出目录默认在应用内；可授权任意文件夹并记住

### 安装

```bash
./build.sh
open LassoCropper.app
```

发布构建：

```bash
xcodegen generate --spec project.yml
open LassoCropper.xcodeproj
# 或
./Scripts/release-direct.sh
./Scripts/release-mas.sh
```
