import 'dart:io';

import '../domain/log_entry.dart';

class NeomLogger {
  final LogLevel minLevel;
  final bool useEmoji;
  final bool jsonOutput;
  final IOSink? fileSink;
  final Stopwatch _stopwatch = Stopwatch();
  final List<LogEntry> _history = [];

  NeomLogger({
    this.minLevel = LogLevel.info,
    this.useEmoji = true,
    this.jsonOutput = false,
    this.fileSink,
  });

  List<LogEntry> get history => List.unmodifiable(_history);

  // ---- Level methods ----

  void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  void warning(String message, {String? tag}) =>
      _log(LogLevel.warning, message, tag: tag);

  void error(String message, {String? tag}) =>
      _log(LogLevel.error, message, tag: tag);

  void fatal(String message, {String? tag}) =>
      _log(LogLevel.fatal, message, tag: tag);

  // ---- Spanish aliases (backward compat) ----

  void log(String message) => info(message, tag: 'NEOM_OPS');

  // ---- Task tracking with stopwatch ----

  void startTask(String taskName) {
    _stopwatch.reset();
    _stopwatch.start();
    _log(LogLevel.info, 'Iniciando: $taskName', tag: 'NEOM_OPS');
  }

  void endTask(String taskName) {
    _stopwatch.stop();
    _log(
      LogLevel.info,
      'Finalizado: $taskName en ${_stopwatch.elapsedMilliseconds} ms.',
      tag: 'NEOM_OPS',
    );
  }

  // ---- Core ----

  void _log(LogLevel level, String message, {String? tag}) {
    if (level.index < minLevel.index) return;

    final entry = LogEntry(
      level: level,
      message: message,
      tag: tag,
      elapsed: _stopwatch.isRunning ? _stopwatch.elapsed : null,
    );
    _history.add(entry);

    final output = jsonOutput
        ? entry.toJsonString()
        : entry.formatted(useEmoji: useEmoji);

    print(output);
    fileSink?.writeln(output);
  }

  void dispose() {
    fileSink?.flush();
  }
}
