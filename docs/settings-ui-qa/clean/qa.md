# 阅读设置干净模拟器 UI QA

- 日期：2026-07-13
- 环境：iPhone 17e，iOS 26.4；首次为本轮安装 `com.fze.margin`
- 构建、安装、启动：成功
- UI 结果：阻塞

在未清理或修改原 iPhone 17 Pro 模拟器文档的前提下，改用另一台 iPhone 17e 构建安装。应用首次启动后仍停留于纯黑窗口，运行时 UI 树仅有根节点，无法进入 UIDocumentBrowser 或文档工作区。

因此无法验证阅读设置面板、浅色/深色即时切换、字号滑杆，以及旧说明文字是否移除。证据见 `fresh-simulator-black-screen.jpg`。
