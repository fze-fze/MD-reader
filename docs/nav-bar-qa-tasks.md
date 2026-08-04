# 顶栏改造验收任务（分支 `claude/md-reader-extra-column-bug-9elfuz`）

给本地会话执行。改动背景：外部 App 打开文件时会多出一条导航栏，且跨文档残留、只有杀进程才消失。根因是 App 自绘了一条顶栏并用 `.toolbarVisibility(.hidden, for: .navigationBar)` 藏系统那条，而外部打开路径上文档在 SwiftUI 应用该偏好之前就已推入导航控制器，于是两条栏同时在场；栏的显隐属于 `UINavigationController` 状态，所以会一直留着。

本分支的做法：**不再自绘顶栏，改用 DocumentGroup 自己的文档导航栏**（返回按钮、文件名、文件名旁的 ⌄ 标题菜单都由系统按打开的文档生成），App 的搜索 / 编辑 / "…" 三个入口作为 `WorkspaceToolbarContent` 放进系统栏右侧。

已删除：`Margin/App/PagesDocumentNavigationBar.swift`、`Margin/App/DocumentNavigationBarHider.swift`、`MarkdownTheme` 的 `navigationControl` / `navigationSurface` / `navigationGlassTint`、`workspace.back` 文案。
已重命名：`Margin/App/PagesWorkspaceToolbar.swift` → `Margin/App/WorkspaceToolbar.swift`（`PagesWorkspaceToolbar: View` → `WorkspaceToolbarContent: ToolbarContent`）。

**这些代码没有在任何机器上编译或运行过。** 下面的任务按依赖顺序排列，T1 之前的失败会阻塞后面全部。

```sh
git fetch origin claude/md-reader-extra-column-bug-9elfuz
git checkout claude/md-reader-extra-column-bug-9elfuz
```

不要开 PR。每个任务按末尾的模板回报。

---

## T0 — 编译与单元测试

**做什么**

