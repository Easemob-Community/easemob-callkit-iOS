# iOS 来电推送集成

最低部署目标为 iOS 15.0。发行市场决定集成组合，运行时使用系统版本和 `CallKitConfig` 选择本机来电方式。 [安装与初始化](Integration.md)

## 选择组合

| CocoaPods 入口 | SwiftPM Traits | iOS 15.0 至 17.3 | iOS 17.4 及以上 |
| --- | --- | --- | --- |
| `EaseCallUIKit` | 默认 `LiveCommunicationKit` | 普通 APNs，进入 App 接听 | VoIP Push + LiveCommunicationKit |
| `EaseCallUIKit/Overseas` | `LiveCommunicationKit`、`AppleCallKit` | VoIP Push + Apple CallKit | VoIP Push + LiveCommunicationKit |
| `EaseCallUIKit/OverseasCallKit` | 仅 `AppleCallKit` | VoIP Push + Apple CallKit | VoIP Push + Apple CallKit |

`config.enableVOIP` 默认 false，启用后本机才创建系统来电处理器。`enableAppleCallKit = false` 可关闭 Apple CallKit 路径。SwiftPM 的两个 Traits 都关闭时走普通 APNs 和 App 内来电。Traits 需要 Swift 6.1 及以上，旧清单只提供国内默认组合。 [SPM 配置](Integration.md#swift-package-manager)

## 宿主配置

1. 开启 Push Notifications，将普通 APNs 证书和 VoIP 证书上传至环信控制台。IM 初始化时配置 `ChatSDKOptions.apnsCertName`、`pushKitCertName`，证书环境与签名环境一致。
2. 系统来电开启 Background Modes 的 Voice over IP。在主线程初始化 `CallKitManager.shared.setup(config)`。
3. 请求普通通知授权，并转发 APNs token 与通知点击回调。恢复 IM 登录或切换账号后重新 `bindDeviceToken()`。
4. 开启 IM 自动登录，将 App 生命周期转发给 IM SDK。退出时使用环信的解绑 token 选项。

普通 APNs 注册、Scene 生命周期和登录示例见集成指南。当前 Example 的证书名写在 `AppDelegate.swift` 的 Debug、Release 分支。 [宿主回调示例](Integration.md#生命周期和普通推送转发) · [Example](Example.md) · [环信 APNs 集成](https://doc.easemob.com/document/ios/push/push_apns.html)

## 普通 APNs 来电

主叫 `enableVOIP = false` 时，邀请的 `em_apns_ext.extern` 携带包含下列字段的 JSON 字符串。推送端将这些自定义内容放入普通 APNs 的 `e` 字段，通知处理器支持对象和 JSON 字符串两种格式。

```json
{
  "msgType": "rtcCallWithAgora",
  "action": "invite",
  "callId": "unique-call-id"
}
```

被叫点击通知后，宿主调用 `CallNotificationHandler.shared.handle(response)`。SDK 记录待打开的 `callId`，等待 IM 恢复邀请，并通过主叫确认信令验证。邀请仍有效且本机可展示时，进入 App 内来电页。从桌面打开 App 时也会恢复有效邀请。过期、取消或已在其他设备处理的邀请按通话状态结束。

国内默认组合在 iOS 17.4 以下显示 `.inApp`，只需普通 APNs 绑定和通知授权。普通通知点击打开 App，接听动作在 App 内完成。

## VoIP Push 来电

主叫 `enableVOIP = true` 时，单聊、群聊和追加邀请统一加入以下消息扩展。

```swift
[
    "em_push_ext": [
        "type": "call",
        "custom": signaling
    ]
]
```

环信按被叫绑定信息处理 VoIP 推送。VoIP payload 的 `f` 是主叫 ID，`m` 是消息 ID，`g` 是可选群 ID，`e` 是邀请对象。当前解析器要求 VoIP 的 `e` 为对象。

```json
{
  "f": "caller-id",
  "m": "im-message-id",
  "e": {
    "msgType": "rtcCallWithAgora",
    "action": "invite",
    "callId": "unique-call-id",
    "callerDevId": "caller-device-id",
    "channelName": "rtc-channel",
    "type": 0,
    "ts": 1794960000000,
    "callerNickname": "Caller"
  }
}
```

`type` 是 `CallType.rawValue`，0 为单聊语音，1 为单聊视频，2 为群组通话。`ts` 使用主叫发送时的毫秒时间戳。群资料在 `callkitGroupInfo` 中。VoIP Push 负责唤起来电，后续接听、取消和结束通过 IM 信令同步。 [环信推送字段](https://doc.easemob.com/document/server-side/push_extension.html)

SDK 通过 PushKit 注册 token，在 token 更新和 IM 连接后尝试绑定。宿主可读取 `CallKitManager.shared.voIPPushToken`，或通过 `config.onVoIPTokenChange` 监听变化。nil 表示当前没有可用 token。`incomingCallPresentation` 表示配置的处理路径，注册和绑定是否成功要查看 token 与日志。

## 重复 Alert 的处理

如果同一次邀请的 VoIP 和 Alert 都送达，需要先核对环信回调中的消息 ID、设备 ID 和证书名，确认是否为同一台设备。现有 `em_push_ext.type = "call"` 的文档说明了 VoIP 通道，但未在本项目中实现按每台设备强制二选一的业务服务器。

环信提供 `em_push_filter.accept_notifier_name` 和 `ignore_notifier_name` 按证书过滤消息推送。将普通 APNs 的低版本来电设备与系统来电设备使用的证书名区分后，可评估在邀请上排除后者的普通 Alert，需先验证与 `type = "call"` 的组合效果。普通聊天仍需要普通 APNs。 [推送过滤字段](https://doc.easemob.com/document/server-side/push_extension.html) · [离线推送回调](https://doc.easemob.com/document/server-side/callback_offline_push.html)

Notification Service Extension 隐藏 Alert 需要 Apple 批准 `com.apple.developer.usernotifications.filtering`，且 Alert payload 带 `aps.mutable-content = 1`、请求使用 `apns-push-type = alert`。当前 Example 中没有通知服务扩展 target，也没有启用过滤权限。普通扩展清空内容时，系统会回退展示原始通知。 [Apple 过滤权限](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.filtering) · [扩展回调规则](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension/didreceive%28_%3Awithcontenthandler%3A%29)

## 真机验证

按 Example 的验证表分别检查前台、后台、锁屏、通知点击、多设备接听和超时。模拟器用于 App 内信令和界面测试，完整 VoIP 与系统来电在真机验证。 [Example 验证步骤](Example.md#验证能力)
