# 隐私说明 / Privacy

Finder Fixer 在本机运行，没有账号、网络请求、遥测、广告或分析 SDK。

## 使用的数据和权限

- **辅助功能权限**：定位 Finder 进程，读取窗口角色、尺寸、位置、最小化和全屏状态，监听相关窗口事件，写入符合条件的新窗口尺寸及必要的位置修正。
- **本机偏好**：通过 UserDefaults 保存固定宽高、自动应用开关及首次运行标记。
- **本机诊断**：通过系统日志记录窗口数量、调整尺寸或 AX 错误码。应用实现不记录窗口标题、文件路径或文件内容。

辅助功能是系统级的广泛权限，但当前实现只针对 `com.apple.finder`。应用不截屏、不读取文件内容，不修改系统辅助功能权限数据库。

关闭自动应用可停止尺寸调整；菜单栏退出应用可停止全部监听。在系统设置中可随时撤销辅助功能权限。删除应用不会自动清除 UserDefaults；如需重置全部偏好，先退出应用，再执行 `defaults delete local.finder-fixer`。

## English summary

The app runs locally with no network requests, telemetry, accounts or analytics. Accessibility access is used only to observe Finder window metadata and resize/reposition eligible new windows. Preferences remain in UserDefaults. Local diagnostic logs contain counts, dimensions and error codes, not filenames or file contents. You can disable resizing, quit the app, or revoke Accessibility permission at any time.
