# neom_cli

[![pub package](https://img.shields.io/pub/v/neom_cli.svg)](https://pub.dev/packages/neom_cli)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Cross-platform shell execution engine for Dart. Run commands with timeout, streaming output, and structured results on Windows, macOS, and Linux.

## Features

- **One-shot execution** — Run a command and get structured results
- **Streaming output** — Real-time line-by-line output for long-running commands
- **Cross-platform** — Windows (`cmd`), macOS/Linux (`bash`)
- **Timeout handling** — Configurable per-command timeouts with clean process termination
- **Structured results** — Exit code, stdout, stderr, duration, timestamp in `CliResult`
- **JSON serialization** — `CliResult.toJson()` / `CliResult.fromJson()` for persistence
- **Web-safe** — Stub implementation compiles on web (returns error gracefully)
- **Structured logging** — `NeomLogger` with levels, tags, task tracking, and JSON output

## Installation

```yaml
dependencies:
  neom_cli: ^1.0.0
```

## Usage

### Quick Execution

```dart
import 'package:neom_cli/neom_cli.dart';

final result = await CliExecutor.run('git status');

print(result.stdout);      // Working tree output
print(result.isSuccess);   // true if exit code == 0
print(result.duration);    // How long it took
```

### With Configuration

```dart
final executor = CliExecutor(
  config: ExecutionConfig(
    workingDirectory: '/path/to/project',
    timeout: Duration(seconds: 60),
    environment: {'NODE_ENV': 'production'},
  ),
);

final result = await executor.execute('npm run build');

if (result.isTimeout) {
  print('Build timed out after 60s');
} else if (result.isSuccess) {
  print('Build succeeded: ${result.stdout}');
} else {
  print('Build failed (exit ${result.exitCode}): ${result.stderr}');
}
```

### Streaming Output

```dart
final executor = CliExecutor();

await for (final line in executor.stream('tail -f /var/log/app.log')) {
  print('LOG: $line');
}
```

### Structured Logging

```dart
final logger = NeomLogger(jsonOutput: true);

logger.startTask('Deploy');
logger.info('Building artifacts...', tag: 'BUILD');
logger.warning('Cache miss detected', tag: 'CACHE');
logger.endTask('Deploy');
// Prints elapsed time automatically
```

### JSON Serialization

```dart
final result = await CliExecutor.run('echo hello');

// Serialize
final json = result.toJson();

// Deserialize
final restored = CliResult.fromJson(json);
```

## CLI Binary

neom_cli includes an executable for direct shell use:

```bash
# Execute a command
neom exec "git log --oneline -5"

# With timeout and streaming
neom exec --timeout 10 --stream "ping localhost"

# Check version
neom version
```

## API Reference

### CliExecutor

| Method | Description |
|--------|-------------|
| `CliExecutor.run(command)` | Static one-shot execution |
| `executor.execute(command)` | Instance execution with config |
| `executor.stream(command)` | Real-time output stream |
| `executor.kill()` | Terminate active process |

### CliResult

| Property | Type | Description |
|----------|------|-------------|
| `exitCode` | `int` | Process exit code |
| `stdout` | `String` | Standard output (trimmed) |
| `stderr` | `String` | Standard error (trimmed) |
| `command` | `String` | Original command |
| `duration` | `Duration?` | Execution time |
| `isSuccess` | `bool` | `exitCode == 0` |
| `isTimeout` | `bool` | `exitCode == -2` |

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.
