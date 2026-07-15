# 阅读设置最终 QA

- 完整 `xcodebuild test` 通过，3 个 `MarkdownParserTests` 均通过。
- iPhone 17 Pro / iOS 26.5 启动后可正常进入系统文档浏览器与阅读界面。
- 阅读设置 Sheet 可正常打开；界面中已不存在“Margin 的阅读与编辑画布共享…”说明文字。
- 浅色、深色选择均可即时改变设置 Sheet；关闭 Sheet 后文档画布同步为所选 Claude-like 配色。
- Markdown 块解析已从高频 `body` 计算移动到仅随文档内容变化执行的任务。
- 正文字号使用设置页本地草稿值，拖动结束或关闭设置时才写回文档页，避免拖动期间反复刷新整篇文档。

备注：iOS 27 的系统 Sheet、Liquid Glass 和分段控件仍可能存在平台自身的动画掉帧；本轮仅消除 Margin 可控的重复解析与状态传播成本。
