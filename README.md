# Margin

Margin 是一个面向 iPhone 和 iPad 的原生 Markdown 阅读与编辑器。它使用系统文档浏览器打开和管理 `.md` / `.txt` 文件，并将用户 Typora 的 Claude-like 主题迁移为自适应 iOS 阅读体验。

## 当前能力

- 通过系统文稿首页新建、打开、重命名与管理 Markdown 文档
- 长按主屏幕 App 图标可直接新建空白 Markdown 文稿
- 使用 Icon Composer 分层图标，适配默认、深色、清透浅色、清透深色与着色外观
- 系统级自动保存、文件协调、最近项目和文档分享
- 可在首页选取 Claude 或 Typora GitHub 文稿主题，并在阅读设置中随时切换
- Claude 主题使用 Anthropic Serif 拉丁字体与 Noto Serif SC 中文衬线回退，支持明暗配色
- 标题、段落、引用、列表、任务、代码块、表格、图片、分隔线与 front matter 渲染
- 原生 TextKit 编辑器，支持选区、撤销、动态字体和 Markdown 快捷工具条
- 文档内搜索、标题目录跳转、字数 / 行数 / 阅读时长统计
- 文稿标题菜单支持复制、移动、分享、重新命名与打印
- 跟随系统 / 浅色 / 深色外观和可调正文比例
- 界面提供完整英语与简体中文资源；默认使用英语，iOS 首选语言为简体中文时自动切换中文

## 开发

需要 Xcode 26.6 或更高版本，部署目标为 iOS 26。

```sh
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphonesimulator build
```

视觉迁移依据见 [`docs/claude-like-theme-spec.md`](docs/claude-like-theme-spec.md)。

App 图标源文件为 `Margin/AppIcon.icon`；旧版扁平图标保存在 `docs/icon-source/AppIconLegacy.appiconset`，不参与构建。

## iCloud Drive

Margin 基于 SwiftUI `DocumentGroup`，因此启动时会显示系统文稿首页，并直接接入“文件”App 的 iCloud Drive、本机与第三方文件提供商。文档在原位置打开和保存，iCloud 同步由系统负责，不需要应用自建云端副本。

若要让正式发行版在 iCloud Drive 中拥有专属的 Margin 文件夹，需要在 Xcode 的 Signing & Capabilities 中选择实际 Apple Developer Team，并为最终 Bundle ID 启用 iCloud Documents container。仓库不会提交无法签名的占位容器。
