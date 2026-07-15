# 主题首页运行态 QA

- 日期：2026-07-14
- 工程：`Margin.xcodeproj`
- Scheme：`Margin`
- 模拟器：iPhone 17 Pro，iOS 26.4
- Bundle ID：`com.fze.margin`
- 结果：最新代码构建、安装、启动成功。

## 验收结果

| 检查项 | 结果 | 备注 |
| --- | --- | --- |
| 首页显示“Margin 文稿” | 通过 | 标题清晰可见。 |
| 首页显示“选取主题” | 通过 | 主色按钮清晰可见。 |
| 首页显示“开始书写” | 通过 | 次级按钮清晰可见。 |
| 下方系统文稿浏览器保留 | 通过 | 可见“Margin”、搜索、更多、创建文稿以及系统底部标签；模拟器无历史文稿，因此列表为空。 |
| 打开主题菜单 | 未完成 | 改为原生 `Menu` 后重新构建成功；自动化点按仍没有显示菜单，按约定停止继续尝试。 |
| Claude / GitHub 与选中状态 | 静态确认，运行态未确认 | 首页 `Menu` 由 `ReaderTheme.allCases` 驱动，选中项使用 `checkmark`；设置中的预览卡片仍使用 `checkmark.circle.fill` 和 `.isSelected`。未获得菜单截图。 |

## 截图

- `homepage-final.jpg`：最终代码在 iPhone 17 Pro / iOS 26.4 上稳定渲染后的首页。
- `homepage.jpg`：最新构建启动后的首页。
- `theme-tap-no-transition.jpg`：点按“选取主题”后界面仍停留首页的证据。
- `menu-tap-no-transition.jpg`：改为原生菜单并重新构建后，自动化点按仍未展开的证据。

## 简短 QA

首页整体结构与参考图一致：上方自定义欢迎卡片、下方系统文稿浏览器。标题、两个主操作按钮均已出现，系统浏览器未被替换。当前唯一运行态缺口是主题入口改为原生 `Menu` 后仍无法通过自动化点按展开；`snapshot_ui` 同时出现两组同名入口，可能是 `DocumentGroupLaunchScene` 与系统文稿浏览器窗口叠层导致工具命中了不可见副本，需要在 Simulator 中人工点按复核。

## 最终验证补充

- 父流程又用 Simulator 窗口自动化尝试了“选取主题”和“开始书写”；两者都只能聚焦可访问性控件，无法转换为设备触控，确认这是当前自动化链路的共同限制，并非只发生在主题菜单。
- 已移除 launch scene action 上的自定义按钮样式，交由 `DocumentGroupLaunchScene` 使用系统原生动作样式与命中区域。
- iOS 26.4 缺少测试所用的 Songti SC 字体，因此 Claude 主题现在随 App 打包 Anthropic Serif 与 Noto Serif SC，避免不同系统版本出现中文无衬线回退。
- 最终测试：7 项通过，0 项失败。
