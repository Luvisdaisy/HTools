# 发布流程

当前采用源码测试版发布，不分发签名或公证安装包。发布者需要仓库写权限；贡献者只需提交 PR。

## 发布前

1. 确认工作区干净，文档、`CHANGELOG.md` 与实际行为一致。
2. 版本变化先更新 `scripts/create-project.py` 中的 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`，再生成工程。
3. 执行 `./scripts/build.sh`、`./scripts/test.sh`、`git diff --check`，确认 GitHub CI 通过。
4. 按[测试说明](manual-testing.md)执行适用的桌面验收；发布说明明确未重测和未覆盖的环境。
5. 确认提交不含本机日志、证书、个人路径及构建产物。

## 源码发布

以 `v<版本号>` 标记已经验证的提交，通过 GitHub Releases 创建说明。0.x 初期版本标为 pre-release。说明功能、构建步骤、测试环境及限制；GitHub 自动生成源码归档。

不要把本地 `dist/` 中的历史包直接当作当前版本上传。若今后提供二进制包，需从对应 tag 重新构建、验证架构和签名、提供校验和，并明确签名及公证状态。证书和公证凭证仅存入受限发布环境，不能进入仓库。

当前没有自动上传二进制的工作流，也不要求贡献者配置开发者证书。
