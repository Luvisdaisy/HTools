# Contributing / 参与贡献

欢迎提交可复现的问题、文档改进和小范围修复。中文和英文均可。

## 开发环境

- macOS 与完整 Xcode 26+（用于编译 Icon Composer 图标），命令行工具需指向对应 Xcode。
- App 部署目标 macOS 13，XCTest target 最低 macOS 14；CI 固定 Xcode 26.6，当前本机使用 Xcode 27。
- 直接打开 `HTools.xcodeproj`；应用构建无第三方依赖。

```sh
./scripts/build.sh Debug
./scripts/test.sh
```

单元测试宿主不启动 Finder 服务，不需要辅助功能权限。涉及窗口行为的修改，请实机检查尺寸、缩放、开关和权限变化；键盘修改应分别记录组件测试、系统 API 和实体按键证据。测试不会安装后台服务或禁用键盘。

## 修改约定

1. 较大的行为变化先开 Issue 描述问题、预期和替代方案。
2. 从 `main` 创建分支，每个 PR 聚焦一个问题。
3. 遵循现有 Swift 风格及模块边界。AX 调用和窗口状态留在服务串行队列，UI 更新回主线程。
4. 行为变化补充有意义的回归测试，同步相关文档。文案和纯排版修改无需机械增加测试。
5. 新增、删除 Swift 文件或修改工程生成配置后，运行 `python3 scripts/create-project.py`，将工程与生成器一起提交。生成器会覆盖工程和共享 Scheme，定制构建配置应先修改生成器。
6. 提交前运行 `git diff --check`、构建和相关测试；说明未验证的桌面行为。

不要提交 `build/`、`dist/`、`docs/evidence/` 和 `docs/local-history/`、原始桌面日志、个人配置、签名证书或令牌。图标生成是独立开发工具，参阅 [assets/README.md](assets/README.md)，正常构建无需 Python 或 Pillow。

## Pull request 内容

说明问题、修改后的行为、测试结果和剩余限制。界面修改可附去除私人信息的截图。CI 只能证明编译和组件测试，不能替代真实访达与键盘验收。

请保持尊重，讨论具体问题。提交贡献表示你同意将贡献按项目的 MIT 许可证分发。

## English summary

Use focused branches and PRs from `main`. Run `./scripts/build.sh Debug`, `./scripts/test.sh`, and `git diff --check`. Keep UI work on the main thread and Accessibility work on the service queue. Regenerate the Xcode project after adding/removing Swift files; update the generator before changing generated build settings. Document manual Finder checks separately from unit tests. Never attach credentials or unredacted desktop logs. Contributions are licensed under MIT.
