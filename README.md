# Codex Meter for macOS

[中文](#中文) | [English](#english)

> An unofficial, native macOS menu bar app for monitoring Codex usage limits.

## 中文

Codex Meter 是一款轻量的原生 macOS 菜单栏应用，用两个彩色分段圆环实时显示 Codex **5 小时额度**和 **7 天额度**的剩余百分比。

### 功能

- 菜单栏同时显示 5 小时和 7 天剩余额度
- 按剩余比例自动变色：绿色、浅绿、黄色、橙色、红色
- 展示额度重置时间、套餐类型和数据更新时间
- 额度低于阈值时发送 macOS 通知
- 支持开机自动启动和手动刷新
- 优先读取 Codex 实时服务，并用本地会话数据补充或离线回退
- 不包含广告、统计分析或第三方遥测

### 系统要求

- macOS 13 Ventura 或更高版本
- 已安装并登录 Codex 桌面应用或 Codex CLI
- Apple Silicon Mac；其他架构可自行从源码构建

### 安装

从 GitHub Releases 下载最新版本，解压后将 `Codex Meter.app` 移入“应用程序”文件夹。

当前发布包采用临时签名，首次打开时可能需要在 Finder 中右键应用并选择“打开”。

### 从源码构建

需要 Xcode 及 Swift 6 工具链：

```bash
git clone https://github.com/3dzhou188/codex-meter-macos.git
cd codex-meter-macos
./scripts/build-app.sh
```

生成的应用位于 `dist/Codex Meter.app`。

运行测试：

```bash
swift test
```

### 数据来源与隐私

- Codex app-server 的 `account/rateLimits/read` 和额度更新通知
- `~/.codex/sessions` 中最近的本地额度事件，用于即时补充和离线回退

应用不会读取 `~/.codex/auth.json`，也不会自行上传提示词、会话内容或账户凭据。详见 [隐私说明](PRIVACY.md)。

### 参与贡献

欢迎提交 Issue 和 Pull Request。开始前请阅读 [贡献指南](CONTRIBUTING.md)、[安全政策](SECURITY.md)与[行为准则](CODE_OF_CONDUCT.md)。

## English

Codex Meter is a lightweight native macOS menu bar app that displays the remaining percentage of your Codex **5-hour** and **7-day** usage windows with two segmented, color-coded rings.

### Features

- Shows both 5-hour and 7-day remaining usage in the menu bar
- Changes color automatically from green to red as usage runs low
- Displays reset times, plan type, data source, and last update time
- Sends macOS notifications when remaining usage crosses thresholds
- Supports launch at login and manual refresh
- Uses the Codex app-server first, with local session data as a supplement and offline fallback
- No ads, analytics, or third-party telemetry

### Requirements

- macOS 13 Ventura or later
- Codex desktop app or Codex CLI installed and signed in
- Apple Silicon Mac; other architectures can build from source

### Installation

Download the latest archive from GitHub Releases, extract it, and move `Codex Meter.app` to your Applications folder.

Release builds are currently ad-hoc signed. On first launch, you may need to right-click the app in Finder and choose **Open**.

### Build From Source

Xcode and a Swift 6 toolchain are required:

```bash
git clone https://github.com/3dzhou188/codex-meter-macos.git
cd codex-meter-macos
./scripts/build-app.sh
```

The built app is created at `dist/Codex Meter.app`.

Run the tests with:

```bash
swift test
```

### Data and Privacy

- Codex app-server `account/rateLimits/read` responses and update notifications
- Recent local usage events under `~/.codex/sessions` for faster updates and offline fallback

The app does not read `~/.codex/auth.json` or independently upload prompts, conversations, or account credentials. See [Privacy](PRIVACY.md) for details.

### Contributing

Issues and pull requests are welcome. Please read the [Contributing Guide](CONTRIBUTING.md), [Security Policy](SECURITY.md), and [Code of Conduct](CODE_OF_CONDUCT.md) first.

## Disclaimer

Codex Meter is an independent, unofficial project. It is not affiliated with, endorsed by, or supported by OpenAI. Codex and OpenAI are trademarks of their respective owners.

## License

Released under the [MIT License](LICENSE).
