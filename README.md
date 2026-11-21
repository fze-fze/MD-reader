# Margin

Margin 是一个面向 iPhone 和 iPad 的原生 Markdown 阅读与编辑器。它使用系统文档浏览器打开和管理 `.md` / `.txt` 文件，并将用户 Typora 的 Claude-like 主题迁移为自适应 iOS 阅读体验。

## 当前能力

- 通过系统文稿首页新建、打开、重命名与管理 Markdown 文档
- 长按主屏幕 App 图标可直接新建空白 Markdown 文稿
- 使用 Icon Composer 分层图标，适配默认、深色、清透浅色、清透深色与着色外观
- 系统级自动保存、文件协调、最近项目和文档分享
- 可在首页选取 Claude 或 Typora GitHub 文稿主题，并在阅读设置中随时切换
- Claude 主题使用 Anthropic Serif 拉丁字体与 Noto Serif SC 中文衬线回退，支持明暗配色
- 正文与标题可分别选择衬线或无衬线字体（Claude 主题的无衬线为 Anthropic Sans）
- 标题、段落、引用、列表、任务、代码块、表格、图片、分隔线与 front matter 渲染
- ` ```mermaid ` 代码块在阅读视图中渲染为图表，右上角的复制按钮相应变为“导出图片”，可分享带主题背景的 PNG；打印、PDF 与 HTML 导出同样内嵌渲染后的图表
- 文档顶部可直接切换阅读、实时排版和源码模式。实时排版复用阅读模式的渲染，包括表格、公式和图片；点按任一块即可用原生 TextKit 编辑其 Markdown 源码。源码模式可跨块编辑和查找全文。
- 支持选区、撤销、动态字体和 Markdown 快捷工具条
- 文档内搜索、标题目录跳转、字数 / 行数 / 阅读时长统计
- 文稿标题菜单支持复制、移动、分享、重新命名与打印
- 跟随系统 / 浅色 / 深色外观和可调正文比例
- 界面支持英语、简体中文、繁体中文、日语、韩语和西班牙语，由 iOS 按首选语言选用，无匹配时回退到英语。在“阅读设置 → App 语言”打开 iOS 设置，再到“设置 → App → Margin → 语言”单独更改界面语言。

## 开发

需要 Xcode 26.6 或更高版本，部署目标为 iOS 26。

```sh
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphonesimulator build
```

视觉迁移依据见 [`docs/claude-like-theme-spec.md`](docs/claude-like-theme-spec.md)。

App 图标源文件为 `Margin/AppIcon.icon`；旧版扁平图标保存在 `docs/icon-source/AppIconLegacy.appiconset`，不参与构建。

图表渲染内置 [mermaid](https://github.com/mermaid-js/mermaid)（MIT，见 `Margin/Resources/Mermaid/LICENSE-mermaid.txt`）离线脚本，随 App 打包，不访问网络。升级时替换 `Margin/Resources/Mermaid/mermaid.min.js` 即可。

## iCloud Drive

Margin 基于 SwiftUI `DocumentGroup`，并以它提供的 `FileDocument` 作为唯一文档数据源，因此启动时会显示系统文稿首页，并直接接入“文件”App 的 iCloud Drive、本机与第三方文件提供商。文档在原位置打开和保存，iCloud 同步、外部修改协调与自动保存均由系统负责，不需要应用自建云端副本或第二套文档会话。

若要让正式发行版在 iCloud Drive 中拥有专属的 Margin 文件夹，需要在 Xcode 的 Signing & Capabilities 中选择实际 Apple Developer Team，并为最终 Bundle ID 启用 iCloud Documents container。仓库不会提交无法签名的占位容器。
