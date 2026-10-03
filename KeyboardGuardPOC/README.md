# KeyboardGuard POC — Phase 1 + Phase 2

按《MacBook 外置键盘联动禁用内置键盘系统 V1.0 技术报告》第 50、54 节，实现独立 Device Inspector 和有限时长的设备级 seize/release 实验。当前验收状态见 [VALIDATION.md](VALIDATION.md)。API 返回成功不能代替物理输入验证。

2026-10-03 本机管理员 worker 的基础链路已通过：成功识别及独占内置键盘，用户确认内置输入被屏蔽、蓝牙 Node75 和触控板正常，30 秒后 release 成功且内置输入恢复。证据来自同一轮 API 日志与四项人工观察；热插拔、断连恢复及其他机型仍未通过实机验收。

## 构建与测试

需要 Xcode / macOS SDK，无第三方依赖。保留现有 HTools 的系统兼容范围，POC 部署目标 macOS 13；仅当前 Apple Silicon/macOS 26.6.2 运行证据可用于本机结论。

从仓库根目录执行：

```sh
bash scripts/build-keyboard-poc.sh test
bash scripts/build-keyboard-poc.sh
open dist/KeyboardGuardPOC.app --args --evidence-dir "$PWD/output/keyboard-poc"
```

包位于 `dist/KeyboardGuardPOC.app`，临时签名、无沙箱，未公证。只构建/运行独立 POC，不修改访达主应用或安装后台服务。

## 权限

设备列表可读不代表允许独占设备。若 seize 返回权限错误，使用“输入监控权限…”打开系统设置，在“隐私与安全性 → 输入监控”中添加并开启实际运行的 `KeyboardGuardPOC.app`，随后退出并重新打开。授权由用户操作。

