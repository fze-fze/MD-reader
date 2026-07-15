# UI 汉化截图审计

> 状态：历史记录。文末顶部 `+` 浏览器截图属于恢复前版本；当前首页验收见 `homepage-restore-audit.md` 与 `homepage-qa/restored-homepage.png`。

审计范围：`docs/screenshots/*.jpg`、`docs/search-ui-qa/*.jpg`。仅依据截图中的可见文案判断，不涉及代码修改。

## 建议汉化

| 英文文案 | 建议中文 | 出现位置 | 判断 |
| --- | --- | --- | --- |
| `Create Document` | `新建文档` | `screenshots/document-browser.jpg` | 明确的系统操作按钮，应汉化。 |
| `Untitled` | `未命名` | `screenshots/document-browser.jpg`、`screenshots/native-editor-v2.jpg`、`screenshots/native-reader-v2.jpg`、`search-ui-qa/01-reader-default.jpg` | 默认文档标题/占位名称，属于界面状态文案，应汉化。编号形式同步为 `未命名 2`。 |

## 建议保留

| 可见英文 | 出现位置 | 保留理由 |
| --- | --- | --- |
| `Margin` | 多张截图 | 软件/产品名称。 |
| `Markdown` | 编辑器与阅读器正文 | 通用技术名称；中文语境中保留英文更自然。 |
| `iPhone`、`iPad`、`App` | 编辑器与阅读器正文 | Apple 产品及平台术语；其中“文件”App 是系统官方常见写法。 |
| `SWIFT`、`let writing = ...` | 阅读器代码块 | 代码语言标签与代码内容，不应翻译；如统一视觉规范，可仅将语言标签规范为 `Swift`。 |
| `Fitness`、`Watch` | `screenshots/app-icon-home.jpg` | iOS 主屏中的其他 App 名称，不属于本软件界面。 |
| `Aa`、`B`、`I`、`</>`、键盘字母 | `screenshots/native-editor-v2.jpg` | 编辑格式图标及系统键盘字符，不属于普通操作文案。 |

## 按截图检查

| 截图 | 待汉化项 | 备注 |
| --- | --- | --- |
| `screenshots/app-icon-home.jpg` | 无 | `Margin` 为 App 名称；其他英文来自系统主屏中的 App 名称。 |
| `screenshots/document-browser.jpg` | `Create Document`、`Untitled`、`Untitled 2` | 建议分别改为“新建文档”“未命名”“未命名 2”。 |
| `screenshots/native-editor-v2.jpg` | `Untitled` | 其余英文为品牌、技术名词、格式图标或系统键盘。 |
| `screenshots/native-reader-v2.jpg` | `Untitled` | `Margin`、`Markdown`、`iPhone`、`iPad`、`SWIFT` 与代码内容保留。 |
| `screenshots/reader-light.jpg` | 无 | 只出现应保留的名称、技术名词和代码。 |
| `search-ui-qa/01-reader-default.jpg` | `Untitled` | 搜索与编辑操作已为图标/中文。 |

## QA 结论

截图中没有发现其他明确的英文系统操作文案。实施时应检查 `Untitled` 是否同时来自新建文档默认命名、空标题回退值和示例数据，避免只替换某一个界面。`Create Document` 只在文档浏览器截图中出现，优先级最高。

## 当前构建运行态验收（2026-07-13）

- 构建：`/tmp/MarginLocalizationBuild/Build/Products/Debug-iphonesimulator/Margin.app`
- 环境：iPhone 17 Pro，iOS 26.4 模拟器。
- 最终结果：恢复内部场景标识后，最新构建安装、启动成功，文档浏览器首屏稳定呈现。
- 文案检查：`搜索`、`文件夹为空`、`最近项目`、`共享`、`浏览`均为中文；未发现需要汉化的英文系统操作文案。`Margin` 为软件/位置名称，保留合理；新增按钮和更多操作使用通用图标。
- 截图：`docs/localization-qa/current-document-browser.png`（已覆盖为第二次、最终一次运行态验收截图）。
- 历史说明：第一次验收因内部场景标识异常只显示空白视图，该结果已被本次成功验收取代。
