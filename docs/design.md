# HTools 架构

原生 SwiftUI / AppKit 菜单栏应用，应用和测试源码位于 `HTools/`、`HToolsTests/`。工程由 `scripts/create-project.py` 确定性生成，无第三方运行依赖。

## 菜单栏与面板

`MenuBarController` 区分左右键：左键切换设置面板，右键提供无图标、无快捷键的两项菜单。`AppDelegate` 使用不可分离的瞬时 `NSPopover`，锚定菜单栏按钮；`SettingsView` 以顶部标签导航，根据页面与设备数更新 400 pt 宽的内容尺寸。关闭前校验草稿，授权中阻止关闭；隐藏面板不改变后台服务状态。

## 访达

`SettingsModel` 管理草稿及偏好，`PreferencesStore` 迁移原应用的有效尺寸设置。`FinderWindowService` 在串行队列中维护 AX 观察器与窗口基线，只处理新标准窗口；策略层负责尺寸夹限和屏幕坐标换算。启动、保存、重新聚焦、标签和最小化恢复不会批量调整已有窗口。

## 键盘

GUI 普通用户进程 → 精确签名校验的特权 XPC 服务 → `launchctl asuser` 用户审计会话中的 root worker → IOHIDDeviceOpen(SeizeDevice)。共享核心位于 `KeyboardGuardPOC/Sources/KeyboardCore`，独立 POC 与应用使用同一分类逻辑。

- 仅独占唯一可信内置键盘，要求可信外接设备在场；拒绝虚拟、歧义、多内置与危险复合接口。
- 服务使用内核提供的连接 UID/PID，并检查控制台用户与私有 socket 元数据。仅执行固定 worker，不接受可执行路径或 shell 命令。
- GUI 与服务双向校验当前 executable 的 cdhash。新构建需要更新服务，不仅靠 Bundle ID 判断身份。
- root worker 保留管理员级 IOKit 身份，并进入用户的 bootstrap/审计会话。准备检查与实际操作使用相同启动路径，避免前台权限通过但后台被 TCC 拒绝。
- GUI 创建 0700 临时目录、0600 Unix socket；双方校验 peer 身份。协议仅含心跳、停止和状态，不传输输入内容。
- 0.5 秒续约，失联 3 秒尝试释放，5 秒独立 watchdog 退出；release 自身另有 2 秒保护。设备移除、退出、睡眠、会话失活均结束会话，重连不重启禁用。

## 权限与服务生命周期

首次统一配置辅助功能、输入监控与服务。权限页实时核实前台授权、签名匹配的服务和实际后台输入权限；“服务可连接”不等于“功能可用”。切页保存有效访达草稿；权限失效停止键盘控制。

一次系统管理员授权安装 root 拥有的完整签名包到 `/Library/PrivilegedHelperTools/HToolsKeyboard.app`，配置位于 `/Library/LaunchDaemons/local.HTools.keyboard.plist`。先在 root 私有目录中复制、校验预期 SHA-256 与完整代码签名，再替换固定文件、加载服务。完整包保留 Info.plist 和资源签名。权限页支持重装和移除。

当前为临时签名、未公证分发，因此使用传统 LaunchDaemon 安装方式。XPC 与 worker 只做限定键盘操作；GUI 不以 root 运行。没有密码持久化、网络服务或按键内容采集。

实现路径和自动化检查不能替代物理输入、跨系统兼容和故障恢复矩阵；参见 [验证范围](manual-testing.md)。
