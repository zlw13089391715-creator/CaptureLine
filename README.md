# CaptureLine

[English](docs/i18n/README.en.md) · [Español](docs/i18n/README.es.md) · 简体中文

CaptureLine 是一款 macOS 截图与录屏收纳工具，将截图和视频封面挂在屏幕顶部，支持跨应用查看、复制、拖拽与播放。基于 Alejandro Buján 创作的 [Tendedero](https://github.com/alejandrobujan/tendedero) 修改，顶部绳线收纳的创意与原始实现来自原项目。

本版本独立维护，与原作者无隶属关系，也不代表原作者认可或支持本版本。感谢原作者的开源贡献。完整来源说明见 [CREDITS.md](CREDITS.md)。

## 功能

- 收纳系统截图与录屏，支持 MOV、MP4、M4V 视频。
- 视频显示封面和播放标识；单击复制视频文件，双击或长按用默认播放器打开。
- 保留截图复制、系统标注、拖拽、动画和重启恢复。
- 开启「接管截图和录屏」后，系统捕获直接保存到内部收纳目录，不经过桌面；正常退出或关闭接管时恢复之前的保存设置。
- 挂绳可在普通窗口、不同桌面、全屏应用及台前调度中展开。鼠标移到屏幕顶部，或按 **Control＋Option＋T** 展开；移开后自动收起。
- 本地运行，无账号、无分析统计，也不上传截图或视频。

## 安装与使用

支持 **macOS 14 及以上**，构建脚本生成兼容 Apple 芯片与 Intel 的通用应用。

本仓库提交的是源码。若 [Releases](https://github.com/zlw13089391715-creator/CaptureLine/releases) 中有应用 ZIP，可直接下载；若尚无下载附件，请使用下方的源码构建方法。

1. 将 CaptureLine.app 放入「应用程序」，退出原版 Tendedero 或其他 CaptureLine 实例后打开。
2. 在菜单中开启「接管截图和录屏」。
3. 用 Command＋Shift＋3／4 截图，或 Command＋Shift＋5 录屏。录屏停止、文件保存完成并可读取后才会挂起。
4. 将鼠标移到屏幕顶部查看；也可以使用 Control＋Option＋T。

当前本地应用采用临时签名，未通过 Apple 公证，不能沿用原版的签名及公证声明。首次打开若被 macOS 阻止，可在「系统设置 → 隐私与安全性」中允许打开。

### 操作

| 操作 | 图片 | 视频 |
| --- | --- | --- |
| 单击 | 复制图片及文件 | 复制视频文件 |
| 双击 | 用默认应用打开 | 用默认播放器打开 |
| 长按 | 系统标注 | 用默认播放器打开 |
| 拖到应用 | 分享 | 分享 |
| 拖到文件夹 | 保存到该文件夹，并取下 | 保存到该文件夹，并取下 |
| 右键 | 复制、打开、标注及文件操作 | 复制、打开及文件操作 |

收纳目录为 `~/Library/Application Support/CaptureLine/Screenshots`，其中同时保存截图与视频。挂绳引用这些文件，不会额外复制一份视频。收纳目录内的项目点叉会移到废纸篓；目录外项目取下时保留原文件。可用右键「在访达中显示」查看文件位置，或「存储到桌面」保留到桌面。

### 录屏没有出现时

- 确认使用 macOS 自带录屏，并且在启动应用后新录制；历史视频可通过菜单「添加录屏…」手动加入。
- 用 Command＋Shift＋5 打开录屏工具栏，检查「选项 → 存储到」。开启接管时应指向上述内部目录。若工具栏在开启接管前已打开，按 Esc 关闭并重新打开。
- 桌面只自动接收可识别的系统截屏与录屏，普通桌面视频不会被自动收纳。专用收纳目录接受支持的媒体格式。
- 视频必须稳定且含可读取的视频轨道。损坏或未写完的文件不会被提前挂起；无变化的失败重试有时限，文件变化后可以继续处理。

## 从源码构建

安装 Xcode 或其 Command Line Tools，准备 Swift 工具链：

```sh
git clone https://github.com/zlw13089391715-creator/CaptureLine.git
cd CaptureLine
bash scripts/build-app.sh
open build/CaptureLine.app
```

产物为 `build/CaptureLine.app`。脚本构建 arm64 与 x86_64 两种架构；默认使用本机 SDK，必要时尝试已安装的 macOS 26 SDK。可通过 `SDKROOT` 指定兼容 SDK。完整 Xcode 可用于解决 Command Line Tools 缺少 SwiftUI 宏插件的问题。

脚本若找到 Developer ID 会尝试使用该身份签名，否则采用本地临时签名。构建脚本不执行公证；正式发行的签名与公证需另行完成。

```sh
# 翻译完整性检查
swift scripts/check-strings.swift

# 媒体监听、收纳、恢复和保存设置检查（需要 macOS）
bash scripts/check-recordings.sh

# 只检查系统保存设置的备份／还原（使用隔离测试配置）
bash scripts/check-recordings.sh --destination-only
```

内部 SwiftPM 模块及源码目录保留 `Tendedero` 名称，以保留来源关系；应用名称、可执行文件、图标和 bundle identifier 已使用 CaptureLine。

## 验证范围

已完成截图与录屏相关集成检查、翻译检查，以及 Apple 芯片／Intel 通用构建。实际 macOS 系统录屏已确认可以挂起并直接保存到内部目录，桌面不出现视频。

1.0.5 修复了全屏窗口中的挂绳显示问题，已通过通用构建和签名检查，并由使用者在测试 Mac 上确认桌面及全屏应用中均能展开。其他全屏应用、台前调度及不同 macOS 版本仍需进一步验证。支持的最低系统版本不代表已在每个版本上实测。

## 来源与许可证

原项目：[Tendedero](https://github.com/alejandrobujan/tendedero)；原作者：**Alejandro Buján**。源码基于上游提交 `ed0618a67cc59e0a8621b97bb5e32ab9af3b0b69` 修改。

代码保留原项目的 MIT 许可证及原版权声明，详见 [LICENSE](LICENSE)。该许可证不授予 Tendedero 名称或图标的使用权；修改版使用独立名称与图标，不分发原版图标及宣传素材。

修改记录见 [CHANGELOG.md](CHANGELOG.md)，更详细的使用与验证说明见 [docs/USAGE.zh-Hans.md](docs/USAGE.zh-Hans.md)。
