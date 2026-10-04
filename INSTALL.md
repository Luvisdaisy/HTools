# 安装 HTools / Installation

适用于 macOS 13+，安装包包含 Apple Silicon 和 Intel 二进制。Intel 和旧版 macOS 尚未实机验证。界面为简体中文。

## 安装与首次打开

1. 从 [GitHub Releases](https://github.com/Luvisdaisy/HTools/releases) 下载 `HTools-<版本>-universal.dmg`，无需 Xcode。
2. 打开 DMG，将 `HTools.app` 拖入 `Applications`（应用程序）。推出磁盘映像，再从“应用程序”打开 App。
3. 本测试版仅使用 ad-hoc 临时签名，**没有 Apple Developer ID 签名和公证**。若 macOS 阻止首次打开，仅在确认下载来源可信后，前往“系统设置 → 隐私与安全性”，找到此次拦截并选择“仍要打开”，按系统提示确认。不同 macOS 版本或受管理设备可能不提供此选项。不要关闭系统安全保护；如提示包含恶意软件或其他异常，请停止安装并反馈。
4. 首次启动进入权限页，逐项配置辅助功能、输入监控和键盘控制服务。系统隐私设置需分别开启 HTools；服务安装由 macOS 请求管理员授权。三项就绪后点击“开始使用”。系统要求重启应用时按提示重启，返回后会重新检查状态。
5. 左键点击菜单栏图标打开设置面板，保存宽高并开启“自动应用到新窗口”，新开访达窗口（⌘N）检查效果。

## 更新与卸载

- 更新前从菜单栏退出旧版，用新 App 替换“应用程序”里的旧 App；本机设置保留。不要同时运行多个副本。
- 更新临时签名应用后可能需要重新添加辅助功能、输入监控权限，并在权限页安装或更新服务以匹配新签名。
- 没有自动更新或 GUI 登录启动。卸载前先在权限页从“管理服务”点击“移除服务”并完成系统授权，再退出、删除 App 和系统隐私权限条目。直接删除 App 不会清理服务。
- 服务文件为 `/Library/PrivilegedHelperTools/HToolsKeyboard.app` 和 `/Library/LaunchDaemons/local.HTools.keyboard.plist`。服务按需运行，开机不会自动禁用键盘。

## 可选：验证下载完整性

将 DMG 和同名 `.dmg.sha256` 放在同一个目录，在该目录运行（替换成实际版本）：

```sh
shasum -a 256 -c HTools-0.2.1-universal.dmg.sha256
```

结果应为 `OK`。校验和用于检查文件完整性，不等于 Apple 公证或开发者身份认证。

## English

Download the universal DMG from GitHub Releases, drag the app to Applications, eject the image, and launch the installed copy. Xcode is not required. macOS 13+ is targeted; Intel and older macOS releases have not been manually verified.

This preview uses ad-hoc signing, with **no Developer ID signature or Apple notarization**. If macOS blocks opening it, only after trusting the download source, use System Settings → Privacy & Security → Open Anyway and follow the system prompts. Availability depends on macOS and device policy. Keep system security protections enabled; stop if macOS reports malware or another unexpected warning.

Complete Accessibility, Input Monitoring and keyboard service installation in the first-launch Permissions page. Reinstall the service after updating the app to match its signature; remove it in Permissions before deleting the app. Quit the old version before replacing it; updates may require removing and re-adding its Accessibility entry. Settings are preserved. Automatic updates and launch at login are not included. The UI is in Simplified Chinese.
