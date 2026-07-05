# CodexUsageWidget

## 中文说明

CodexUsageWidget 是一个原生 macOS 菜单栏小工具，用来查看个人 Codex 使用情况。它会安静地待在系统菜单栏里，显示 5 小时额度剩余百分比和重置时间；点击菜单栏项目即可展开用量详情。

### 功能

- 在菜单栏显示 Codex 图标、5 小时额度剩余百分比和重置时间。
- 点击菜单栏项目后显示 5 小时额度、本周额度和最近用量详情。
- 使用最近 7 天 token 用量柱状图，更直观看到每天用量高低。
- 鼠标悬停在柱状图日期上时显示当天的精确 token 数。
- 支持手动刷新、自动刷新间隔设置、开机启动，以及可选显示/隐藏 7 日用量。
- 使用柔和蓝色作为用量和额度视觉提示；0 用量日期不显示柱子，图表更清爽。

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

启动后，应用不会出现在 Dock 中，而是显示在 macOS 顶部菜单栏。点击菜单栏里的 Codex 图标和额度文本即可展开面板。

建议从 Finder 或普通 Terminal 启动打包后的 app。如果从受限沙盒环境里启动，Codex app-server 可能无法访问本地状态数据库，导致额度数据不可用。

当前构建脚本生成的是未签名 app。首次运行时，macOS 可能会提示来源不明，需要在系统安全设置中手动允许。

### 数据来源与隐私

主要数据来源是本地 Codex app-server 协议：

- `account/usage/read`
- `account/rateLimits/read`

额度更新目前通过定时轮询 `account/rateLimits/read` 实现。为了显示可用重置机会的具体过期时间，应用还会从 `~/.codex/auth.json` 读取 `tokens.access_token`，只在内存中用它请求 OpenAI 的 `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits` 接口。应用不会保存 access token、refresh token、cookie 或完整唯一 ID。

如果账号用量数据不可用，应用会回退读取本地 Codex 会话 JSONL 文件：

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

回退读取时，本工具会遍历这些目录中的 `.jsonl` 文件，只尝试解析 `event_msg` 中 `payload.type == "token_count"` 的事件，并读取 `last_token_usage.total_tokens` 统计字段。它不会展示会话正文，也不会向远程服务器上传本地会话内容。

本工具会在 macOS Application Support 目录下保存一个本地缓存文件，通常位于 `~/Library/Application Support/CodexUsageWidget/cache.json`。缓存用于离线或刷新失败时显示最近一次用量数据，不包含认证信息；重置机会缓存仅包含可用次数、状态、标题、获得时间和过期时间。

### 开源协议

本项目使用 MIT License 开源，详见 [LICENSE](LICENSE)。

### 免责声明

CodexUsageWidget 是一个非官方个人工具，不隶属于 OpenAI，也不代表 OpenAI 官方产品。Codex、OpenAI 及相关名称归其各自权利方所有。

本项目依赖本地 Codex app-server 协议和本地会话日志格式。这些接口和文件结构可能随着 Codex 更新而变化，因此本工具可能在未来版本中失效或需要调整。

本项目完全通过 vibe coding 方式生成和迭代，包括代码、文档与构建脚本。它更像是一个实用型实验项目，而不是经过严格产品化、审计或长期兼容性保障的软件。请自行判断是否适合使用，并在公开分享或二次开发前自行检查代码行为。

本项目按 MIT License 以“现状”提供，不提供任何明示或暗示担保。使用本项目产生的任何问题、数据误读、额度显示误差或兼容性问题，均由使用者自行承担风险。

## English

CodexUsageWidget is a small native macOS menu bar utility for personal Codex usage. It sits quietly in the system menu bar, showing your five-hour quota percentage and reset time; click the menu bar item to open the detailed usage popover.

### Features

- Shows the Codex icon, five-hour quota percentage, and reset time in the menu bar.
- Opens a popover with five-hour quota, weekly quota, and recent usage details.
- Shows a seven-day daily token usage bar chart for clearer comparison.
- Shows exact daily token counts when hovering over chart dates.
- Supports manual refresh, configurable auto-refresh interval, launch at login, and toggling the seven-day usage chart.
- Uses a soft blue visual scale for usage and quota bars; zero-usage days do not render bars, keeping the chart cleaner.

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

After launch, the app does not appear in the Dock. It appears in the macOS menu bar instead; click the Codex icon and quota text to open the popover.

It is best to launch the bundled app from Finder or a normal Terminal session. If launched from a restricted sandbox, the Codex app-server may be unable to access its local state database, which can prevent quota data from loading.

The build script currently creates an unsigned app. On first launch, macOS may warn that the app is from an unidentified developer, and you may need to allow it manually in System Settings.

### Data Sources and Privacy

The primary data source is the local Codex app-server protocol:

- `account/usage/read`
- `account/rateLimits/read`

Quota updates are currently implemented by periodically polling `account/rateLimits/read`. To show exact reset-credit expiration times, the app also reads `tokens.access_token` from `~/.codex/auth.json` in memory and uses it to request OpenAI's `https://chatgpt.com/backend-api/wham/rate-limit-reset-credits` endpoint. The app does not save access tokens, refresh tokens, cookies, or full unique IDs.

If account usage data is unavailable, the app falls back to local Codex session JSONL files:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

When using the fallback path, the app scans `.jsonl` files in these folders, only attempts to parse `event_msg` entries whose `payload.type` is `token_count`, and reads the `last_token_usage.total_tokens` statistics field. It does not display conversation contents and does not upload local conversation contents to a remote server.

The app stores a local cache file under macOS Application Support, usually at `~/Library/Application Support/CodexUsageWidget/cache.json`. The cache is used to show the most recent usage snapshot when offline or when refresh fails, and it does not contain authentication data; reset-credit cache entries only include count, status, title, granted time, and expiration time.

### License

This project is released under the MIT License. See [LICENSE](LICENSE).

### Disclaimer

CodexUsageWidget is an unofficial personal tool. It is not affiliated with, endorsed by, or maintained by OpenAI. Codex, OpenAI, and related names belong to their respective owners.

This project depends on the local Codex app-server protocol and local session log formats. These interfaces and file structures may change as Codex evolves, so this tool may break or require updates in the future.

This project was fully generated and iterated through a vibe coding workflow, including the code, documentation, and build script. Treat it as a practical experimental utility rather than a formally productized, audited, or long-term compatibility-guaranteed application. Please review the code yourself before relying on it, publishing it, or building on top of it.

This project is provided “as is” under the MIT License, without warranty of any kind. You are responsible for any issues, misread usage numbers, quota display inaccuracies, or compatibility problems that may result from using it.
