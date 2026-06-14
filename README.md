# CodexUsageWidget

## 中文说明

CodexUsageWidget 是一个原生 macOS 桌面浮窗，用来查看个人 Codex 使用情况。它适合放在屏幕角落，随时瞄一眼当前额度和最近用量。

### 功能

- 显示 Codex 5 小时额度和每周额度的剩余百分比。
- 在额度后显示重置时间：5 小时额度显示具体时间，本周额度显示日期。
- 可选显示最近 7 天 token 用量热力图。
- 鼠标悬停在热力图格子上时显示当天的精确 token 数。
- 支持置顶显示、手动刷新、自动刷新间隔设置和开机启动。
- 使用柔和蓝色作为用量和额度视觉提示，0 用量会显示为浅灰色。

### 使用

直接运行：

```bash
swift run CodexUsageWidget
```

也可以先打包成一个简单的 `.app`：

```bash
zsh Scripts/build-app.zsh
```

打包完成后打开：

```text
dist/CodexUsageWidget.app
```

建议从 Finder 或普通 Terminal 启动打包后的 app。如果从受限沙盒环境里启动，Codex app-server 可能无法访问本地状态数据库，导致额度数据不可用。

当前构建脚本生成的是未签名 app。首次运行时，macOS 可能会提示来源不明，需要在系统安全设置中手动允许。

### 数据来源与隐私

主要数据来源是本地 Codex app-server 协议：

- `account/usage/read`
- `account/rateLimits/read`

额度更新目前通过定时轮询 `account/rateLimits/read` 实现。

如果账号用量数据不可用，应用会回退读取本地 Codex 会话 JSONL 文件：

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

回退读取时，本工具会遍历这些目录中的 `.jsonl` 文件，只尝试解析 `event_msg` 中 `payload.type == "token_count"` 的事件，并读取 `last_token_usage.total_tokens` 统计字段。它不会展示会话正文，不会读取或保存 `auth.json`，也不会向远程服务器上传数据。

本工具会在 macOS Application Support 目录下保存一个本地缓存文件，通常位于 `~/Library/Application Support/CodexUsageWidget/cache.json`。缓存用于离线或刷新失败时显示最近一次用量数据，不包含认证信息。

### 开源协议

本项目使用 MIT License 开源，详见 [LICENSE](LICENSE)。

### 免责声明

CodexUsageWidget 是一个非官方个人工具，不隶属于 OpenAI，也不代表 OpenAI 官方产品。Codex、OpenAI 及相关名称归其各自权利方所有。

本项目依赖本地 Codex app-server 协议和本地会话日志格式。这些接口和文件结构可能随着 Codex 更新而变化，因此本工具可能在未来版本中失效或需要调整。

本项目完全通过 vibe coding 方式生成和迭代，包括代码、文档与构建脚本。它更像是一个实用型实验项目，而不是经过严格产品化、审计或长期兼容性保障的软件。请自行判断是否适合使用，并在公开分享或二次开发前自行检查代码行为。

本项目按 MIT License 以“现状”提供，不提供任何明示或暗示担保。使用本项目产生的任何问题、数据误读、额度显示误差或兼容性问题，均由使用者自行承担风险。

## English

CodexUsageWidget is a small native macOS floating panel for personal Codex usage. It is designed to sit quietly in a corner of your screen and show your current quota and recent activity at a glance.

### Features

- Shows remaining Codex quota for the five-hour and weekly windows.
- Shows reset timing next to each quota: exact time for the five-hour window and date for the weekly window.
- Optionally shows a seven-day token usage heatmap.
- Shows exact daily token counts when hovering over heatmap cells.
- Supports pinning, manual refresh, configurable auto-refresh interval, and launch at login.
- Uses a soft blue visual scale for usage and quota bars; zero-usage days are rendered in light gray.

### Usage

Run directly:

```bash
swift run CodexUsageWidget
```

Or build a simple `.app` bundle:

```bash
zsh Scripts/build-app.zsh
```

The bundled app will be written to:

```text
dist/CodexUsageWidget.app
```

It is best to launch the bundled app from Finder or a normal Terminal session. If launched from a restricted sandbox, the Codex app-server may be unable to access its local state database, which can prevent quota data from loading.

The build script currently creates an unsigned app. On first launch, macOS may warn that the app is from an unidentified developer, and you may need to allow it manually in System Settings.

### Data Sources and Privacy

The primary data source is the local Codex app-server protocol:

- `account/usage/read`
- `account/rateLimits/read`

Quota updates are currently implemented by periodically polling `account/rateLimits/read`.

If account usage data is unavailable, the app falls back to local Codex session JSONL files:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

When using the fallback path, the app scans `.jsonl` files in these folders, only attempts to parse `event_msg` entries whose `payload.type` is `token_count`, and reads the `last_token_usage.total_tokens` statistics field. It does not display conversation contents, does not read or store `auth.json`, and does not upload data to a remote server.

The app stores a local cache file under macOS Application Support, usually at `~/Library/Application Support/CodexUsageWidget/cache.json`. The cache is used to show the most recent usage snapshot when offline or when refresh fails, and it does not contain authentication data.

### License

This project is released under the MIT License. See [LICENSE](LICENSE).

### Disclaimer

CodexUsageWidget is an unofficial personal tool. It is not affiliated with, endorsed by, or maintained by OpenAI. Codex, OpenAI, and related names belong to their respective owners.

This project depends on the local Codex app-server protocol and local session log formats. These interfaces and file structures may change as Codex evolves, so this tool may break or require updates in the future.

This project was fully generated and iterated through a vibe coding workflow, including the code, documentation, and build script. Treat it as a practical experimental utility rather than a formally productized, audited, or long-term compatibility-guaranteed application. Please review the code yourself before relying on it, publishing it, or building on top of it.

This project is provided “as is” under the MIT License, without warranty of any kind. You are responsible for any issues, misread usage numbers, quota display inaccuracies, or compatibility problems that may result from using it.
