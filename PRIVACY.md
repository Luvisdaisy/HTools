# 隐私说明 / Privacy

HTools 在本机运行，没有账号、网络请求、遥测、广告或分析 SDK。

## 使用的数据和权限

- **辅助功能权限**：定位 Finder 进程，读取窗口角色、尺寸、位置、最小化和全屏状态，监听相关窗口事件，写入符合条件的新窗口尺寸及必要的位置修正。
- **键盘控制**：枚举 HID 设备名称、内外分类和连接状态。输入监控用于设备访问，前台与后台均检查授权；首次通过系统管理员授权安装固定功能服务，之后按请求启动租约 worker。仅独占可信内置键盘，不订阅按键报告、不记录输入内容或按键统计。密码由 macOS 管理，应用不保存密码。服务可在权限页移除；XPC 双向校验当前程序精确签名，私有本机 Unix socket 传递心跳、停止命令和状态，不连接互联网。
- **本机偏好**：通过 UserDefaults 保存固定宽高、自动应用开关、首次运行及权限配置完成标记。实际权限始终重新检查。
- **本机诊断**：通过系统日志记录窗口数量、调整尺寸或 AX 错误码。应用实现不记录窗口标题、文件路径或文件内容。键盘 worker 仅记录权限状态、进程权限和 HID 操作结果码，不记录按键。

辅助功能是系统级的广泛权限，但当前实现只针对 `com.apple.finder`。应用不截屏、不读取文件内容，不修改系统辅助功能权限数据库。

关闭自动应用可停止尺寸调整；关闭“禁用内置键盘”可恢复内置键盘。退出应用停止功能监听与键盘独占；已安装服务保留，卸载前需在权限页移除。应用异常退出后，后台在心跳失联 3 秒时尝试释放，独立 watchdog 在 5 秒时兜底退出。在系统设置中可随时撤销辅助功能或输入监控权限。删除应用不会自动清除 UserDefaults；如需重置全部偏好，先退出应用，再执行 `defaults delete local.HTools`。

## English summary

The app runs locally with no network requests, telemetry, accounts or analytics. Accessibility access is used only to observe Finder window metadata and resize/reposition eligible new windows. Keyboard control reads device metadata, never keystrokes. A transient administrator worker opens only a validated built-in keyboard and uses a private Unix socket for status and a heartbeat lease. No password is stored. A persistent root-owned service accepts only signature-matched app requests and launches the fixed worker; remove it in Permissions before deleting the app. Preferences remain in UserDefaults; keyboard blocking is never restored automatically. Local diagnostic logs contain counts, dimensions and error codes, not filenames or file contents. You can disable either feature, quit the app, or revoke its permissions at any time.
