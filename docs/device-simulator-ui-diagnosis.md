# 真机与模拟器界面差异诊断

> 状态：历史记录。2026-07-13 后续已按用户要求恢复 SwiftUI `DocumentGroup` 首页；文中“当前顶部 `+` 形态”仅描述恢复前的 UIKit 版本。

日期：2026-07-13
范围：只读比较真机截图、对话中的 Simulator 截图，以及 `docs/localization-qa/current-document-browser.png`。

## 结论

真机与对话中的模拟器截图并不是两套业务界面；两者都属于 iOS 系统文档浏览器的旧 `DocumentGroup` / “Create Document”卡片形态。它们之间最显眼的差异主要由**系统外观、当前标签和本机文件状态**造成：

- 真机是深色模式，选中“最近项目”，并存在多条来自 iCloud Drive 与“我的 iPhone”的最近文档。
- 模拟器是浅色模式，选中“浏览”，进入 `Margin` 位置，只有 `Untitled 2` 等模拟器本地数据。
- 系统文档浏览器会根据当前标签、项目数量、可用高度和系统外观重排卡片及工具栏，因此顶部标题、按钮、文件面板位置不会逐像素一致。

不过，这两张截图都**不是当前仓库最终代码对应的首屏**。当前实现已改为 `UIDocumentBrowserViewController`，关闭系统创建占位卡片，并在顶部提供自定义 `+`：

- `Margin/App/MDReaderApp.swift:10-15` 将场景接到 `AppSceneDelegate`。
- `Margin/App/AppSceneDelegate.swift:16-19` 以 `DocumentBrowserViewController` 作为根控制器。
- `Margin/App/DocumentBrowserViewController.swift:47-59` 设置 `allowsDocumentCreation = false`，并添加“新建文稿”加号。
- `docs/localization-qa/current-document-browser.png` 与该实现一致：顶部有 `+`，没有 “Create Document” 大卡片。

所以，如果现在某台设备仍显示 “Create Document”，可以直接判断它运行的是切换入口前安装的旧二进制，或尚未重新安装当前构建；这不是单纯由屏幕尺寸造成的。

## 三张截图对照

| 证据 | 外观 / 状态 | 可见数据 | 构建形态判断 |
| --- | --- | --- | --- |
| 真机截图（1260×2736，Display P3） | 深色；“最近项目” | 多个真机 / iCloud 最近文档 | 旧的系统创建卡片形态 |
| 对话中的 iPhone 17 Pro Simulator（iOS 26.2） | 浅色；“浏览” | `Margin` 文件夹及少量模拟器文档 | 旧的系统创建卡片形态 |
| `current-document-browser.png`（368×800） | 浅色；“浏览” | 文件夹为空 | 当前 `UIDocumentBrowserViewController` + 顶部 `+` 形态 |

## 各因素影响排序

1. **不同运行状态：高影响。** 深浅色、选中的“最近项目 / 浏览”、最近文档数量和存储位置足以解释两张旧界面的主要视觉差异。
2. **不同构建代际：确定存在。** 用户两张截图都有 “Create Document”，而当前源码明确禁用它；与最新 QA 截图比较时，这一项是结构差异的主因。
3. **系统小版本：低到中等影响。** 对话明确模拟器为 iOS 26.2，最新 QA 记录为 iOS 26.4；系统文档浏览器的材质、间距和工具栏可能有细节变化，但没有证据表明它是两张用户截图差异的主因。真机系统版本未提供。
4. **屏幕尺寸：低影响。** 分辨率会影响缩放和留白，但两张用户截图的结构差异不能仅靠尺寸解释。

## 时间线佐证

- 对话中的 Simulator appshot：约 23:07。
- 当前 App 入口文件 `MDReaderApp.swift` 的修改时间：23:10:52。
- 真机截图：23:11，可能仍是修改前已安装的 App。
- 最新本地化 QA 截图：23:12:31，已显示当前顶部 `+` 形态。

这条时间线与“截图时设备仍在运行旧安装包、随后模拟器才完成当前构建验收”一致。

## 建议验收方式

在真机和模拟器分别卸载旧 App，再从同一个 Xcode scheme / commit 重新安装；将两边都设为同一深浅色、切到同一个标签，并准备相同的测试文件。此时仍可能因 iOS 26.2 与 26.4 的系统组件差异出现少量材质和间距变化，但界面结构应统一为顶部 `+`、不再出现 “Create Document” 大卡片。
