# 文稿操作菜单适配审计

## 结论

Preview 截图展示的是“文件级”标题菜单；Margin 当前右上角“更多”菜单是“阅读级”菜单。建议保留现有“目录、阅读设置、文档信息”，并在文稿标题菜单补齐文件操作，而不是用一组菜单替换另一组。

当前 `DocumentWorkspaceView.swift:90-111` 已有：

- 目录：`list.bullet.indent`
- 阅读设置：`textformat.size`
- 文档信息：`info.circle`
- 分享文档 / 分享文本：`square.and.arrow.up`

当前缺少文件级的复制、移动和打印；用户看到的“重新命名”来自 `DocumentGroup` 提供的系统标题菜单，不在上述 `workspaceMenu` 代码中。

## Preview 截图结构

1. 顶部文件摘要：缩略图、文件名、类型与大小；右侧为分享按钮 `square.and.arrow.up`。
2. 第一组：锁定 `lock`。
3. 第二组：复制 `plus.square.on.square`、移动 `folder`、重新命名 `pencil`、导出 `square.and.arrow.up`（若要强调副本，可用 `square.and.arrow.up.on.square`）。
4. 第三组：打印 `printer`。

分隔线应按上述三组保留；危险操作若以后加入，应单独分组并使用 destructive role。

## Markdown 能力适配

| 动作 | 结论 | Margin 中的合理语义 |
| --- | --- | --- |
| 复制 | 可直接实现 | 复制当前 `.md` 文件，在同目录生成不重名副本；iCloud / 外部位置应使用协调式文件访问。 |
| 移动 | 可直接实现 | 调起系统位置选择器，把当前 `.md` 移到用户选择的目录，并处理安全作用域和移动后的 URL 更新。 |
| 重新命名 | 已由系统提供 | 保留 `DocumentGroup` 的原生重命名，避免再做一套重复入口。 |
| 分享 | 可直接实现 | 分享原始 Markdown 文件；当前有 `fileURL` 时的 `ShareLink` 已覆盖该语义。 |
| 导出 | 需先定义格式 | 若“导出”仅指分享原始 `.md`，可直接复用分享；若要 `.txt`、`.html` 或 `.pdf`，需先确定格式、样式、图片资源打包和链接处理。建议菜单先命名为“分享”，不要把未定义的格式转换称为“导出”。 |
| 打印 | 可直接实现 | 打印渲染后的 Markdown 阅读页，而不是源码；调用系统打印面板。外链图片加载失败时应给出明确结果。 |
| 锁定 / 加密 | 不适用于普通 Markdown | Preview 的“锁定”针对 PDF 安全能力；`.md` 没有标准密码或权限字段。除非定义私有加密容器及解锁流程，否则不应照搬。 |

## 推荐信息架构

- 点击标题：文件摘要、复制、移动、重新命名、分享、打印。
- 点击右上角“更多”：目录、阅读设置、文档信息。
- 分享只保留一个主要入口；若标题菜单已提供，右上角可移除重复的分享项。
- 所有图标按钮都应保留可读文字标签，例如 `Button("打印", systemImage: "printer")`，以满足 VoiceOver 和 Voice Control。

## 实施优先级

1. 复制、移动、分享原始 Markdown、打印。
2. 将现有文件分享迁入标题菜单，阅读菜单保持纯阅读能力。
3. 只有在确定导出格式后，再增加真正的“导出”。
4. 不实现 PDF 式“锁定”。

## 运行态 QA（2026-07-13）

- 环境：最终构建 `/tmp/MarginDocumentActionsBuild/Build/Products/Debug-iphonesimulator/Margin.app`，iPhone 17 Pro，iOS 26.5。
- 安装与冷启动：通过。
- 文稿入口：失败。点击“创建文稿”后，系统提示“无法导入文稿：未能完成操作。（com.apple.DocumentManager 错误 1。）”。
- 标题菜单：未进入文稿详情页，因此本轮无法确认“复制、移动、重新命名、分享、打印”五项，也没有生成 `docs/document-actions-qa/title-menu.png`。
- 结论：部分完成；按两次尝试上限停止。需先解决或绕过 DocumentManager 新建/导入失败，再复验标题菜单。

## 主流程补充验证

- 在加入 `RenameButton` 前，主流程曾成功打开测试文稿并通过可访问性树确认标题菜单显示“复制、移动、分享、打印”。
- 该次检查同时发现自定义 `toolbarTitleMenu` 会覆盖系统默认“重新命名”，随后已显式加入原生 `RenameButton()`。
- 补回重命名后的最终增量构建通过；3 个现有 `MarkdownParserTests` 通过。受上述模拟器 DocumentManager 状态影响，最终五项菜单截图仍未取得。
