# EaseCallUIKit 集成指南

本项目在环信 easemob-callkit-iOS 上改造，Swift 模块名为 `EaseCallUIKit`，最低部署目标为 iOS 15.0，依赖环信 IM SDK 4.26.0 和声网 RTC SDK 4.6.2。 [当前仓库](https://github.com/Easemob-Community/easemob-callkit-iOS) · [上游项目](https://github.com/easemob/easemob-callkit-iOS) · [运行 Example](Example.md)

## CocoaPods

宿主的 Podfile 选择一个入口，指向当前仓库中包含改造的提交。`COMMIT_SHA` 需要替换成实际提交 ID。

```ruby
platform :ios, '15.0'
use_frameworks!

target 'YourApp' do
  pod 'EaseCallUIKit', :git => 'https://github.com/Easemob-Community/easemob-callkit-iOS.git',
                      :commit => 'COMMIT_SHA'
end
```

海外双框架将名称改为 `EaseCallUIKit/Overseas`，纯 Apple CallKit 改为 `EaseCallUIKit/OverseasCallKit`。执行 `pod install`，随后打开宿主 `.xcworkspace`。本地开发可将 `:git`、`:commit` 换成 `:path => '../easemob-callkit-iOS'`。

同一 target 的 subspec 会合并，按自己的组合选择一个入口即可。公共 Specs 源中的同名版本与本仓库当前修改的代码对应关系，需要在发布后核对。

## Swift Package Manager

在 Xcode 的 **File → Add Package Dependencies…** 输入当前项目仓库地址，选择包含本次改造的版本或提交，把 **EaseCallUIKit** product 添加到 App target。本地调试使用 **Add Local…** 选择仓库根目录。 [当前仓库](https://github.com/Easemob-Community/easemob-callkit-iOS)

Swift 6.1 及以上使用 `Package@swift-6.1.swift`，通过 Traits 选择系统来电框架。Xcode 26.4 及以上可在 **Package Dependencies** 中选择 Traits。 [Apple 发布说明](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_4-release-notes)

| 需求 | Traits |
| --- | --- |
| 国内默认 | 保留默认的 `LiveCommunicationKit` |
| 海外双框架 | 同时启用 `LiveCommunicationKit` 和 `AppleCallKit` |
| 海外纯 Apple CallKit | 关闭默认 Trait，只启用 `AppleCallKit` |
| 全部使用 App 内来电 | 关闭所有 Traits，普通 APNs 入口仍可用 |

如果宿主自身是 Swift package，可在 Swift 6.1 及以上的清单里指定 Traits。下面以海外双框架为例，`COMMIT_SHA` 替换为实际提交 ID。

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "YourAppSupport",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/Easemob-Community/easemob-callkit-iOS.git",
            revision: "COMMIT_SHA",
            traits: ["LiveCommunicationKit", "AppleCallKit"]
        )
    ],
    targets: [
        .target(
            name: "YourAppSupport",
            dependencies: [.product(name: "EaseCallUIKit", package: "easemob-callkit-iOS")]
        )
    ]
)
```

纯 Apple CallKit 使用 `traits: ["AppleCallKit"]`，关闭全部 Traits 使用 `traits: []`。SwiftPM 将同一个依赖图内的 Traits 合并，多个依赖请求不同组合时会取并集。Swift 6.1 以下使用 `Package.swift` 的默认国内组合。两份清单保持 Swift 5 语言模式。 [SwiftPM Traits 规则](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/)

普通 APNs token 与 VoIP token 的处理统一使用以下 API，业务代码无需按包管理方式拆分。IM 与 RTC 依赖使用同一种包管理方式接入，资源随框架自动打包。

## 初始化与登录

先在宿主 Info.plist 配置 `NSMicrophoneUsageDescription` 和 `NSCameraUsageDescription`。使用后台音视频或系统来电时，按需启用 Background Modes 的 Audio、AirPlay、Picture in Picture 和 Voice over IP，普通推送启用 Push Notifications。

在 App 启动时初始化 IM，再配置 EaseCallUIKit。以下方法在主线程调用，证书名来自环信控制台。

```swift
import UIKit
import UserNotifications
import EaseCallUIKit

