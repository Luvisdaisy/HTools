# Security policy

Only the latest published version is maintained. Preview releases have limited compatibility coverage; see the README.

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/Luvisdaisy/HTools/security/advisories/new). Include affected version, macOS version, reproduction steps and impact. Do not include credentials, private documents or unredacted desktop logs.

If private reporting is unavailable, open an issue asking for a private contact channel without disclosing vulnerability details. There is no guaranteed response time or bug bounty.

Ordinary window-sizing bugs belong in public Issues. Accessibility permission is broad: the app limits its implementation to Finder window management, but it is not sandboxed. The keyboard feature installs a root-owned fixed-function helper, pins both XPC endpoints to the app executable signature, validates the active user and local socket, and limits worker lifetime with a heartbeat lease. Updates require a matching helper. Report authorization, IPC and recovery defects privately. See [PRIVACY.md](PRIVACY.md) for current data use.

安全漏洞请优先通过上述 GitHub 私密报告入口提交；普通尺寸与兼容性问题请使用公开 Issue。请勿公开凭证或私人文件内容。
