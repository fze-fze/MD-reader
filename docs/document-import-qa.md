# DocumentGroup 新建文档导入问题 QA

## 结论

“Create Document” 后的 “Unable to Import Document” 不是写文件失败。补齐文档类型注册是必要修复，但后续在经过多轮热安装、保留多份 `Untitled` 文档的 iOS 26.4 模拟器上仍能间歇复现，因此类型注册不是唯一原因，不能将此项标记为完全关闭。

`MarkdownDocument` 使用 `net.daringfireball.markdown`，`CFBundleDocumentTypes` 也声明了该标识，但 `Info.plist` 原先没有用 `UTImportedTypeDeclarations` 告诉系统该 UTI 对应 `.md` / `.markdown`。因此 DocumentGroup 创建 `.md` 后，系统可能把它识别成动态 UTI，无法按应用声明的 Markdown 类型重新导入。

## 证据

- 最近两次 XcodeBuildMCP build-and-run 均成功；应用运行日志只有 iOS 26.4 模拟器的 WebKit Accessibility 重复类警告，没有应用崩溃或 `FileDocument` 解码异常。
- 模拟器应用容器完整存在，`Documents` 中留下 3 个新建结果：`Untitled.md`、`Untitled 2.md`、`Untitled 3.md`。
- 三个文件均为 389 字节、UTF-8、普通可读文件，说明 `fileWrapper(configuration:)` 已成功写入；失败发生在系统随后重新识别/导入文档的阶段。
- 主机类型数据库对 `.md` 返回动态 UTI，而 `UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)` 只在进程内构造类型，不能代替应用包里的扩展名注册。

## 修复

在 `Margin/Info.plist` 增加 `UTImportedTypeDeclarations`：

- UTI：`net.daringfireball.markdown`
- conforms to：`public.plain-text`
- extensions：`md`、`markdown`
- MIME：`text/markdown`

保留现有 `CFBundleDocumentTypes`、`LSSupportsOpeningDocumentsInPlace` 与 `UISupportsDocumentBrowser` 配置。

## 验证

- `plutil -lint Margin/Info.plist`：通过。
- XcodeBuildMCP iOS Simulator Debug build：通过（2.3 秒）。
- 构建产物 `Margin.app/Info.plist` 已包含完整 `UTImportedTypeDeclarations`。
- 未擦除、卸载或手动修改模拟器容器；原有 3 个测试文档均保留。

## 运行态复测

主流程曾在 iPhone 17 Pro（iOS 26.4）复测成功一次；本轮原生编辑界面回归中，经过反复安装且保留多份 `Untitled` 文档后再次出现导入提示。两次复现都没有应用崩溃，文档文件仍已成功写入。

当前判断：这更像 Document Browser / File Provider 在测试模拟器中的残留状态或重导入竞态，但在干净模拟器、真机和真实 iCloud Drive 上完成对照前，不把它归因于环境，也不再通过增加冲突 UTI 声明来猜测修复。

## 干净模拟器对照

本轮另选一个从未安装过 Margin 的 iPhone 17e（iOS 26.4），不擦除旧模拟器、不迁移旧文档：首次构建安装后点击 “Create Document” 直接成功进入 `Untitled`，阅读、编辑和自动保存链路正常，未出现导入提示。

因此当前将问题限定为旧 iPhone 17 Pro 测试环境中经过多轮热安装、保留多份同名文档后的 Document Browser / File Provider 状态。正式交付仍保留完整 `UTImportedTypeDeclarations`；下一阶段只需在真实 iCloud Drive 真机上做最终对照，不再修改 UTI 架构。
