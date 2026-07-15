# Margin 编译验收

日期：2026-07-13
环境：Xcode 26.6，iPhoneOS / iPhoneSimulator 26.5 SDK，禁用代码签名

## 结论

- 已修复 Xcode 工程将 `Info.plist` 同时处理并复制而产生的重复输出错误。
- 已修复 3 类 Swift 编译问题：不存在的 `UTType.markdown`、不可用的 `accessibilityLiveRegion` 修饰器，以及标题字号倍率被推断为 `Any`。
- 全部 App Swift 源文件已通过 iPhoneOS 26.5 SDK 的 Swift 6 类型检查。
- 随后改用 XcodeBuildMCP 的配套模拟器服务，在 iPhone 17 Pro（iOS 26.4）上完成构建、安装、启动与运行态 UI 检查。
- 3 个 Swift Testing 单元测试全部通过。

## 执行记录

### 1. Simulator build（首轮）

```sh
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphonesimulator -derivedDataPath /tmp/MarginDerivedData CODE_SIGNING_ALLOWED=NO build
```

结果：失败。`Margin/Info.plist` 同时进入 Copy Bundle Resources 与 ProcessInfoPlistFile，产生重复 `Info.plist` 输出。已在文件同步组中添加目标级排除规则。日志：`/tmp/margin-build.log`。

### 2. Simulator build（修复后）

执行同一命令。

结果：工程配置错误已消失；构建继续进入资源与 Swift 编译阶段，随后因 CoreSimulator 无可用 runtime 而失败。关键环境诊断为：CoreSimulator 当前版本 `1051.54.0`，低于 Xcode 所需 `1051.55.0`。日志：`/tmp/margin-build.log`。

### 3. 通用 iOS 设备构建尝试

```sh
xcodebuild -project Margin.xcodeproj -scheme Margin -sdk iphoneos -destination generic/platform=iOS -derivedDataPath /tmp/MarginDeviceDerivedData CODE_SIGNING_ALLOWED=NO build
```

结果：当前受限环境中 `xcodebuild` 在初始化失效的 CoreSimulator 服务时被终止（exit 143），未形成可用的完整构建结论。日志：`/tmp/margin-device-build.log`。

### 4. Swift 6 源码类型检查

```sh
xcrun --sdk iphoneos swiftc -typecheck -swift-version 6 -target arm64-apple-ios26.0 \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk \
  -module-cache-path /tmp/MarginSwiftModuleCache Margin/**/*.swift
```

结果：通过，无诊断。日志：`/tmp/margin-swift-typecheck.log`。

### 5. XcodeBuildMCP 模拟器构建与启动

目标：iPhone 17 Pro，iOS 26.4；Bundle ID：`com.fze.margin`。

结果：构建、安装和启动成功。首次截图发现 `DocumentGroup` 与应用内 `NavigationStack` 形成双层导航栏；删除多余导航层并将搜索栏改为按需出现后，再次构建成功。

## 单元测试

`MarginTests` 使用 Swift Testing 宏，已通过 XcodeBuildMCP 在 iPhone 17 Pro 模拟器运行：3 个测试通过，0 个失败，0 个跳过。

## 尚存问题

1. 普通 shell 下的 CoreSimulator 服务版本仍与 Xcode 不匹配；项目本身已通过 XcodeBuildMCP 的配套服务完成构建和测试。
2. AppIcon 已拆分为默认、深色和着色三个独立资源槽位；当前使用同一视觉候选，后续可再为 tinted 模式做单色专版。
