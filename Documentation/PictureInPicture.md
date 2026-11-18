# 单聊视频画中画

当前项目为一对一视频通话提供系统 Picture in Picture（PiP）。实现位于 `Call1v1VideoViewController`，群组页面使用自己的通话 UI 与悬浮呈现。 [控制器源码](../Sources/EaseCallUIKit/Classes/UI/Controllers/Call1v1VideoViewController.swift)

## 配置

```swift
let config = CallKitConfig()
config.enablePIPOn1V1VideoScene = true
CallKitManager.shared.setup(config)
```

在 App 的 Signing & Capabilities 中启用 Background Modes 的 Audio、AirPlay 和 Picture in Picture。系统 VoIP 来电再启用 Voice over IP，并配置对应推送证书。麦克风、摄像头的用途说明与用户授权由宿主提供。

后台摄像头采集还取决于设备、系统和摄像头采集会话对 multitasking camera access 的支持。示例包含 `com.apple.developer.avfoundation.multitasking-camera-access` entitlement，宿主的签名配置需与实际能力对应。 [Apple 视频通话 PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-for-video-calls) · [Apple 摄像头多任务能力](https://developer.apple.com/documentation/avfoundation/avcapturesession/ismultitaskingcameraaccesssupported)

## 当前行为

控制器检查 `AVPictureInPictureController.isPictureInPictureSupported()` 与配置开关，创建 `AVPictureInPictureVideoCallViewController` 和 PiP content source，并允许系统从 inline 内容自动进入 PiP。实际是否进入由系统状态与支持情况决定。

单聊视频收起时在通话页与 PiP 容器之间迁移视频画面，恢复时回到通话页面。结束通话清理相关 UI 和会话。群组通话的系统 PiP 尚未在本项目中提供，群组页面的收起能力应按其当前 UI 逻辑验证。

## 真机验证

1. 两台设备登录不同账号，发起并接通单聊视频。
2. 操作通话页收起入口，或将 App 退到后台，检查 PiP 是否出现。
3. 检查远端画面、音频、设备旋转与 App 恢复。
4. 从 PiP 返回通话页，确认画面和控制按钮恢复。
5. 分别在前台与 PiP 状态结束通话，确认 PiP 消失、摄像头和音频资源释放。

PiP 无法启动时，结合控制器日志、系统支持检查、后台能力与签名排查。 [Example 验证步骤](Example.md#验证能力) · [错误与日志](ErrorHandler.md)
