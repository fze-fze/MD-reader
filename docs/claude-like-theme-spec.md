# Claude-like iOS Markdown 视觉规范

## 1. 来源与实现边界

本规范提炼自用户当前实际使用的 Typora 主题：

- `claude-like.css`：排版、布局、Markdown 元素与明色 token 的唯一基准。
- `claude-like-dark.css`：通过导入明色主题，仅覆盖颜色和少量深色表面状态。

iOS 端应保持同样的结构：**一套排版与组件几何，两套动态颜色**。不要为暗色模式复制或分叉 Markdown 布局代码。

CSS 中与 Typora、CodeMirror 或 Windows 菜单实现强绑定的选择器不应照搬；只迁移视觉意图。

## 2. 整体气质

- 暖白纸张感，而非纯白系统表面。
- 正文以克制的衬线字体承载，应用 chrome 使用清晰的无衬线字体。
- 标题不夸张，依靠字重、留白与略深的颜色建立层级。
- Claude 陶土橙只用于链接、光标、选中态、任务勾选与少量强调。
- 卡片感极轻：细边框、小圆角、低对比背景，避免大阴影与玻璃拟态。
- 暗色不是简单反相，而是暖近黑背景、骨白文字、棕灰分隔线和陶土橙强调。

## 3. 颜色 token

所有颜色应进入 Asset Catalog，并设置 Any/Dark appearance；Swift 代码只引用语义名。

| iOS 语义 token | 明色 | 暗色 | 用途 |
|---|---:|---:|---|
| `canvas` | `#FAF9F5` | `#1B1B19` | 阅读与编辑主背景 |
| `windowSurface` | `#F6F3ED` | `#22211F` | 工具栏、检查器、弹层外层 |
| `sidebarSurface` | `#F5F2EC` | `#1F1F1D` | 文档列表、目录侧栏 |
| `textPrimary` | `#2B2621` | `#D8D2C5` | 正文 |
| `textStrong` | `#1C1815` | `#F2EEE7` | 标题、强调文字、当前项 |
| `textSecondary` | `#72695E` | `#9F998F` | 元信息、列表 marker、辅助标签 |
| `accent` | `#BC6A3A` | `#D97855` | 链接、光标、勾选、活动指示 |
| `selection` | `#E8DDD0` | `rgba(211,120,84,0.34)` | 文本选择 |
| `separator` | `#DDD5CA` | `#34322E` | 普通分隔线 |
| `hoverFill` | `rgba(194,113,62,0.08)` | `rgba(232,125,89,0.10)` | 指针悬停、轻按反馈 |
| `activeFill` | `rgba(188,106,58,0.14)` | `rgba(217,120,85,0.14)` | 当前文档、当前目录项 |
| `quoteFill` | `#F3EDE5` | `#22211F` | 引用与目录块背景 |
| `quoteRule` | `#D8CBBB` | `#51463D` | 引用左边线 |
| `quoteText` | `#625950` | `#CFC6B8` | 引用正文 |
| `codeFill` | `#FCFCFA` | `#24231F` | 围栏代码块 |
| `codeText` | `#1C1815` | `#E9E1D5` | 代码正文 |
| `codeBorder` | `#E9E2D8` | `#393733` | 代码块边框 |
| `inlineCodeFill` | `#F2EEEA` | `#292622` | 行内代码背景 |
| `inlineCodeText` | `#B14A40` | `#F0A17F` | 行内代码文字 |
| `inlineCodeBorder` | `#D7CEC5` | `#4A4139` | 行内代码边框 |
| `tableStrongRule` | `#CBB9A6` | `#48443E` | 表格顶、底与表头线 |
| `tableRowRule` | `rgba(114,105,94,0.26)` | `rgba(216,210,197,0.14)` | 表格行线 |
| `tableHover` | `rgba(188,106,58,0.05)` | `rgba(217,120,85,0.08)` | iPad 指针悬停行 |

补充固定表面：front matter 明色使用 `#F6F1EA` / `#6B6158`，暗色使用 `#22211F` / `textSecondary`。链接按压或指针悬停可使用明色 `#9D552D`、暗色 `#F09B78`。

### 代码高亮

| 语义 | 明色 | 暗色 |
|---|---:|---:|
| 注释、元数据 | `#6F665D` | `#8F877B` |
| 关键字、类型、内建符号 | `#7B2FF7` | `#D8B4FE` |
| 字符串 | `#2F8F2F` | `#9AD98C` |
| 数字 | `#C06A2A` | `#F0A36A` |
| 标签、属性、链接、成员 | `#2C5EC6` | `#8FB8FF` |

