# Growth Context

*Last updated: 2026-09-02*

## Product
- **Name:** 套索导出 (Lasso Cropper)
- **One-liner:** macOS 原生套索圈选，批量导出 1:1 透明 PNG
- **What it does:** 打开任意图片，沿轮廓徒手画圈，把每个圈选裁成正方形透明 PNG 并批量导出。画布边长可选 256 / 512 / 1024，支持缩放、平移、撤销重做。
- **Category:** macOS graphics / sprite / asset crop tool

## Platform & distribution
- **Platform / requirements:** macOS 13+, Apple Silicon / Intel（Universal 视构建而定）, Swift 6 / AppKit
- **How it ships / installs:**
  - GitHub：完整版免费下载（源码 + 自建 `.app`）
  - Mac App Store：计划上架，**免费**
  - 本地：`./build.sh` 产出 `LassoCropper.app`
- **Updates:** 手动 / 商店更新（商店通道就绪后）
- **Bundle ID:** `dev.onecat.lasso-export`
- **Repo:** https://github.com/EvilIrving/lasso-cropper
- **Site:** https://lasso.onecat.dev/（Cloudflare Pages `lasso-export`；源站 https://lasso-export.pages.dev/；源码在 `website/`）
- **Support URL:** https://lasso.onecat.dev/support（App Store Connect）
- **Privacy URL:** https://lasso.onecat.dev/privacy（App Store Connect）
- **AEO:** 三页均含自洽首句、可见 FAQ 与 JSON-LD（`SoftwareApplication` / `FAQPage` / `WebPage`）；canonical/sitemap/OG 已用正式域名
- **Version:** 1.2 (3)

## Pricing model
- 完整功能免费
- GitHub 下载免费
- Mac App Store 免费上架（无内购计划）

## Audience
- **Who it's for:** 做 UI / 游戏 / 表情包素材的人；需要从整图里快速抠出多个正方形透明切片
- **Why they reach for it:** 不想开 Photoshop；拖进图、圈几下、一次导出

## Differentiators (ranked, all true)
- 原生 AppKit，macOS 13+，无 Electron
- 徒手套索即圈即收，批量导出 1:1 透明 PNG
- 本地处理，无账号、无遥测、无网络请求
- 中文界面（`zh_CN`）
- 开源，商店与 GitHub 均为免费

## Competitors / alternatives
| Name | Model | Honest strength | How we differ |
|------|-------|-----------------|---------------|
| Photoshop / Affinity | 付费专业套件 | 功能完整、蒙版与路径强 | 我们只做圈选导出，启动快、无订阅 |
| Preview.app | 系统自带 | 人人都有 | 不支持套索批量透明方图 |
| 在线抠图站 | 免费/限额 | 方便分享链接 | 我们完全本地，素材不出机 |

## Channels
- **Where this audience is:** GitHub (macos / design-tools), Mac App Store 图形与设计分类, 少数派 / V2EX 偶尔, r/macapps
- **Languages to publish in:** 中文（与软件 UI 一致；目前仅 zh_CN）

## Voice
- **Tone:** 简洁、工具向、少形容词
- **Words to use / avoid:** 用「圈选 / 导出 / 透明 PNG / 本地」；避免「强大 / 无缝 / AI 驱动」等空话

## Proof points (REAL only)
- （尚无下载量或外部评价可写）

## Links
- **Social handles / accounts:**
- **Press / contact:**
- **GitHub:** https://github.com/EvilIrving/lasso-cropper
- **Homepage:** https://lasso.onecat.dev/
- **Pages alias:** https://lasso-export.pages.dev/
