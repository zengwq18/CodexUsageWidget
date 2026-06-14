# CodexUsageWidget

CodexUsageWidget 是一个原生 macOS 小浮窗，用来查看个人 Codex 使用情况。

CodexUsageWidget is a small native macOS floating panel for personal Codex usage.

## 功能 / Features

它会显示：

It shows:

- 最近七天的 token 使用热力图。
- 鼠标悬停时显示每天的精确 token 数。
- Codex 五小时额度和每周额度的剩余量，以及对应的重置时间。

- A heatmap of token usage over the last seven days.
- Hover tooltips with exact daily token counts.
- Five-hour and weekly Codex quota remaining, plus reset times.

## 数据来源 / Data Sources

主要数据来源是本地 Codex app-server 协议：

The primary data source is the local Codex app-server protocol:

- `account/usage/read`
- `account/rateLimits/read`
- `account/rateLimits/updated`

如果账号用量数据不可用，应用会回退读取本地 Codex 会话 JSONL 文件，路径包括 `~/.codex/sessions` 和 `~/.codex/archived_sessions`。它不会读取或保存 `auth.json`。

If account usage is unavailable, the app falls back to local Codex session JSONL files under `~/.codex/sessions` and `~/.codex/archived_sessions`. It does not read or store `auth.json`.

## 构建 / Build

这个项目刻意保持为 Swift Package，因此不需要 Xcode 工程文件也可以构建：

This project is intentionally a Swift Package, so it can be built without an Xcode project:

```bash
swift test
swift run CodexUsageWidget
```

Swift 工具链可用后，可以执行下面的命令打包一个简单的 `.app`：

To assemble a simple `.app` bundle after the Swift toolchain is healthy:

```bash
zsh Scripts/build-app.zsh
```

当前本地备注：这台机器之前出现过 Swift / Command Line Tools SDK 版本不匹配的问题。如果 `swift -e 'import SwiftUI'` 失败，请先修复或重新安装匹配的 Xcode / Command Line Tools。

Current local note: this machine previously reported a Swift / Command Line Tools SDK mismatch. If `swift -e 'import SwiftUI'` fails, fix or reinstall matching Xcode / Command Line Tools first.