```sh
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphonesimulator build

xcodebuild test -project Margin.xcodeproj -scheme Margin \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

**通过标准**：两条都成功。测试文件删掉了两个只服务已删除类的用例，其余未改动，应全绿。

**可能的编译错误与修法**

- `WorkspaceToolbarContent` 的 `body` 里 `ToolbarItem` 报类型错误 → `ToolbarContent` 的 `body` 是 `@ToolbarContentBuilder`，确认三个 `ToolbarItem(placement: .topBarTrailing)` 都在同一层，没有被 `if` 包住。
- `.tint(theme.accent)`（`DocumentWorkspaceView.swift:102`）如果和 `ToolbarContent` 的环境推断打架，改成放在 `.toolbar { }` **之前**。
- 报 `MarkdownTheme` 找不到 `navigation*` → 说明还有地方引用了删掉的 token，把引用一并清掉，别把 token 加回来。

---

## T1 — 核心回归：从其他 App 打开文件（iPhone 真机）

这是整件事的验收点。

**做什么**

1. 杀掉后台里的 Margin，重新装本分支的构建。
2. 从"文件" App 里长按一个 `.md` → 共享/用其他应用打开 → Margin。
3. 记录顶部一共几条栏，截图。
4. **不要杀后台**，返回文档浏览器，再从浏览器打开另一个文件；再从别的 App（飞书 / 微信 / Safari 下载的 md 都行）打开第三个文件。
5. 每一步都看顶部栏数量。

**通过标准**：全程只有一条顶栏；栏上是返回箭头 + 文件名 + ⌄，右侧是放大镜、编辑、"…"。

**失败时**：截图 + 说明是在第几步出现的、当时是冷启动还是 App 已在后台。

---

## T2 — 常规路径没被改坏

**做什么**：从 Margin 自己的文档浏览器打开文件 → 返回 → 再打开另一个文件；用侧滑手势返回一次。

**通过标准**：顶栏正常、返回按钮可用、侧滑返回可用（`InteractivePopGestureRestorer` 保留着，理论上系统栏回归后它是空转）。

**失败时**：如果侧滑返回失效，先试着把 `.background(InteractivePopGestureRestorer())`（`DocumentWorkspaceView.swift:103`）注释掉再测一次，报告两种情况的差异 —— 这决定这个 helper 是否该退休。

---

## T3 — 右侧三个入口逐个点

**做什么**：在阅读模式下依次验证

1. 放大镜 → 底部搜索条弹出，输入关键词有高亮和计数，回车/箭头能跳转，关闭正常。
2. 编辑（铅笔）→ 进编辑模式；此时再点放大镜 → 应弹出系统查找面板（不是底部搜索条）；点"完成"回到阅读模式，正文内容与编辑一致。
3. "…" 菜单 → 大纲、文档信息、阅读设置、拷贝、移动、重命名、导出（Markdown / PDF / HTML）、打印，**每一项都点一次**。

**通过标准**：功能与改造前一致；菜单里不再有"文件名"分区标题（文件名现在显示在栏上），其余项一个不少。

**失败时**：写明哪一项、什么现象。导出/打印涉及 `DocumentActionsModifier`，未改动，若失效多半是菜单绑定问题。

---

## T4 — 重命名后，栏上的名字会不会更新（最可能失败的一项）

**背景**：系统栏的标题跟的是 `UIDocument`，而 DocumentGroup 发布给我们的 `fileURL` 在重命名后会滞后（`renamedFileURL` 这个补丁就是为它存在的）。改造前顶栏是我们自己画的、用的是补过的名字；现在交给系统了，行为未知。

**做什么**：打开一个文件 → "…" → 重命名 → 改成一个明显不同的名字 → 确认。

**通过标准**：栏上的文件名立刻变成新名字；再点"…" → 文档信息，里面显示的也是新名字/新路径。

**失败时（栏上仍是旧名字）**：在 `DocumentWorkspaceView.swift` 的 `.toolbar { }` 之前加

```swift
.navigationTitle(displayName)
```

重测。如果加了之后出现"两个标题重叠"或标题闪烁，改回去并报告 —— 那说明要走 `.toolbar(removing: .title)` + 自定义标题的路子，需要重新设计。

---

## T5 — 调查：系统标题菜单里到底有什么

**做什么**：点顶栏上的文件名 ⌄，把展开的菜单完整截图（包括顶部的文档头预览区，如果有的话）。iPhone 和 iPad 各一张。

**要回答的问题**

- 菜单顶部有没有文档预览卡片（文件名 / 类型 / 大小）？有没有分享按钮？能不能长按预览图拖拽？
- 菜单里有没有：重命名、拷贝/复制、移动、打印、导出？
- 有没有撤销/重做？

**为什么要问**：如果系统菜单已经原生提供了重命名/移动，那我们 "…" 菜单里的同名项和 `DocumentRenamer`（靠遍历视图层级找 `UIDocumentBrowserViewController`）+ `renamedFileURL` 这两处补丁就可以退休。这是下一轮清理的输入，本任务只收集信息，不改代码。

---

## T6 — iPad

**做什么**

1. iPad 上正常打开文档，看顶栏。
2. 分屏（Split View）里再开一个 Margin 窗口，两个窗口各开一个文件。
3. 在其中一个窗口里执行重命名和分享。

**通过标准**：只有一个返回按钮（不是两个）；重命名/分享的弹窗出现在**发起操作的那个窗口**上。

**失败时**

- 双返回按钮 → 报告即可，不要自己加 `.toolbarRole`。当前代码刻意没设 `.toolbarRole`（DocumentGroup 自己会设，覆盖它在历史上正是双返回按钮的成因）；若真机上确实需要，我们再决定设 `.editor` 还是 `.automatic`。
- 弹窗跑到另一个窗口 → 这是 `AppPresentationAnchor`（`Margin/App/AppPresentationAnchor.swift:7`）取"任意前台 keyWindow"造成的已知隐患，记录现象即可，属于另一条修复。

---

## T7 — 布局与观感

**做什么**

1. 深色 / 浅色各看一遍顶栏，两种主题（Claude / GitHub）各切一次。
2. 长文档滚动：正文从栏下方滚过时，栏的玻璃/模糊表现是否正常，第一行标题有没有被栏切掉。
3. 打开底部搜索条，确认它和键盘、底部安全区没有打架。

**通过标准**：右侧按钮的着色跟随主题强调色（`.tint(theme.accent)`）；正文没有被顶栏永久遮挡；没有多余的空白条。

**失败时**：截图 + 说明主题和深浅色。顶栏留白异常大/小的话，八成是 `ZStack` 里 `theme.canvas.ignoresSafeArea()` 与新的安全区交互，报告即可。

---

## T8 — 外部只读/异地文件的编辑与保存

**做什么**：从别的 App（不是 Margin 自己的容器）打开一个 md → 编辑几个字 → 返回 → 再从那个 App 打开同一个文件，确认改动在。

**通过标准**：改动被保存回原位置。

**失败时**：记录是否有系统报错弹窗。目前 App 没有自己的保存失败提示，如果这里静默丢改动，是一条独立的待修问题。

---

## 回报模板

每个任务一段：

```
T#：通过 / 失败 / 未测
设备与系统：iPhone 17 Pro, iOS 26.x（真机 / 模拟器）
现象：
截图：
```

T0 失败请直接贴完整报错。T1、T4 无论结果如何都请附截图。