## 4. 字体与排版

### 字体角色

- `documentSerif`：优先使用已获授权并随 App 打包的 Anthropic Serif；否则使用 iOS 的 New York / `Font.Design.serif`。中文回退到宋体风格时需先做真机可读性检查；若未内置合适中文衬线字体，优先系统中文字体，不要强行模拟。
- `interfaceSans`：SF Pro；中文自动回退 PingFang SC。用于导航栏、文件列表、搜索、菜单、状态文字。
- `codeMono`：SF Mono（或系统 monospaced design）；中文代码回退到等宽 CJK 字体。

### 基准尺寸

Typora 基准为 16 px，正文行高 1.62。iOS 实现应把它视为默认比例，而不是锁死字号：

| 样式 | 默认字号 | 字重 | 行高倍率 | 相对正文 |
|---|---:|---:|---:|---:|
| 正文 | 16 pt | 400 | 1.62 | 1.00 |
| H1 | 29.4 pt | 600 | 1.16 | 1.84 |
| H2 | 23.7 pt | 600 | 1.20 | 1.48 |
| H3 | 19.8 pt | 600 | 1.32 | 1.24 |
| H4 | 17.9 pt | 600 | 1.30 | 1.12 |
| H5 | 16 pt | 600 | 1.30 | 1.00 |
| H6 | 16 pt | 600 | 1.30 | 1.00 |
| 表格 | 14.9 pt | 400 / 表头 600 | 1.56 / 1.48 | 0.93 |
| 围栏代码 | 14.4 pt | 400 | 1.55 | 0.90 |
| 行内代码 | 14.4 pt | 400 | 随正文 | 0.90 |
| 行内公式 | 17.3 pt | 400 | 随正文 | 1.08 |

实现要求：

- 使用 Dynamic Type / `UIFontMetrics` 按正文比例缩放全部层级。
- 正文和标题字距为 0，不做人为 tracking。
- `strong`/`bold` 使用 700，并采用 `textStrong`。
- H6 使用 `textSecondary`，保持尺寸与正文一致。
- front matter 使用**正文同字体、同字号、同 1.62 行高**，不能做成小号等宽代码。
- 不依赖合成粗体；所用字体必须包含 400、600、700 字重或提供合理替代。

## 5. 阅读画布与响应式间距

- iPad / 大窗口正文列最大宽度：780 pt；极宽窗口可以逐级放宽到 820 pt、880 pt，但不应铺满屏幕。
- Regular 宽度：水平内边距 32 pt，顶部 32 pt，底部至少 104 pt。
- Compact 宽度：水平内边距 20 pt，顶部 24 pt，底部至少 84 pt。
- 所有边距叠加 safe area；键盘出现时底部留白应自然跟随编辑视口。
- 普通段落、列表、引用、表格上下间距为约 `0.78em`（默认约 12.5 pt）。
- 标题默认上间距 `1.45rem`（约 23 pt）、下间距 `0.7rem`（约 11 pt）；H1 顶部仅约 6 pt，使文档标题贴近开头但不拥挤。
- 分隔线宽 1 pt，上下 26 pt，颜色 `separator`，视觉不透明度约 75%。

## 6. Markdown 元素样式

### 段落、强调与链接

- 正文使用 `documentSerif`、`textPrimary`、1.62 行高。
- 粗体使用 700 + `textStrong`；斜体保留同字体家族的真实 italic。
- 链接静止时为 `accent` 且不加下划线；按压、键盘聚焦或指针悬停时显示下划线并切换到 link-hover 色。
- 编辑光标使用 `accent`；文本选择使用 `selection`。

### 标题

- 全部标题使用正文衬线字体、600 字重、`textStrong`。
- 不添加标题下划线、分隔线或彩色装饰。
- 标题中的行内代码继承标题字号，避免突然缩小。

### 列表与任务项

- 列表左缩进 23 pt，条目额外左内边距约 2.5 pt。
- marker 使用 `textSecondary`。
- 嵌套列表自身不额外增加上下段距。
- 任务勾选使用 `accent`；点击区域按 iOS 最小 44×44 pt 扩大，但视觉 checkbox 保持克制。

### 引用

- `quoteFill` 背景、`quoteText` 文字。
- 2 pt `quoteRule` 左边线，10 pt 圆角。
- 垂直内边距约 9 pt，水平内边距 16 pt。
- 嵌套引用不重复堆叠右侧内边距；避免形成多层厚卡片。

