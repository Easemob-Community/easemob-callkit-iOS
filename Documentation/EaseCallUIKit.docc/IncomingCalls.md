# 来电呈现与推送

普通 APNs 与 VoIP Push 共用 IM 邀请和通话状态。

## Overview

enableVOIP 默认 false。启用且包含 LiveCommunicationKit 时，iOS 17.4 及以上优先走 LiveCommunicationKit。其余版本根据所选组合与 enableAppleCallKit 判断是否使用 Apple CallKit。最终路径通过 incomingCallPresentation 读取。

普通通知的 e 支持对象或 JSON 字符串，携带 msgType、action 和 callId。通知点击恢复 App 后，还需 IM 邀请和主叫确认，过期或已结束邀请由状态机处理。

VoIP Push 使用 f 传主叫 ID，m 传消息 ID，e 传完整邀请对象。SDK 注册并绑定 PushKit token，宿主通过 voIPPushToken 或 onVoIPTokenChange 读取变化。系统来电接听、挂断和静音与 IM 信令和 RTC 音频状态同步。

系统来电配置方式和真机验证见项目文档。 [来电推送](https://github.com/Easemob-Community/easemob-callkit-iOS#文档) · [系统框架](https://github.com/Easemob-Community/easemob-callkit-iOS#文档)

## Topics

### 通知入口

- ``CallNotificationHandler``
- ``IncomingCallPresentation``
- ``CallKitConfig``
