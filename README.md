# EaseCallUIKit for iOS

本项目基于环信 easemob-callkit-iOS 改造，增加国内与海外来电组合、CocoaPods subspec、SwiftPM Traits，以及用于验证登录、单聊、群聊和来电状态的 Example。Swift 模块和依赖名称均为 `EaseCallUIKit`。 [上游项目](https://github.com/easemob/easemob-callkit-iOS)

直接运行示例请看 [Example 使用说明](Documentation/Example.md)。在自己的 App 中接入请看 [完整集成步骤](Documentation/Integration.md)。

## 环境

- iOS 15.0 及以上，环信 IM SDK 4.26.0，声网 RTC SDK 4.6.2。
- Xcode 16 及以上。SwiftPM Traits 需要 Swift 6.1 及以上，Xcode 界面配置 Traits 需要 Xcode 26.4 及以上。
- 在环信控制台开通对应 App Key 的音视频服务，准备同一 App Key 下两个不同的测试账号和有效 IM token。

## 运行 Example

在仓库根目录执行以下命令，默认使用国内组合。

```sh
cd Example
pod install
open EaseCallUIKit.xcworkspace
```

海外双框架和纯 Apple CallKit 分别使用下面的命令安装，选择一个执行。

```sh
EASE_CALL_UIKIT_VARIANT=Overseas pod install
EASE_CALL_UIKIT_VARIANT=OverseasCallKit pod install
```

在 Xcode 中配置 Team 和 Bundle ID，并将 `Example/EaseCallUIKit/AppDelegate.swift` 中 Debug、Release 的 APNs 和 VoIP 证书名替换为自己的环信推送配置。首页从 `PublicDefines.swift` 读取 App Key、User ID、Token，支持修改后登录。登录成功后锁定输入，退出登录后可再次编辑，重启通过 IM 自动登录恢复会话。

选择 Audio 或 Video，输入目标用户 ID 后呼叫。选择 Group，输入已加入的群 ID，再选择群成员。首页显示连接状态、当前通话状态和 Last call 结束原因，Logs 可查看日志。锁屏来电、VoIP 推送和系统来电界面使用真机验证。 [配置与验证步骤](Documentation/Example.md)

## 在 App 中集成

### CocoaPods

通过新仓库的具体提交接入，将 `COMMIT_SHA` 替换为包含本次改造的提交 ID。

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'EaseCallUIKit', :git => 'https://github.com/Easemob-Community/easemob-callkit-iOS.git',
                      :commit => 'COMMIT_SHA'
end
```

按发行市场选择一个入口。

| CocoaPods 入口 | iOS 15.0 至 17.3 | iOS 17.4 及以上 |
| --- | --- | --- |
| `EaseCallUIKit` | 普通 APNs，进入 App 接听 | LiveCommunicationKit |
| `EaseCallUIKit/Overseas` | Apple CallKit | LiveCommunicationKit |
| `EaseCallUIKit/OverseasCallKit` | Apple CallKit | Apple CallKit |

安装后打开 App 的 `.xcworkspace`。系统来电需要启用 VoIP 并完成证书、设备 token 和后台模式配置。 [来电推送配置](Documentation/IncomingCalls.md)

### Swift Package Manager

在 Xcode 的 **File → Add Package Dependencies…** 输入本项目仓库地址，选择包含本次改造的提交或版本，把 **EaseCallUIKit** product 添加到 App target。在 Swift 6.1 及以上可选择 Traits。 [当前项目仓库](https://github.com/Easemob-Community/easemob-callkit-iOS)

| SwiftPM Traits | 对应组合 |
| --- | --- |
| 默认的 `LiveCommunicationKit` | 国内默认组合 |
| `LiveCommunicationKit` 和 `AppleCallKit` | 海外双框架 |
| 仅 `AppleCallKit`，关闭默认 Trait | 海外纯 Apple CallKit |

Swift 6.1 以下使用兼容清单，提供国内默认组合。本地验证可通过 **Add Local…** 选择本仓库根目录。 [SwiftPM 配置示例](Documentation/Integration.md#swift-package-manager)

### 初始化和呼叫

宿主先初始化并登录环信 IM，再在主线程配置 EaseCallUIKit。需要普通 APNs 来电时，同时转发通知注册和点击回调。 [初始化、登录与通知转发](Documentation/Integration.md#初始化与登录)

```swift
import EaseCallUIKit

let config = CallKitConfig()
config.enableVOIP = true
CallKitManager.shared.setup(config)

// IM 已登录且连接成功后，选择一种呼叫方式执行。
CallKitManager.shared.call(with: "target-user-id", type: .singleAudio)
CallKitManager.shared.groupCall(groupId: "joined-group-id")
```

两种包管理方式均自动打包图片、铃声和本地化资源。完整的用户资料、事件监听、退出登录与自定义配置见集成指南。 [完整集成步骤](Documentation/Integration.md)

## 文档

| 文档 | 内容 |
| --- | --- |
| [Example](Documentation/Example.md) | 示例运行、账号配置、证书和能力验证 |
| [集成指南](Documentation/Integration.md) | CocoaPods、SPM、初始化、通知转发与呼叫 |
| [API 概览](Documentation/APIOverView.md) | 当前公开接口、状态、结束原因和回调 |
| [来电推送](Documentation/IncomingCalls.md) | 国内外组合、普通 APNs、VoIP 和重复通知 |
| [系统来电](Documentation/LiveCommunicationKit.md) | LiveCommunicationKit 与 Apple CallKit 的处理流程 |
| [画中画](Documentation/PictureInPicture.md) | 单聊视频 PiP 配置与测试 |
| [错误与日志](Documentation/ErrorHandler.md) | 错误分类、结束原因和日志排查 |
| [信令](Documentation/Signaling.md) | 邀请、确认、应答与多设备处理 |
| [更新日志](Documentation/CHANGELOG.md) | 当前改造记录 |
| [DocC API 归档](Documentation/EaseCallUIKit.doccarchive) | 用 Xcode 打开，或按生成说明在浏览器预览 |
| [DocC 生成说明](Documentation/DocC.md) | 从当前源码重新生成归档 |

本项目遵循 MIT 许可证。 [LICENSE](LICENSE)
