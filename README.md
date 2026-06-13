# CodexUsageWidget

CodexUsageWidget is a small native macOS floating panel for personal Codex usage.

It shows:

- The last seven days of token usage as a heatmap.
- Hover tooltips with exact daily token counts.
- Five-hour and weekly Codex quota remaining plus reset times.

The primary data source is the local Codex app-server protocol:

- `account/usage/read`
- `account/rateLimits/read`
- `account/rateLimits/updated`

If account usage is unavailable, the app falls back to local Codex session JSONL files under `~/.codex/sessions` and `~/.codex/archived_sessions`. It does not read or store `auth.json`.

## Build

This project is intentionally a Swift Package so it can be built without an Xcode project:

```bash
swift test
swift run CodexUsageWidget
```

To assemble a simple `.app` bundle after the Swift toolchain is healthy:

```bash
zsh Scripts/build-app.zsh
```

Current local note: the machine previously reported a Swift/Command Line Tools SDK mismatch. Fix or reinstall matching Xcode / Command Line Tools first if `swift -e 'import SwiftUI'` fails.
