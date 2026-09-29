# 安装 Finder Fixer / Installation

适用于 macOS 13+，安装包包含 Apple Silicon 和 Intel 二进制。Intel 和旧版 macOS 尚未实机验证。界面为简体中文。

## 安装与首次打开

1. 从 [GitHub Releases](https://github.com/Luvisdaisy/finder-fixer/releases) 下载 `Finder-Fixer-<版本>-universal.dmg`，无需 Xcode。
2. 打开 DMG，将 `finder-fixer.app` 拖入 `Applications`（应用程序）。推出磁盘映像，再从“应用程序”打开 App。
3. 本测试版仅使用 ad-hoc 临时签名，**没有 Apple Developer ID 签名和公证**。若 macOS 阻止首次打开，仅在确认下载来源可信后，前往“系统设置 → 隐私与安全性”，找到此次拦截并选择“仍要打开”，按系统提示确认。不同 macOS 版本或受管理设备可能不提供此选项。不要关闭系统安全保护；如提示包含恶意软件或其他异常，请停止安装并反馈。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”中添加并开启“应用程序”里的 `finder-fixer.app`。权限必须由你手动授予。
5. 在菜单栏打开设置，保存宽高并开启“自动应用到新窗口”，新开 Finder 窗口（⌘N）检查效果。

## 更新与卸载

- 更新前从菜单栏退出旧版，用新 App 替换“应用程序”里的旧 App；本机设置保留。不要同时运行多个副本。
- 更新临时签名应用后可能需要在辅助功能列表移除旧条目，再添加当前 App。
- 没有自动更新或内置登录启动。卸载时先退出，删除 App 并移除辅助功能条目。

## 可选：验证下载完整性

将 DMG 和同名 `.dmg.sha256` 放在同一个目录，在该目录运行（替换成实际版本）：

```sh
shasum -a 256 -c Finder-Fixer-0.1.1-universal.dmg.sha256
```

结果应为 `OK`。校验和用于检查文件完整性，不等于 Apple 公证或开发者身份认证。

## English

Download the universal DMG from GitHub Releases, drag the app to Applications, eject the image, and launch the installed copy. Xcode is not required. macOS 13+ is targeted; Intel and older macOS releases have not been manually verified.

This preview uses ad-hoc signing, with **no Developer ID signature or Apple notarization**. If macOS blocks opening it, only after trusting the download source, use System Settings → Privacy & Security → Open Anyway and follow the system prompts. Availability depends on macOS and device policy. Keep system security protections enabled; stop if macOS reports malware or another unexpected warning.

Grant Accessibility permission to the installed app. Quit the old version before replacing it; updates may require removing and re-adding its Accessibility entry. Settings are preserved. Automatic updates and launch at login are not included. The UI is in Simplified Chinese.
