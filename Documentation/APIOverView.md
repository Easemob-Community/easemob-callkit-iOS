# API 概览

本页按当前源码公开的 Swift 接口整理。导入模块使用 `import EaseCallUIKit`，默认、海外双框架和纯 Apple CallKit 使用同一组业务 API。 [完整集成](Integration.md) · [DocC 归档](EaseCallUIKit.doccarchive)

## CallKitManager

通过 `CallKitManager.shared` 访问。初始化、呼叫和界面相关操作在主线程执行。

| 接口 | 用途 |
| --- | --- |
| `setup(_ config: CallKitConfig? = nil)` | 注册通话监听，按安装能力与系统版本建立系统来电处理器 |
| `call(with userId: String, type: CallType, extensionInfo: [String: Any]? = nil)` | 发起单聊语音或视频通话 |
| `groupCall(groupId: String, extensionInfo: [String: Any]? = nil)` | 选择群成员并发起群组通话，或在当前群通话中追加邀请 |
| `accept()` | 接听当前来电 |
| `hangup()` | 按当前状态取消邀请、拒接或结束通话 |
| `addListener(_ listener: CallServiceListener)` | 注册弱引用事件监听 |
| `removeListener(_ listener: CallServiceListener)` | 移除事件监听 |
| `cleanUserDefaults()` | 清理当前用户的 RTC token、UID 映射等缓存 |
| `tearDown()` | 释放通话服务与系统来电资源 |

| 属性 | 访问与用途 |
| --- | --- |
| `config: CallKitConfig` | 只读引用，通过 `setup` 应用配置 |
| `currentUserInfo: CallProfileProtocol?` | 可读写，当前用户资料 |
| `profileProvider: CallUserProfileProvider?` | 可读写，Swift 异步用户和群资料提供者 |
| `profileProviderOC: CallUserProfileProviderOC?` | 可读写，Objective-C 资料提供者 |
| `usersCache: [String: CallProfileProtocol]` | 可读写，资料缓存 |
| `callInfo: CallInfo?` | 对宿主只读，当前通话信息 |
| `engine: AgoraRtcEngineKit?` | 对宿主只读，当前 RTC 引擎 |
| `incomingCallPresentation: IncomingCallPresentation` | 只读，本机实际配置的来电方式 |
| `voIPPushToken: Data?` | 只读，PushKit 当前 token，尚未注册或此组合无系统来电时为 nil |

## CallKitConfig

| 属性 | 默认值 | 含义 |
| --- | --- | --- |
| `enableVOIP` | `false` | 呼出邀请标记 `em_push_ext.type = "call"`，并在本机安装能力和系统版本允许时启用系统来电 |
| `enableAppleCallKit` | `true` | 允许已集成的 Apple CallKit 路径，LiveCommunicationKit 路径优先 |
| `enablePIPOn1V1VideoScene` | `false` | 开启单聊视频 PiP |
| `onVoIPTokenChange` | `nil` | 主线程回调 `(Data?) -> Void`，通知 VoIP token 更新或失效 |
| `ringTimeOut` | `30` | 邀请有效期与振铃超时，单位秒 |
| `maximumConversationGroups` | `1` | LiveCommunicationKit 的最大会话组数 |
| `maximumConversationsPerConversationGroup` | `1` | 每个系统会话组的最大会话数 |
| `disableRTCTokenValidation` | `false` | RTC token 校验相关配置，按 RTC 服务配置使用 |

调整系统来电能力时，在结束当前通话后调用 `tearDown()` 并使用新配置 `setup`。仅修改已持有的 config 字段不会重新创建已存在的来电处理器。

## 来电呈现与普通 APNs

`IncomingCallPresentation` 有 `.inApp`、`.liveCommunicationKit` 和 `.appleCallKit`。该属性表示本机配置的处理路径，实际 PushKit token 是否注册成功需结合 `voIPPushToken` 与日志确认。

| CallNotificationHandler.shared 接口 | 宿主调用位置 |
| --- | --- |
| `registerForNotifications(completion:)` | 请求普通通知授权并向系统注册 APNs，主线程调用，completion 参数为 `(Bool, Error?)` |
| `didRegister(deviceToken: Data)` | 转发系统 APNs token 注册回调 |
| `bindDeviceToken()` | 登录、自动登录恢复或切换账号后重新绑定普通 token |
| `handle(_ response: UNNotificationResponse) -> Bool` | 处理通知默认点击动作，返回是否匹配来电通知 |
| `handle(userInfo: [AnyHashable: Any]) -> Bool` | 处理已提取的通知内容，匹配后等待 IM 邀请和确认信令 |

处理器返回 true 表示识别出匹配的来电通知。旧邀请是否仍有效由后续信令与超时状态判断。 [来电推送](IncomingCalls.md)

## 通话类型和状态

| CallType | 说明 |
| --- | --- |
| `.singleAudio` | 单聊语音 |
| `.singleVideo` | 单聊视频 |
| `.groupCall` | 群组音视频 |

| CallState | 说明 |
| --- | --- |
| `.idle` | 空闲 |
| `.dialing` | 主叫拨号 |
| `.ringing` | 被叫振铃 |
| `.answering` | 已进入接听和通话处理阶段 |

`CallInfo` 携带 `callId`、主被叫 ID 与设备 ID、`channelName`、`type`、`state`、`duration`、`inviteMessageId`、群组信息与 `extensionInfo`。`CallState` 的 `.answering` 还需结合 RTC 远端加入事件判断媒体连接，状态枚举本身没有单独的 connected 值。

## 通话结束原因

| CallEndReason | 含义 |
| --- | --- |
| `.hangup` | 通话挂断 |
| `.cancel` | 本机取消拨号 |
| `.remoteCancel` | 对方取消拨号 |
| `.refuse` | 本机拒接 |
| `.remoteRefuse` | 对方拒接 |
| `.busy` | 忙线 |
| `.noResponse` | 本机未响应或等待超时 |
| `.remoteNoResponse` | 对方未响应 |
| `.handleOnOtherDevice` | 已在其他设备处理 |
| `.abnormalEnd` | 异常结束 |

## CallServiceListener

所有方法均为可选实现。监听者由宿主持有，UI 更新切回主线程。

```swift
func didOccurError(error: CallError)
func remoteUserDidJoined(userId: String, channelName: String, type: CallType)
func remoteUserDidLeft(userId: String, channelName: String, type: CallType)
func didUpdateCallEndReason(reason: CallEndReason, info: CallInfo)
func onRtcEngineCreated(engine: AgoraRtcEngineKit)
func onReceivedCall(callType: CallType, userId: String, extensionInfo: [String: Any]?)
```

## 资料与资源

`CallUserProfileProvider` 通过 `fetchUserProfiles(profileIds:) async` 和 `fetchGroupProfiles(profileIds:) async` 返回 `[CallProfileProtocol]`。`CallUserProfile` 可直接作为默认实现，群资料同样返回遵循 `CallProfileProtocol` 的对象。

`CallAppearance` 提供颜色、语言、头像占位图、通话背景与 `resourceBundle` 配置。图片、铃声和本地化在 `CallResource.bundle` 中，由 CocoaPods 或 SwiftPM 自动打包。 [集成指南](Integration.md)
