# 原生阅读与编辑界面 QA

## 本轮改进

- 删除顶部“阅读 / 编辑”图标分段控件，恢复系统文档标题。
- 阅读态工具栏改为 `搜索 / 更多 / 编辑`，由 iOS 26 自动组成 Liquid Glass 工具栏。
- 编辑态只保留强调色“完成”，点击“编辑”后自动聚焦原生 TextKit 编辑器。
- Markdown 格式栏仅在编辑焦点存在时出现，按 `格式 / 行内样式 / 块样式` 分组。
- `格式`菜单支持正文、标题 1、标题 2、标题 3；常用操作支持粗体、斜体、链接、行内代码、项目列表、任务列表和引用。
- 编辑字体继续使用 Claude-like 衬线正文，并将源码行高调整为更接近 Apple 备忘录的 1.36 倍。
- 模式切换支持 Reduce Motion，并提供克制的系统 selection feedback。
- 搜索结果浮层改用原生交互式 Liquid Glass，正文、引用和代码块不滥用玻璃材质。

## 验证

- Swift 6 / iOS 26 全量类型检查通过。
- XcodeBuildMCP 在 iPhone 17 Pro 模拟器构建、安装和启动成功。
- 运行态可访问性树确认编辑器自动获得焦点，格式栏 8 个入口均可访问。
- 干净 iPhone 17e（iOS 26.4）确认中文软件键盘会自动出现，格式栏稳定停靠在键盘上方。
- 点击“完成”后，软件键盘与格式栏均消失，并恢复 `搜索 / 更多 / 编辑` 阅读工具栏。
- “完成”按钮、阅读态搜索与更多菜单具有明确文本标签和至少 44pt 交互区域。
- 3 个 Swift Testing 测试通过，0 失败。

## 截图

- `docs/screenshots/native-reader-v2.jpg`
- `docs/screenshots/native-editor-v2.jpg`

## 环境说明

- 旧 iPhone 17 Pro 模拟器在保留多份测试文档并多轮热安装后，偶发显示 “Unable to Import Document”；干净 iPhone 17e 首次安装对照通过。详见 `docs/document-import-qa.md`。
- 真实 iCloud Drive 的最终同步体验仍应在带 Apple ID 的真机上复核。