**输入监控授权不等于允许独占键盘。** 本机已确认输入监控开启，但普通用户 worker 仍返回 `0xe00002c1 / privilege violation`。Apple 公开的 [IOHIDLibUserClient.cpp](https://github.com/apple-oss-distributions/IOHIDFamily/blob/main/IOHIDFamily/IOHIDLibUserClient.cpp) 在 `open` 中明确要求键盘 seize 客户端具备管理员级权限（或系统认可的特权 entitlement）。不能通过添加未经 Apple 授权的 entitlement 绕过检查。

Phase 2 使用**单次 sudo worker**验证，不让整个 GUI 以 root 运行、不安装常驻 helper、不修改 TCC。构建额外生成 `dist/KeyboardGuardPOCWorker`，与 GUI 共用源代码，但脚本只调用固定的限时 CLI 入口。`run-keyboard-poc.sh` 先以普通用户枚举并检查唯一目标，再由用户在终端确认基线、输入管理员凭据，执行最长 30 秒的 worker，随后退出。日志、tee 和验收问答仍以普通用户运行。

从终端或 Codex 直接执行 CLI 时，macOS 的权限归属可能与 Finder 启动的 App 不同。临时签名重建后，旧授权可能失效，必要时重新添加实际交付包。最新 worker 会记录 `euid`、`input_monitoring_access` 和原始 IOReturn，便于区分两层权限。正式产品的受控特权服务与身份校验仍需另行设计。

## 本机管理员 POC 路径

先在终端运行只读检查（不需要管理员权限）：

```sh
bash scripts/build-keyboard-poc.sh worker
bash scripts/run-keyboard-poc.sh 30 --inspect
```

准备好两把实体键盘和一个可输入的窗口（可用 Inspector 的输入框），确认均能输入，然后运行：

```sh
bash scripts/run-keyboard-poc.sh 30
```

输入 `START` 后，在终端本地完成 sudo 密码提示。看到 `seize_result` 为 0 / `blocked` 后，在 30 秒内切到输入窗口，依次测试内置按键、外接输入、触控板；到期恢复后测试内置输入。终端 Ctrl+C 可以提前 release。**普通用户 GUI 的“立即释放”只控制 GUI 自己启动的 worker，不控制 sudo worker**，此路径使用终端 Ctrl+C、外接断连或到时释放。

API 成功结束后，脚本会逐项询问四项物理观察；填写 y/n/u（确认/不符合/未验证）。结果只存结论，关联同一个 `runID`；不会采集输入文本。证据位于 `output/keyboard-poc/admin-run.*/`。不会自动勾选 GUI 中另一轮测试的结果。多把外接键盘同时存在时脚本拒绝猜测，可用 CLI 明确选择当前 registry ID。

## GUI worker 验证流程

此流程用于具备所需权限的 GUI worker 路径；本机普通用户 worker 会返回管理员权限错误，应使用上面的单次管理员 POC。

1. 打开检查器，核对唯一 `builtIn` 键盘及选中的外接设备。将外接键盘暂时放在旁边，保持内置键盘和触控板可测试。
2. 在窗口输入框中分别使用**两把实体键盘**输入测试字符，确认均正常。松开全部按键，勾选基线确认。软件自动打字、粘贴、远程输入不能证明物理设备工作。
3. 点击“开始 30 秒测试”。只有 worker 的 `IOHIDDeviceOpen(...SeizeDevice)` 返回成功，才显示 `BLOCKED` 并允许记录独占期间观察。
4. 在输入框聚焦时尝试内置字母键、Shift/Control/Option/Command 等修饰键；用内置修饰键搭配外接字母键检查是否影响输入。按完立即松开，避免遗留修饰状态。若内置输入或修饰效果仍出现，该项不通过。
5. 使用外接键盘输入普通字符及修饰组合；使用**内置触控板**移动、点击。将真实观察勾选在对应项中，不符合就不勾选。特殊 Fn/Globe/媒体键另行验证，不默认通过；不承诺屏蔽电源/Touch ID。
6. 点击“立即释放”，或等待 30 秒自动释放。只有 `release_result.code=0` 且 worker 正常退出，恢复确认才可选。再用**内置键盘**输入，确认后勾选“释放之后…”。
7. 同一轮的成功 API 结果和四项用户观察都齐全，才可证明这台机器、这个系统和这一外接键盘的基础链路。

输入框仅保留在窗口内存中，不写入证据。不要在测试框输入密码等真实敏感内容。记录的是用户明确勾选的观察结论，不是自动分析用户输入。

## 热插拔及恢复实验

每轮手动重新开始，无自动重连禁用或持久化禁用状态。

| 实验 | 预期证据 | 仍需物理确认 |
|---|---|---|
| USB 插入/拔出，蓝牙开/关再连接 | `connected` / `removed`，新 registry ID 正确 | 真实设备及当前连接状态 |
| 阻止期间选定外接键盘断开 | `device_removed` → `release_result` → `worker_exit` | 内置立即恢复；重连不会自行禁用 |
| 30 秒到期 | `timeout` → `release_result` | 内置恢复 |
| 手动释放、正常退出 GUI | `signal_15` → `release_result` | 内置恢复 |
| 强制结束 worker / GUI | supervisor 退出记录或日志截断；OS 回收句柄 | 内置恢复，不能用进程消失代替此项 |
| 睡眠或会话失活 | `sleep_or_session_inactive`，worker 结束 | 唤醒后可输入且未重新独占 |

运行中请勿重建/覆盖同一个应用包。多 POC 实例或其他键盘工具可能占用设备；不要把 seize 失败隐藏为成功。

## CLI

默认无参数启动 GUI。CLI 输出 JSONL，只含元数据与操作结果，不读取输入 report。

```sh
dist/KeyboardGuardPOC.app/Contents/MacOS/KeyboardGuardPOC --list
dist/KeyboardGuardPOC.app/Contents/MacOS/KeyboardGuardPOC --watch
# 从本次 --list 取得十进制 ID；禁止把历史 ID 当作稳定设备身份。
dist/KeyboardGuardPOC.app/Contents/MacOS/KeyboardGuardPOC \
  --seize INTERNAL_REGISTRY_ID --external EXTERNAL_REGISTRY_ID --seconds 3
```

`--seconds` 必须为 1–30；默认不 seize。Ctrl+C / SIGTERM 走 release 路径。CLI 仅供开发诊断，运行前需要操作者自行确认两把键盘正常并松开全部按键。失败退出码 2，参数错误退出码 64。`--watch` 持续观察元数据，Ctrl+C 停止。

## 实现边界

- `DeviceClassifier`：Built-In、内部 transport、Apple vendor、registry ancestry 评分；分数是启发式信心值，并非统计概率。名称不作为内置设备正向证据。
- `HIDDeviceManager`：Keyboard usage 匹配与热插拔，`IndependentDevices` 防止 manager 自动打开所有设备。仅对目标内置键盘调用 device-level open/close；不订阅输入，不对外接设备 open。
- 指向设备的复合内置接口、未知拓扑、缺少 collections、多候选内置设备均拒绝。真实蓝牙键盘可由 `IOHIDUserDevice` 实现，这个类名本身不是虚拟证据。
- `SeizeSession`：显式状态机及可注入 controller。close 失败保持 error，不伪造 available。worker 结束作为系统回收句柄的兜底，实际恢复仍需验收。
- `Worker`：主 run loop 串行执行 HID 操作；本轮外接移除即结束，最长 30 秒。独立队列在时限后 3 秒强制结束卡住进程，父进程退出后尝试释放并在 1 秒后兜底结束。GUI 也在启动后 35 秒兜底结束 worker。系统整体挂起或 OS 驱动异常不在这些用户态定时器保证范围内。
- `InspectorApp`：独立窗口，启动 worker、按序消费 JSONL、原始 IOReturn、人工观察。只有观察者可声明物理通过。

本次不包含 Phase 3 自动触发策略、Phase 4 DriverKit/虚拟 HID、正式 Phase 5 XPC/登录与锁屏保证、Phase 6 产品化。POC 的有限时长与释放措施是实验保护，不代表完整生产级恢复验收。

## 证据

GUI 默认写到系统临时目录 `KeyboardGuardPOC/session-<UUID>.jsonl`；指定 `--evidence-dir` 可写入项目 `output/keyboard-poc`。文件权限 0600。按 `runID` 关联单轮。

验收时区分：`source=program` 的 API 与设备事实、`source=user_observation` 的人工确认。未勾选不等于失败或通过。程序不保存具体按键、输入文本、report、全局输入或按键统计，不上传数据。

OpenSpec 变更 `add-keyboard-seize-poc` 位于仓库已忽略的 `openspec/`；本文件及验收记录位于可追踪的 POC 目录，随分支交付。
