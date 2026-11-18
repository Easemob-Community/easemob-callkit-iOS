# 接入与 Example

从当前项目选择 CocoaPods subspec 或 SwiftPM Traits，初始化 IM 后启用通话。

## Overview

项目依赖环信 IM SDK 4.26.0 和声网 RTC SDK 4.6.2，最低系统为 iOS 15.0。CocoaPods 的 EaseCallUIKit 使用国内默认组合，Overseas 使用双框架，OverseasCallKit 使用纯 Apple CallKit。

Swift 6.1 及以上可启用 LiveCommunicationKit 和 AppleCallKit Traits。默认 Trait 为 LiveCommunicationKit，纯 Apple CallKit 只启用 AppleCallKit。旧工具链使用兼容清单的默认组合。

宿主初始化 ChatClient，再在主线程调用 CallKitManager.shared.setup(config)。登录成功后设置 currentUserInfo，绑定普通 APNs token。默认通知点击转交 CallNotificationHandler，App 前后台事件转交 IM SDK。

```swift
import EaseCallUIKit

let config = CallKitConfig()
config.enableVOIP = true
CallKitManager.shared.setup(config)

// IM 已登录并连接后，按需发起语音呼叫。
CallKitManager.shared.call(with: "target-user-id", type: .singleAudio)
```

Example 使用 CocoaPods，在 Example 目录安装依赖后打开 workspace。首页支持编辑账号、自动登录、退出登录、输入目标用户或群 ID、查看通话状态和日志。完整步骤见仓库内的文档。 [Example](https://github.com/Easemob-Community/easemob-callkit-iOS#运行-example) · [集成指南](https://github.com/Easemob-Community/easemob-callkit-iOS#在-app-中集成)
