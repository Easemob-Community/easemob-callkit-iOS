# ``EaseCallUIKit``

基于环信 IM 与声网 RTC 的 iOS 单聊、群聊音视频通话组件。

## Overview

本改造版支持普通 APNs、PushKit、LiveCommunicationKit 与 Apple CallKit。CocoaPods 通过 subspec 选择组合，SwiftPM 通过 Traits 选择框架，宿主统一导入 EaseCallUIKit。

此归档由当前源码启用两个框架后生成，列出的公开 API 涵盖三个集成组合。实际系统来电方式由部署版本、所选依赖和 CallKitConfig 决定，最低部署版本为 iOS 15.0。

完整的 Example 与宿主接入步骤在仓库的 Documentation 目录。 [当前仓库](https://github.com/Easemob-Community/easemob-callkit-iOS) · [上游项目](https://github.com/easemob/easemob-callkit-iOS)

## Topics

### 使用指南

- <doc:GettingStarted>
- <doc:IncomingCalls>

### 通话服务

- ``CallKitManager``
- ``CallKitConfig``
- ``CallMessageService``
- ``CallServiceListener``

### 来电通知

- ``IncomingCallPresentation``
- ``CallNotificationHandler``

### 通话状态

- ``CallInfo``
- ``CallType``
- ``CallState``
- ``CallEndReason``

### 资料与资源

- ``CallProfileProtocol``
- ``CallUserProfile``
- ``CallUserProfileProvider``
- ``CallUserProfileProviderOC``
- ``CallAppearance``

### 错误

- ``CallError``
- ``CallErrorModule``
- ``CallBusinessErrorCode``
- ``CallErrorType``
