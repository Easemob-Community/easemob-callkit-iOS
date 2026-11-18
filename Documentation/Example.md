# Example 使用说明

示例入口为 `Example/EaseCallUIKit.xcworkspace`，使用 CocoaPods 管理依赖。界面、IM 生命周期与账号逻辑分别位于 `ViewController.swift`、`SceneDelegate.swift` 和 `AppDelegate.swift`。 [示例源码](../Example/EaseCallUIKit) · [返回 README](../README.md)

## 准备账号和权限

在环信控制台准备一个已开通音视频服务的 App Key，以及该 App Key 下两个不同用户的 IM token。两台设备分别登录不同账号。单聊输入目标用户 ID，群聊输入当前账号已经加入的群 ID。 [环信音视频服务开通](https://doc.easemob.com/callkit/ios/product_activation.html)

在 `PublicDefines.swift` 配置 `AppKey`、`userId` 和 `token` 的默认值，或在首页直接修改。首次点 Login 登录，后续启动由 `options.isAutoLogin = true` 恢复已保存的 IM 会话。自动登录恢复的是此前登录的账号，编辑默认值后需先 Logout 再重新登录。

## 安装和运行

在仓库根目录执行。

```sh
cd Example
pod install
open EaseCallUIKit.xcworkspace
```

默认组合支持普通 APNs，并在 iOS 17.4 及以上启用 LiveCommunicationKit。海外双框架选择下面的命令。

```sh
EASE_CALL_UIKIT_VARIANT=Overseas pod install
```

海外统一使用 Apple CallKit 时选择下面的命令。

```sh
EASE_CALL_UIKIT_VARIANT=OverseasCallKit pod install
```

切换后重新打开 workspace，执行构建。环境变量只作用于本次命令，后续运行不带变量的 `pod install` 会回到默认组合。`pod update` 同样可加该变量，例如 `EASE_CALL_UIKIT_VARIANT=Overseas pod update EaseCallUIKit`。

在 Example target 的 Signing & Capabilities 配置 Team、Bundle ID、Push Notifications，以及所需的 Background Modes。麦克风与摄像头用途说明已经包含在示例 Info.plist 中，需按自己的 App 文案调整。

## 推送证书

当前代码在 `AppDelegate.initializeIM(appKey:)` 中直接配置证书名。将 Debug 的 `iim_apns_dev`、`iim_voip_dev` 和 Release 的 `iim_apns_release`、`iim_voip_release` 替换成自己在环信控制台上传的证书名。普通 APNs 和 VoIP 是独立的 token 与通道。

Xcode 的 **Edit Scheme → Run → Build Configuration** 选择 Debug，**Archive → Build Configuration** 选择 Release。示例 Debug 的 Swift 编译条件包含 `DEBUG`，Release 使用 `#else` 分支，推送签名环境也要对应 development 或 production。

清空 `options.pushKitCertName` 可使示例的 `config.enableVOIP` 为 false，从而验证普通 APNs 邀请。国内默认组合在 iOS 17.4 以下即使配置了 VoIP 证书，也会选择 `.inApp` 来电。 [推送集成](IncomingCalls.md)

## 首页操作

| 区域 | 操作 |
| --- | --- |
| Account | 编辑 App Key、User ID、Token，点击 Login。登录后锁定输入，Logout 成功后可再编辑 |
| Audio / Video | 输入 Target User ID，点击发起呼叫或键盘 Go |
| Group | 输入 Target Group ID，进入成员选择页选取被叫 |
| Status | 查看连接状态、当前来电呈现方式、呼出推送方式与当前通话状态 |
| Last call | 查看上一次已结束、取消、拒接、超时、忙线或其他设备处理的结果，保存在当前页面会话中 |
| Logs | 打开日志文件，按 `callId` 查找通话相关记录 |

## 验证能力

| 场景 | 操作和预期 |
| --- | --- |
| 单聊语音、视频 | 两台设备登录不同账号，分别发起 Audio 与 Video，被叫接听、拒接并结束通话 |
| 群组通话 | 两个账号先加入同一群，主叫输入群 ID 后选择成员，验证加入、离开与追加邀请 |
| 自动登录 | 登录后重启 App，确认恢复账号，输入锁定，退出后支持修改 |
| 普通 APNs | 被叫先登录并允许通知，退到后台至 IM 离线后发起邀请，点通知或桌面图标进入，邀请仍有效时显示 App 内接听界面 |
| 系统来电 | 使用配置了 VoIP 的真机，后台或锁屏时呼叫，验证接听、拒接、静音、挂断和音频路由 |
| 多设备 | 同一被叫账号在多台设备登录，一台接听后其他设备结束振铃 |
| 来电结束状态 | 分别触发取消、拒接、超时和正常挂断，核对 Last call |
| 单聊视频 PiP | 开启配置，接通视频后收起或进入后台，验证系统 PiP、恢复页面与结束通话 |

当前示例通过证书名决定 `enableVOIP`，模拟器也执行这段配置。需要在模拟器验证 App 内信令时，将 `config.enableVOIP` 临时设为 false。VoIP 投递和系统来电使用真机验证。 [Apple CallKit 示例要求](https://developer.apple.com/documentation/callkit/voip-calling-with-callkit)

示例的 `SceneDelegate` 在 `sceneDidEnterBackground` 和 `sceneWillEnterForeground` 调用 AppDelegate 中的转发方法。移植到自己的 App 时，要与宿主实际采用的生命周期一致。 [完整集成](Integration.md)
