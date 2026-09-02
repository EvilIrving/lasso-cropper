# 套索导出

独立的 macOS 工具：打开任意图片，沿轮廓画圈，批量导出 1:1 透明 PNG。

## 使用

双击 `LassoCropper.app`，或：

```bash
./build.sh
open LassoCropper.app
```

- 画一圈即收下，最后一次导出全部
- 鼠标滚轮、Ctrl+滚轮、⌘+滚轮缩放
- 触控板双指平移，空格拖动
- **画布**是每张导出 PNG 的正方形边长
- **导出到**默认在原图旁边的「文件名-导出」文件夹

## 构建

需要 macOS 13+ 与 Swift 6。

```bash
./build.sh
```
