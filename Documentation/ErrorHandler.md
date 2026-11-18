# 错误与日志

通过 `CallServiceListener` 获取错误、通话结束原因和远端成员事件。Example 的 Last call 显示最近一次结束结果，Logs 用于打开 SDK 日志。 [API 概览](APIOverView.md) · [Example](Example.md)

## 错误分类

`CallError` 是封装类，`module` 表示 `.im`、`.rtc`、`.business` 或 `.unknown`，`error.errorCode` 和 `errorMessage` 提供错误码和描述。业务错误包含 `.state`、`.param`、`.signaling` 和 `.unknown`。

```swift
final class CallEvents: NSObject, CallServiceListener {
    func didOccurError(error: CallError) {
        switch error.errorType {
        case .im(let code):
            print("IM", code.rawValue, error.errorMessage)
        case .rtc(let code):
            print("RTC", code.rawValue, error.errorMessage)
        case .business(let code):
            print("Call", code.rawValue, error.errorMessage)
        case .unknown:
            print("Unknown", error.error.errorCode, error.errorMessage)
        }
    }

    func didUpdateCallEndReason(reason: CallEndReason, info: CallInfo) {
        DispatchQueue.main.async {
            print("Call ended", info.callId, reason.rawValue, info.duration)
        }
    }
}
```

SDK 以弱引用保存 listener，宿主需要持有监听对象。界面操作切回主线程。IM 与 RTC 的具体错误码分别按官方 SDK 文档查询。 [环信错误码](https://doc.easemob.com/document/ios/error.html) · [声网错误码](https://doc.shengwang.cn/doc/rtc/ios/error-code)

## 结束原因

拒接、取消、忙线、超时和正常挂断通过 `didUpdateCallEndReason(reason:info:)` 上报。错误回调与结束原因可能分别发生，显示上一次通话结果时以结束原因为依据。完整枚举与本地、远端的含义见 API 概览。 [CallEndReason](APIOverView.md#通话结束原因)

## 常见问题

| 现象 | 检查 |
| --- | --- |
| `A call is already in progress` | 当前是否已有邀请或通话，按钮是否重复触发 |
| IM 登录失败 | App Key、User ID、IM token 是否对应，自动登录是否恢复了此前的账号 |
| 群成员列表或群呼叫失败 | 当前账号是否加入该群，群 ID 是否正确，资料提供者是否返回所需用户 |
| RTC token 或频道加入失败 | 环信音视频服务是否开通，网络、RTC token 和声网服务配置是否有效 |
| 普通推送收不到 | 通知授权、普通 APNs token 绑定、签名环境、环信证书名及设备离线状态 |
| VoIP 收不到 | 本机是否选择系统来电路径、`voIPPushToken` 是否有值、绑定日志是否成功 |
| 来电立即结束 | Last call 的结束原因、同一 callId 的信令、过期时间、多设备接听和系统上报错误 |
| 点击旧通知没有接听页 | 邀请是否已取消、超时或在其他设备处理，IM 是否已恢复连接 |

## 日志定位

日志包含 `EaseCallKit Log:` 前缀。先记录发生时间、主被叫账号、通话 ID、系统版本、集成组合及 App 前后台状态，再按通话 ID 查找。

| 关键字 | 含义 |
| --- | --- |
| `Could not bind the APNs token` | 普通 APNs token 绑定失败 |
| `Could not bind the VoIP token` | VoIP token 绑定失败 |
| `Could not report Apple CallKit call` | Apple CallKit 来电上报失败 |
| `Could not report LiveCommunicationKit call` | LiveCommunicationKit 来电上报失败 |
| `Update call end reason` | 通话结束原因同步 |
| `Failed to send call message` | 单聊邀请发送失败 |
| `Failed to send group call message` | 群组邀请发送失败 |

系统来电需在真机检查锁屏、后台、音频会话与蓝牙。模拟器验证 App 内来电时可关闭 `enableVOIP`，结合日志判断具体失败环节。 [系统来电](LiveCommunicationKit.md)
