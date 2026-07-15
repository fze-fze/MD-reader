# Claude-like 中英文字体级联 UI QA

- 日期：2026-07-14
- 环境：iPhone 17e，iOS 26.4；独立 QA App，直接复用主工程 `MarkdownReaderView` 与 `MarkdownEditorView`
- 结果：通过

## 验收结论

- 中文呈现出明显的宋体笔形与衬线特征，不是苹方的无衬线观感。
- 英文保持 New York / Claude-like serif 风格，中英文混排协调。
- 阅读态一级、二级标题的粗体层级清楚，正文常规字重稳定，Swift 代码块保持等宽字体，没有明显回归。
- 编辑态与阅读态使用同一套中英文 serif 级联；Markdown 原文中的中英文混排观感一致。

## 截图

- `reader-mixed-fonts.jpg`
- `editor-mixed-fonts.jpg`

说明：为避开文档场景已知黑屏，本次在 `/tmp` 工程副本中替换启动入口为隔离 QA 画布；主源码未修改。
