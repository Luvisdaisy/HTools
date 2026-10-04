# 免费 DMG 测试版发布

安装包使用 ad-hoc 签名，不需要付费开发者账号，没有 Developer ID 签名或公证。用户安装流程见 [INSTALL.md](INSTALL.md)。

当前版本：**v0.2.1（build 8）**。构建要求 Xcode 26+，CI 明确选择 Xcode 26.6。

1. 更新 `scripts/create-project.py` 的版本号和构建号，运行 `python3 scripts/create-project.py`；同步 CHANGELOG 和安装说明中的版本示例。
2. 运行 `./scripts/test.sh`、`git diff --check`。提交源码后，确认对应提交的 GitHub CI 通过。
3. 从该提交的干净工作区运行 `./scripts/package-dmg.sh`。脚本在独立临时构建目录生成 Release 双架构 App，验证临时签名、架构和 DMG 完整性，输出 `dist/` 下的 DMG 和 SHA-256 文件；不会覆盖已有同名包。
4. 只读挂载 DMG，检查 App、Applications 快捷入口和安装说明，验证映像内 App 的签名与架构。核对下载校验和。
5. 在测试 Mac 上从浏览器下载，测试 Gatekeeper 首次启动、复制到 Applications、辅助功能授权、新 Finder 窗口调整、退出和升级。明确记录未验证的环境；本机包校验和单元测试不能替代这项验收。
6. 为构建提交创建 `v<版本>` tag，通过 GitHub Releases 上传 DMG 及 `.sha256`。0.x 版本标记为 pre-release；发布说明包含未公证状态、安装步骤及验证边界。可以先创建 draft 供验收，再发布。

新身份为 `local.HTools`，应用显式迁移旧窗口偏好。后续保持此 Bundle ID 稳定。临时签名更新可能需要重新添加系统权限，并在权限页更新键盘服务以匹配新签名。不要上传历史构建、本机日志或凭证。证书与付费账号不属于本路线。

发布并验证后，删除本机旧 DMG、备份 App、Debug/Release 构建产物及临时缓存；保留当前 DMG、校验和和简短验证记录。最终从发布 DMG 安装到 `/Applications/HTools.app`，核对版本、签名、架构与包内二进制一致。`HToolsKeyboard.app` 是必要的系统服务，不是第二份可交互安装；在权限页更新服务后，核对其二进制与主应用一致。不要删除当前设计源、共享核心源码或有效测试证据。
