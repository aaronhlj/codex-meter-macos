# Contributing / 参与贡献

感谢你帮助改进 Codex Meter。Thank you for helping improve Codex Meter.

## 提交问题 / Reporting Issues

- 提交前请先搜索现有 Issue。
- 请说明 macOS 版本、Codex 安装方式、复现步骤和预期结果。
- 截图或日志中请删除账户信息、会话内容、用户名和本机路径。

- Search existing issues before opening a new one.
- Include your macOS version, Codex installation method, reproduction steps, and expected behavior.
- Remove account details, conversation content, usernames, and local paths from screenshots or logs.

## 开发流程 / Development Workflow

1. Fork 仓库并创建功能分支。Fork the repository and create a focused branch.
2. 保持改动范围清晰，并为行为变更添加测试。Keep changes focused and add tests for behavioral changes.
3. 运行 `swift test` 和 `./scripts/build-app.sh`。Run both checks locally.
4. 提交 Pull Request，说明改动原因和验证方式。Open a pull request describing the reason and validation.

## 代码风格 / Code Style

- 遵循现有 Swift 与 SwiftUI 风格。
- 优先使用系统框架，避免不必要的第三方依赖。
- 不要提交构建产物、本地 Codex 数据、凭据或开发工具状态文件。

- Follow the existing Swift and SwiftUI style.
- Prefer system frameworks and avoid unnecessary third-party dependencies.
- Do not commit build artifacts, local Codex data, credentials, or tool state.