### 围栏代码块

- `codeFill` 背景、1 pt `codeBorder`、8 pt 圆角。
- 内边距：水平 16 pt、顶部约 14 pt、底部约 13.5 pt。
- 上间距 14 pt、下间距 18 pt；代码行高 1.55。
- 明色只允许近乎不可见的底边阴影；暗色只允许极弱的内高光。不要使用明显投影。
- 代码块内部的反引号或富文本片段不得再次套行内代码胶囊样式。

### 行内代码

- `inlineCodeFill` + 1 pt `inlineCodeBorder` + `inlineCodeText`。
- 视觉为胶囊形圆角；水平内边距约 `0.42em`，垂直约 `0.1em`。
- 字号为正文 90%，不因所在标题而缩小。

### 表格

- 不使用网格卡片或斑马纹；背景保持透明。
- 表格顶、底和表头下方使用 1 pt `tableStrongRule`。
- 正文行之间使用 1 pt `tableRowRule`；最后一行不画行线。
- 单元格垂直 12 pt，右侧 18 pt；最后一列无多余右边距。
- 表头 600、左对齐、底对齐；正文顶对齐。
- 数字使用 lining + tabular figures。
- iPad 指针悬停可用 `tableHover`；iPhone 不常驻行底色。

### Front matter、目录、数学与图片元信息

- front matter：16 pt 正文衬线、1.62 行高、16 pt 内边距、10 pt 圆角、无边框；只用轻微表面色区分。
- 目录块：复用 `quoteFill`，10 pt 圆角，水平 20 pt、垂直 18 pt 内边距。
- 行内数学比正文放大到 1.08 倍；块级数学编辑/选中态使用与 code/quote 同族的暖色表面。
- 图片的标题、路径或元信息使用 90% 正文字号、3 pt 小圆角，不抢夺图片主体注意力。

## 7. 应用界面与文档列表映射

Claude-like 的文档内容与应用 UI 使用不同字体角色，但必须共享颜色语言：

- 文档列表、文件树、目录、搜索、菜单全部使用 `interfaceSans`。
- 侧栏使用 `sidebarSurface`；当前项用 `activeFill`，并在 leading 边缘加 3 pt `accent` 指示条。
- 次要路径、摘要、展开箭头使用 `textSecondary`。
- iPad 指针悬停使用 `hoverFill`；触控按压态短暂使用同一颜色，不保留 hover。
- 弹层、快速打开、上下文菜单以 `windowSurface` / `codeFill` 为暖色表面，边框统一 `separator`。
- 搜索命中使用 accent 的低透明度填充，文字保持 `textStrong`。
- 导航栏与工具栏避免纯白或纯黑突变，应与 `canvas` / `windowSurface` 连续过渡。

## 8. 原生实现约束

1. 建立 `ClaudeTheme` 语义层：颜色动态切换，字体和几何只定义一次。
2. 阅读与编辑必须消费同一套 Markdown attributes，避免“阅读像 Claude、编辑像系统文本框”。
3. UIKit/TextKit 的 attributed string、SwiftUI 预览和导出渲染应共享字体比例与颜色 token。
4. 系统动态字体、增大对比度、Reduce Transparency、Smart Invert 下均需验收；暖色低对比边线不能承载唯一语义。
5. 触控操作保持 Apple 原生尺寸和反馈：视觉可以克制，但可点击区域不得小于 44 pt。
6. 暗色只覆盖颜色、阴影和极少数表面状态；间距、字号、圆角、Markdown 结构必须与明色完全一致。
7. 导出 PDF/打印时回到 13 pt 基准是 Typora 的打印行为；iOS 若支持导出，应单独定义 print profile，不要影响屏幕字号。

## 9. 验收基线

至少用同一份包含 H1–H6、长段落、中英文混排、粗斜体、链接、嵌套列表、任务项、引用、代码、表格、front matter、图片和数学公式的 Markdown fixture 验收：

- 明暗切换时只有颜色变化，文档不重排、不跳动。
- iPhone 与 iPad 的正文行长舒适，iPad 不出现横跨全屏的长行。
- 编辑态与阅读态在字号、行高、段距、标题层级上肉眼一致。
- Dynamic Type 放大后不截断代码操作、表格滚动和标题。
- 中文 fallback 不出现粗体缺失、行高抖动或中英基线错位。
- VoiceOver 能区分标题、链接、列表、任务项、代码块和表格结构。