func initializeCalling(appKey: String) -> Bool {
    let options = ChatSDKOptions(appkey: appKey)
    options.isAutoLogin = true
    #if DEBUG
    options.apnsCertName = "YOUR_APNS_DEV"
    options.pushKitCertName = "YOUR_VOIP_DEV"
    #else
    options.apnsCertName = "YOUR_APNS_RELEASE"
    options.pushKitCertName = "YOUR_VOIP_RELEASE"
    #endif

    if let error = ChatClient.shared().initializeSDK(with: options) {
        print(error.errorDescription ?? "IM initialization failed")
        return false
    }

    let config = CallKitConfig()
    config.enableVOIP = true
    config.enablePIPOn1V1VideoScene = true
    CallKitManager.shared.setup(config)
    CallNotificationHandler.shared.registerForNotifications()
    return true
}
```

只使用普通 APNs 时将 `enableVOIP` 设为 false，并使用普通 APNs 证书。配置在 `setup` 时应用，切换配置需先完成当前通话，再 `tearDown()` 和 `setup(newConfig)`。

首次登录调用环信 IM SDK 的 token 登录接口。IM token 由业务服务端签发。成功后写入本机资料并绑定普通推送 token，自动登录完成时也执行相同的会话恢复步骤。

```swift
func login(userID: String, imToken: String) {
    ChatClient.shared().login(withUsername: userID, token: imToken) { _, error in
        DispatchQueue.main.async {
            guard error == nil else {
                print(error?.errorDescription ?? "Login failed")
                return
            }
            let profile = CallUserProfile()
            profile.id = userID
            profile.nickname = userID
            CallKitManager.shared.currentUserInfo = profile
            CallNotificationHandler.shared.bindDeviceToken()
        }
    }
}
```

SDK 在 IM 已连接的回调中绑定 VoIP token，并准备 RTC 引擎和令牌。自动登录状态、失败提示和退出入口由宿主维护，可参照 Example。 [账号实现](../Example/EaseCallUIKit/AppDelegate.swift)

## 生命周期和普通推送转发

宿主保持 `UNUserNotificationCenterDelegate`，在启动时设置它，并在以下系统回调中转发普通 APNs 注册和点击事件。通知处理器只接管匹配的来电通知。

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    CallNotificationHandler.shared.didRegister(deviceToken: deviceToken)
}

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    if !CallNotificationHandler.shared.handle(response) {
        // 在这里处理宿主的其他通知。
    }
    completionHandler()
}
```

IM 初始化成功后再转发生命周期。采用单窗口 Scene 的宿主在下面的方法中转发。

```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    ChatClient.shared().applicationDidEnterBackground(UIApplication.shared)
}

func sceneWillEnterForeground(_ scene: UIScene) {
    ChatClient.shared().applicationWillEnterForeground(UIApplication.shared)
}
```

采用 AppDelegate 生命周期的宿主在 `applicationDidEnterBackground` 和 `applicationWillEnterForeground` 中转发。多个 Scene 的宿主应按 App 整体前后台状态通知转发。

## 呼叫与事件

IM 已连接且当前页面可以展示通话 UI 时，在主线程发起呼叫。以下方法按场景分别调用。

```swift
func startAudioCall(userID: String) {
    CallKitManager.shared.call(with: userID, type: .singleAudio)
}

func startVideoCall(userID: String) {
    CallKitManager.shared.call(with: userID, type: .singleVideo)
}

func startGroupCall(groupID: String) {
    CallKitManager.shared.groupCall(groupId: groupID)
}
```

群组接口使用已加入的群 ID，随后由内置页面选择成员。需要展示昵称、头像和群名时，为 `profileProvider` 提供 `CallUserProfileProvider` 实现，可参照 Example 的异步用户资料查询。

监听对象需由宿主持有，SDK 使用弱引用保存。UI 更新切回主线程。

```swift
final class CallEvents: NSObject, CallServiceListener {
    func didUpdateCallEndReason(reason: CallEndReason, info: CallInfo) {
        DispatchQueue.main.async {
            print("Call ended", info.callId, reason.rawValue, info.duration)
        }
    }

    func didOccurError(error: CallError) {
        print(error.module.rawValue, error.error.errorCode, error.errorMessage)
    }
}

// 宿主持有 callEvents，在初始化之后注册。
let callEvents = CallEvents()
CallKitManager.shared.addListener(callEvents)
```

内置来电页面处理接听和拒接。自定义页面可调用 `accept()` 接听、`hangup()` 结束当前邀请或通话。精确签名、状态和结束原因见 API 概览。 [API 概览](APIOverView.md)

## 退出与自定义资源

退出登录前结束通话，调用 `ChatClient.shared().logout(true)` 解绑设备 token。成功后清理当前用户资料和宿主保存的账号状态。宿主准备完整销毁通话服务时调用 `CallKitManager.shared.tearDown()`，再次启用时重新 `setup`。

界面颜色、语言、头像占位图和背景由 `CallAppearance` 配置。自定义资源包通过 `CallAppearance.resourceBundle` 指定，并保留所需图片、铃声和本地化文件。默认资源在 CocoaPods 与 SPM 中由 `Bundle.callBundle` 定位。

## 后续配置

- 普通 APNs、VoIP token、国内外路由与重复通知见 [来电推送](IncomingCalls.md)。
- 画中画与摄像头后台能力见 [视频 PiP](PictureInPicture.md)。
- 真机验证和常见错误见 [Example](Example.md) 与 [错误和日志](ErrorHandler.md)。
