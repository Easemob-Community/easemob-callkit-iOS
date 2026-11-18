# 更新日志

## 未发布 · 2026-11-18

当前改造版基于环信 easemob-callkit-iOS，podspec 版本仍为 4.23.0，以下为本分支尚未发布的改造记录。 [上游项目](https://github.com/easemob/easemob-callkit-iOS) · [当前项目](https://github.com/Easemob-Community/easemob-callkit-iOS)

### 集成与来电

- 国内默认组合使用普通 APNs，在 iOS 17.4 及以上支持 PushKit + LiveCommunicationKit。
- 新增 CocoaPods `Overseas` 双框架组合和 `OverseasCallKit` 纯 Apple CallKit 组合，公共业务代码统一使用 EaseCallUIKit。
- 新增 SwiftPM 兼容清单与 Swift 6.1 Traits 清单，默认启用 LiveCommunicationKit，可选 AppleCallKit 或双框架。
- IM SDK 固定为 4.26.0，RTC SDK 固定为 4.6.2，两种包管理方式自动打包 CallResource.bundle。
- 增加普通 APNs 注册与点击转发入口、本机来电方式、VoIP token 读取与变化回调。
- 系统来电通过独立处理器管理，邀请、确认、取消与结束由 IM 信令同步。

### Example

- 通过环境变量选择 CocoaPods 来电组合。
- 账号输入从代码配置读取，支持修改、自动登录恢复与退出登录，登录后锁定输入。
- 支持输入单聊用户 ID 或已加入的群 ID，提供语音、视频和群组通话入口。
- 首页显示连接状态、当前通话状态、上一次结束原因和日志入口。
- 转发 Scene 前后台事件，示例按 Debug、Release 使用不同推送证书配置。

### 文档

- 重构 README，保留当前 Example、CocoaPods 与 SwiftPM 接入和详细文档入口。
- 将 API、推送、系统框架、PiP、信令、错误处理和更新日志整理到 Documentation。
- 按当前 API 更新回调签名、CallType 与 CallEndReason、来电路由和 Example 配置说明。
- 增加 DocC catalog 和生成脚本，重新从当前源码生成 EaseCallUIKit.doccarchive。
- 将 podspec 的 homepage 和 source 指向 Easemob-Community 仓库。

## 4.16.0 · 原有记录

- 单聊与群组音视频通话。
- LiveCommunicationKit 系统来电。
- 视频通话画中画。
