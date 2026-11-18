# DocC API 文档

`EaseCallUIKit.doccarchive` 从当前公开源码生成，涵盖 CocoaPods 与 SPM 共用的 API。生成时启用 AppleCallKit 与 LiveCommunicationKit 两个 Traits，实际接入组合仍由宿主选择。 [API 概览](APIOverView.md) · [归档目录](EaseCallUIKit.doccarchive)

## 重新生成

需要 macOS、Xcode、iOS Simulator SDK 和支持 Traits 的 Swift 6.1 及以上工具链。在仓库根目录执行。

```sh
bash Documentation/generate-docc.sh
```

脚本把 Package 清单、Sources 和 Tests 复制到临时目录，以 arm64 iOS Simulator 目标编译 EaseCallUIKit 并提取 symbol graph，再用 Documentation/EaseCallUIKit.docc 转换为归档。成功后替换 Documentation/EaseCallUIKit.doccarchive，构建与 DocC 日志路径会在终端显示。首次运行需要解析和下载官方依赖。

生成脚本要求 Apple Silicon Mac，或具备 arm64 iOS Simulator 交叉编译能力的环境。构建步骤生成 API 符号，不会运行通话或设备测试。

## 查看

在 Finder 中双击 EaseCallUIKit.doccarchive，或在终端执行以下命令，用 Xcode 的文档窗口查看。

```sh
open Documentation/EaseCallUIKit.doccarchive
```

需要浏览器预览时，在仓库根目录启动本地 HTTP 服务。

```sh
python3 -m http.server 8000 --directory Documentation/EaseCallUIKit.doccarchive
```

随后访问本机文档首页。GitHub 仓库的文件浏览页面展示归档文件，浏览器阅读 DocC 需要 HTTP 服务或静态站点托管。 [本机预览](http://localhost:8000/documentation/easecalluikit/)

## 文档目录

- `Documentation/EaseCallUIKit.docc` 保存模块介绍和 DocC 指南。
- `Documentation/EaseCallUIKit.doccarchive` 保存生成的 API、索引与静态页面。
- `Documentation/*.md` 保存 Example、集成与各能力的操作说明。
