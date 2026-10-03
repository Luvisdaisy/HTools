# 独立 POC 验证摘要

2026-10-03，Apple Silicon / macOS 26.6.2：设备枚举识别内置 Apple 键盘及外接蓝牙键盘。普通用户 seize 返回 privilege violation；一次性管理员 worker 的 seize 和 release 均返回成功。

同轮用户确认内置普通键和修饰键被屏蔽、外接实体键盘正常、内置触控板正常、释放后内置键盘恢复。独立 POC 限时 30 秒，记录 API 和人工观察，不保存输入文本。

早先沙箱内尝试返回 not permitted，普通用户输入监控已授权后仍缺少独占权限。这些失败事实保留，不能将输入监控等同于管理员级 IOKit 访问。

分类与生命周期由 `Tests/KeyboardCoreTests` 验证。USB/蓝牙热插拔和异常恢复未完成系统化硬件覆盖；不宣称跨机型、所有特殊键或生产级恢复保证。

原始设备与会话日志仅保存在本机，公开仓库只提供此摘要。集成应用的独立验证见 [HTools 测试说明](../docs/manual-testing.md)。
