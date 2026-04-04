# Changelog

## 1.0.0

Initial public release.

### Features

- **CliExecutor** — Cross-platform shell command execution (Windows: `cmd`, Unix: `bash`)
  - `CliExecutor.run()` — Static convenience method for one-shot commands
  - `CliExecutor().execute()` — Instance method with custom configuration
  - `CliExecutor().stream()` — Real-time line-by-line output streaming
  - Configurable timeout, working directory, and environment variables
  - Process kill support via `CliExecutor().kill()`
- **CliResult** — Structured command result with exit code, stdout, stderr, duration, and timestamp
  - JSON serialization (`toJson` / `fromJson`)
  - Convenience getters: `isSuccess`, `isTimeout`, `hasOutput`, `hasError`
- **NeomLogger** — Structured logging with levels, tags, task tracking, and JSON output
- **LogEntry** — Log entry model with level, message, tag, timestamp, and metadata
- **CLI binary** (`neom`) with `exec` and `version` commands
- Web-safe stub implementation for cross-platform compilation
