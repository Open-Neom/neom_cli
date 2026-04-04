import 'dart:convert';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal;

  String get emoji {
    switch (this) {
      case LogLevel.debug: return '🔍';
      case LogLevel.info: return '💬';
      case LogLevel.warning: return '⚠️';
      case LogLevel.error: return '🛑';
      case LogLevel.fatal: return '💀';
    }
  }

  String get label {
    switch (this) {
      case LogLevel.debug: return 'DEBUG';
      case LogLevel.info: return 'INFO';
      case LogLevel.warning: return 'WARN';
      case LogLevel.error: return 'ERROR';
      case LogLevel.fatal: return 'FATAL';
    }
  }
}

class LogEntry {
  final LogLevel level;
  final String message;
  final String? tag;
  final DateTime timestamp;
  final Duration? elapsed;
  final Map<String, dynamic>? metadata;

  LogEntry({
    required this.level,
    required this.message,
    this.tag,
    DateTime? timestamp,
    this.elapsed,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'message': message,
    if (tag != null) 'tag': tag,
    'timestamp': timestamp.toIso8601String(),
    if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
    if (metadata != null) 'metadata': metadata,
  };

  String toJsonString() => jsonEncode(toJson());

  String formatted({bool useEmoji = true}) {
    final prefix = useEmoji ? level.emoji : '[${level.label}]';
    final tagStr = tag != null ? ' [$tag]' : '';
    return '$prefix$tagStr $message';
  }

  @override
  String toString() => formatted();
}
