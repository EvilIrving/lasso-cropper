# Lasso Export · 套索导出

Native macOS tool. Draw a freehand lasso around anything on a sheet, then export every cut as a square transparent PNG in one shot.

[中文说明](#中文)

## Why

Sprite sheets and model dumps pack objects too tightly for a rectangle crop. This app keeps the lasso in your hand: each closed path becomes one file, numbered in draw order.

## Install

macOS 13 or later.

```bash
./build.sh
open LassoCropper.app
```

Or clone and build with Swift 6:

```bash
git clone https://github.com/EvilIrving/lasso-cropper.git
cd lasso-cropper
./build.sh
```

## Use

1. Open or drop an image.
2. Draw around an object. Release to keep it.
3. Repeat. The inspector shows each result on a checkerboard.
4. Export once. Files land as `01.png`, `02.png`, …

- **Canvas** is the square export size (default 512×512), not the source crop.
- **Margin** is transparent padding inside that square.
- Mouse wheel, Control+wheel, or ⌘+wheel zooms. Trackpad pans. Space drags.

Cuts autosave per source image.

## License

MIT. See [LICENSE](LICENSE).

## Mac App Store

Possible, not the first ship. Store apps must be sandboxed. User-selected files via Open/Save panels are allowed; writing a sibling `*-导出` folder next to the source image is not, unless the user picks that folder. GitHub Releases plus Developer ID notarization is the current path.

---

## 中文

打开任意图片，沿轮廓画圈。每画完一圈自动收下，最后一次导出全部 1:1 透明 PNG。

画布是导出正方形边长。导出文件夹默认同目录下的「文件名-导出」。
