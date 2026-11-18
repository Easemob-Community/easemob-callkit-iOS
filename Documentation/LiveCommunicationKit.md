# 系统来电框架

本项目通过 `CallKitManager` 统一接入 PushKit、LiveCommunicationKit 和 Apple CallKit。宿主调用公开的配置与通话 API，内部的 `LiveCommunicationManager`、`AppleCallKitPresenter` 和 `VoIPPushRegistry` 由 SDK 创建和管理。 [完整集成](Integration.md) · [来电推送](IncomingCalls.md)

## 框架选择

`setup` 根据编译能力和 `config.enableVOIP` 选择处理器。包含 LiveCommunicationKit 且系统为 iOS 17.4 及以上时优先使用它。低于该版本，或集成组合没有 LiveCommunicationKit 时，已集成且配置允许的 Apple CallKit 才参与选择。最终结果可读取 `incomingCallPresentation`。

默认国内组合只包含 LiveCommunicationKit，iOS 17.4 以下为 `.inApp`。海外双框架提供 `.appleCallKit` 的低版本路径。海外纯 Apple CallKit 全版本选择 `.appleCallKit`。最低系统仍为项目要求的 iOS 15.0。 [组合对照](IncomingCalls.md#选择组合)

## 配置

在初始化环信 IM 时设置自己的 `apnsCertName` 和 `pushKitCertName`，启用 Push Notifications 与 Voice over IP 后台模式。证书上传、签名环境和设备 token 绑定都完成后启用配置。

```swift
let config = CallKitConfig()
config.enableVOIP = true
config.enableAppleCallKit = true
config.maximumConversationGroups = 1
config.maximumConversationsPerConversationGroup = 1
config.onVoIPTokenChange = { token in
    // 按业务需要同步到自己的设备登记接口。
    print("VoIP token available", token != nil)
}
CallKitManager.shared.setup(config)
```

`setup` 在主线程调用，配置发生变化时先结束通话、`tearDown()`，再 `setup(newConfig)`。`onVoIPTokenChange` 在主线程回调。

## LiveCommunicationKit

`LiveCommunicationManager` 用 `ConversationManager` 上报系统来电，管理 Join、End、Mute 操作。`Conversation.Update` 携带主叫 Handle 和语音、视频能力；群组数量与每组会话上限来自 `CallKitConfig`。来电 UUID 在当前邀请中复用。

PushKit token 与 payload 由 `VoIPPushRegistry` 处理。宿主收到的 payload 需要包含完整的通话 ID、主叫设备 ID 和频道名，最小示例见来电推送文档。 [VoIP payload](IncomingCalls.md#voip-push-来电)

## Apple CallKit

`AppleCallKitPresenter` 使用 `CXProvider` 与 `CXCallController` 上报来电和发起系统操作，通过 `CXAnswerCallAction`、`CXEndCallAction`、`CXSetMutedCallAction` 同步接听、挂断和静音。RTC 媒体连接与系统音频会话激活相协调。

## 处理流程

1. PushKit 收到 VoIP Push，解析为 `CallInfo`。
2. SDK 判断邀请是否完整、新鲜，以及是否已结束或与当前来电重复，并上报系统来电。
3. 用户接听后，系统操作进入 SDK 的接听流程，等待 IM 确认与媒体连接。
4. 主叫取消、超时、拒接或其他设备处理时，同步结束当前来电。
5. 系统操作完成后清理 UUID、会话和待处理操作，释放对应音频状态。

VoIP Push 需要及时完成系统来电上报，接听有效性还要结合 IM 信令。系统来电的展示、锁屏交互、蓝牙和音频切换使用真机验证。 [Apple PushKit 指南](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit) · [Apple CallKit 示例](https://developer.apple.com/documentation/callkit/voip-calling-with-callkit)

## 日志排查

`Could not report LiveCommunicationKit call` 或 `Could not report Apple CallKit call` 表示系统来电上报失败。`Could not bind the VoIP token` 表示环信绑定失败。结合 `callId`、`Update call end reason` 和 Example 的 Last call 判断是上报问题、信令结束还是音频连接问题。 [错误与日志](ErrorHandler.md)
