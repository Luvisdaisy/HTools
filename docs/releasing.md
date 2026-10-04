# 发布说明入口

当前发布 **HTools v0.2.1 通用 DMG 预览版**，不再是仅源码发布。

权威步骤见根目录 [RELEASING.md](../RELEASING.md)，用户安装与更新见 [INSTALL.md](../INSTALL.md)，验证边界见 [manual-testing.md](manual-testing.md)。

文档与源码随同一 PR 合并；主分支 CI 通过后，在合并提交上创建版本 tag，上传该提交生成并验证的 DMG 与 SHA-256。发布为 pre-release，明确临时签名且未公证。历史版本保留，不上传旧构建冒充新版本。
