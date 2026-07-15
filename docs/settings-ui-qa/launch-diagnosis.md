# 启动黑屏诊断

> 状态：历史记录。该诊断针对从 `DocumentGroup` 切换到 UIKit 浏览器时的会话迁移；当前项目已恢复 `DocumentGroup`，不再使用文中所述 UIKit 启动链。

## 最可能根因

黑屏由架构切换后残留的 `UISceneSession` 引起，而不是当前 `Info.plist` / `MDReaderApp` / `AppSceneDelegate` 启动链本身缺失。

受影响的 iOS 26.2 simulator 仍恢复旧 SwiftUI `DocumentGroup` session：持久状态明确记录 `SwiftUI.AppSceneDelegate` 和旧 `DocumentGroup-editor(...)` scene ID。当前应用已经改为 UIKit 入口，要求 `Margin.AppSceneDelegate` 创建 `UIWindow`。系统重连旧 session 时沿用旧 scene configuration，新的 `AppSceneDelegate.scene(_:willConnectTo:)` 没有成为该 scene 的窗口创建者，于是进程存活、没有 crash，但前台只有状态栏和黑色 scene，UI 树也没有应用内容。

## 为什么判断不是当前启动代码写错

- 源码会返回名为 `Document Browser` 的 scene configuration，并指定 `AppSceneDelegate.self`。
- 源码 scene delegate 会创建 `UIWindow`、设置 `DocumentBrowserViewController` 根控制器并 `makeKeyAndVisible()`。
- 构建产物 Info.plist 已展开为 `Margin.AppSceneDelegate`，二进制也包含该类。
- 受影响运行的 app stdout 与 oslog 没有 fatal exception；黑屏时进程持续存在。

## 最小修复建议

当前项目仍处于开发期，最小且最可靠的处理是：先备份 iOS 26.2 simulator 容器中的测试 Markdown 文件，再卸载该 simulator 上的 `com.fze.margin` 并重新安装当前构建，或直接使用一个新的 simulator。这样会让系统创建使用 `Margin.AppSceneDelegate` 的全新 scene session。

不要仅反复 build/run；普通覆盖安装会保留 `Library/Saved Application State`，旧 `SwiftUI.AppSceneDelegate` session 仍可能被再次恢复。

如果未来需要让已发布版本从 SwiftUI `DocumentGroup` 原地迁移到 UIKit，而不能要求用户重装，应增加一次性的 scene-session 迁移：在 app delegate 启动阶段识别迁移版本，销毁旧持久 session，并请求一个采用 `Document Browser` 配置的新 session。该逻辑需谨慎保护为一次性执行，避免影响用户的正常多窗口/文档状态。

## 验收建议

重装或换新 simulator 后首次启动应直接出现系统 Document Browser；UI 树应包含导航栏、搜索框和浏览区域。随后再验证打开已有 `.md`、新建文档和返回浏览器。
