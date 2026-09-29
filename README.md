# Finder Fixer

<img src="assets/app-icon.png" width="96" alt="Finder Fixer icon">

让每个新开的访达窗口，自动使用你喜欢的尺寸。

[English](README.en.md) · [参与贡献](CONTRIBUTING.md) · [MIT 许可证](LICENSE)

Finder Fixer 是一个轻量的 macOS 菜单栏工具。设置一次宽高，后续新开的标准访达窗口会自动调整一次；之后仍可自由拖动和缩放。

## 功能

- 固定宽高，默认 **1000 × 700 pt**，设置保存在本机。
- 只调整新窗口，启动应用或保存设置不会批量改变已有窗口。
- 手动缩放后不会被拉回；标签页、重新聚焦和最小化恢复不会重复调整。
- 自动应用可以随时关闭；退出应用即停止监听。
- SwiftUI + AppKit 原生实现，无第三方运行依赖、账号或联网服务。

当前应用界面为简体中文。

## 安装与使用

提供免费 DMG 测试版，**仅临时签名，没有 Developer ID 签名和 Apple 公证**。从 [Releases](https://github.com/Luvisdaisy/finder-fixer/releases) 下载 DMG，将 App 拖到“应用程序”，无需 Xcode。首次打开可能被 macOS 拦截；系统允许时，确认来源可信后可在“隐私与安全性”中选择“仍要打开”。详见[安装与更新说明](INSTALL.md)。

也可以安装完整 Xcode 及命令行工具，从源码构建：

```sh
git clone https://github.com/Luvisdaisy/finder-fixer.git
cd finder-fixer
./scripts/build.sh
open build/Build/Products/Release/finder-fixer.app
```

1. 在“系统设置 → 隐私与安全性 → 辅助功能”中添加并开启刚构建的 `finder-fixer.app`。
2. 在菜单栏打开设置，输入宽高并保存，开启“自动应用到新窗口”。
3. 新开一个访达窗口（⌘N），查看尺寸效果。

宽高是窗口外框的逻辑点（pt），不是物理像素；Finder 自身最小尺寸和屏幕可用区域可能限制实际尺寸。关闭设置窗后应用继续运行，退出请使用菜单栏菜单。

权限仅用于观察和调整 Finder 窗口，不读取文件内容。重建临时签名的应用后，可能需要重新添加辅助功能授权。详见[隐私说明](PRIVACY.md)。

## 兼容性与限制

| 项目 | 当前状态 |
| --- | --- |
| 应用部署目标 | macOS 13+；不代表所有版本均已实机验证 |
| 既有桌面验证 | macOS 26.6.2 / Apple Silicon / 单屏 |
| 构建环境 | 已在 Xcode 27 构建；测试 target 要求 macOS 14+ |
| 特殊窗口 | 跳过全屏、最小化和非标准窗口；平铺／最大化行为受系统限制 |
| 尚未实机验证 | 多屏、Intel、旧 macOS、完整 VoiceOver 与部分权限竞态 |
| 暂未提供 | 登录启动、自动更新、按文件夹记忆、其他应用窗口管理 |

单元测试验证尺寸策略与设置逻辑，不替代真实 Finder 桌面验收。

## 开发

```sh
./scripts/build.sh Debug
./scripts/test.sh
```

可直接打开 `finder-fixer.xcodeproj`。测试宿主不会启动 Finder 控制服务或展示设置窗口；自动化测试不需要辅助功能权限。

```text
finder-fixer/
  App/               应用生命周期、菜单栏、设置窗口
  Settings/          SwiftUI 界面、编辑草稿与配置协调
  WindowManagement/  Finder 事件监听、窗口筛选与尺寸策略
  Infrastructure/    辅助功能权限入口、偏好持久化
  Resources/         已生成的应用和菜单栏图标
finder-fixerTests/    尺寸策略与偏好/草稿回归测试
scripts/             构建、测试、工程及图标生成工具
assets/              图标源素材
```

[更新记录](CHANGELOG.md) · [DMG 打包与发布](RELEASING.md)

## 反馈与许可证

请通过 [Issues](https://github.com/Luvisdaisy/finder-fixer/issues) 报告问题，附上系统版本、芯片架构、显示器配置和复现步骤。请勿上传含私人文件名的桌面截图或完整系统日志。贡献前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)；安全问题请参阅 [SECURITY.md](SECURITY.md)。

项目采用 [MIT License](LICENSE)。Finder 和 macOS 是 Apple 的商标；本项目为独立社区工具，与 Apple 无隶属或背书关系。
