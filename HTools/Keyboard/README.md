# HTools 键盘控制

设置包含 访达窗口、键盘控制两个功能页和统一权限页。输入监控和键盘服务未就绪时，键盘页保留标题，正文仅显示“前往权限设置”；前台输入监控、服务连接及同上下文后台权限检查均通过后显示设备分类和禁用内置键盘开关。权限失效时停止当前控制会话。

## 首次配置

首次启动集中配置辅助功能、输入监控、键盘服务。TCC 由系统逐项确认；服务安装请求一次管理员授权，之后切换开关无需密码。更新或重建应用后需更新服务，系统隐私权限也可能要求重新添加。

服务位于 `/Library/PrivilegedHelperTools/HToolsKeyboard.app`，launchd 配置位于 `/Library/LaunchDaemons/local.HTools.keyboard.plist`。权限页支持移除服务；删除 app 前先移除。应用不以 root 运行，不保存密码。

## 控制边界

- LaunchDaemon 的 XPC 入口仅提供状态、启动固定 worker 和结束会话，双向要求当前 executable 的精确 cdhash。旧版或仅伪造 Bundle ID 的程序不可访问。
- 安装以 root 私有目录暂存完整签名应用包副本（保留 Info.plist 和资源签名），校验预期 SHA-256 和代码签名，设置 root 所有权后替换固定目标。当前支持临时签名分发，不依赖 Developer ID 公证。
- 前台输入授权或服务在线不代表可用：权限页另启动不打开设备的后台检查进程验证输入权限。检查与实际 worker 都通过 `launchctl asuser` 进入已验证控制台用户的 bootstrap/审计会话并保留 root credentials；实际 seize 前再次检查。
- 一次只允许一个 worker。服务验证控制台用户、socket 路径、类型、权限与所有者；worker 验证 GUI UID/PID，GUI 验证 worker 为 root。
- 首个心跳后重新枚举并核对设备，再独占唯一可信内置键盘；实际成功后才开启 UI 开关。不独占外接设备。
- GUI 每 0.5 秒续约；失联 3 秒释放，5 秒独立 watchdog 退出；release 卡住另有 2 秒保护。关闭开关、退出、设备移除、睡眠、会话失活均结束会话。服务或 GUI 重启不会自动禁用。
- 选定 registry ID 最小的可信外接设备作为存活条件；它断开即释放。该 ID 不是永久身份。
- 共享 `KeyboardGuardPOC/Sources/KeyboardCore`。独立 POC 保留 30 秒上限，集成版采用租约。不记录按键内容、统计或设备历史。

## 验证

本轮进展见 [VALIDATION.md](VALIDATION.md)。历史 POC 物理确认仅属于 POC，不能代替本版本验收。XCTest 不安装服务、不请求管理员授权、不执行物理键盘禁用。
