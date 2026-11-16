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

  static final RegExp _logControlOrBidiRe = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u200B-\u200F\u2028-\u202E\u2060-\u2069\u061C\uFEFF]',
  );

  static final RegExp _internalLogTagsRe = RegExp(
    r'<\|(?:channel|turn)>\s*thought\b[\s\S]*?(?:<(?:channel|turn)\|>|$)'
    r'|<\|tool_call>[\s\S]*?(?:<tool_call\|>|$)'
    r'|<\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?(?:<\s*/\s*\1\s*>|$)'
    r'|<\s*/?\s*(?:think|thought|memory_recall|auto_memory|system_context)\b[^>]*>'
    r'|<\|/?(?:turn|channel|eot|tool_call)\|?>'
    r'|<(?:turn|channel|tool_call)\|>',
    caseSensitive: false,
  );

  static final RegExp _urlUserInfoSecretRe = RegExp(
    r'(://)[^/\s:@]+:[^/\s@]+@',
  );

  static final RegExp _secretTokenRe = RegExp(
    r'(\b(?:Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{8,}'
    r'|(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}'
    r'|sk-(?:ant-)?[A-Za-z0-9_-]{20,}'
    r'|AIzaSy[A-Za-z0-9_-]{33}'
    r'|gh[pousr]_[A-Za-z0-9]{30,}'
    r'|github_pat_[A-Za-z0-9_]{22,}'
    r'|glpat-[A-Za-z0-9_-]{20,}'
    r'|(?:AKIA|ASIA)[0-9A-Z]{16}'
    r'|hf_[A-Za-z0-9]{30,}'
    r'|xox[baprs]-[A-Za-z0-9-]{15,}'
    r'|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,})',
  );

  static const Set<String> _prototypePollutionKeys = {
    '__proto__',
    'constructor',
    'prototype',
  };

  /// Masks embedded URL passwords and common API/OAuth/JWT tokens in [value].
  static String redactSecrets(String value) {
    if (value.isEmpty) return value;
    return value
        .replaceAllMapped(_urlUserInfoSecretRe, (m) => '${m.group(1)}[REDACTED]@')
        .replaceAll(_secretTokenRe, '[REDACTED]');
  }

  static String _sanitizeSingleLine(String value) => redactSecrets(value)
      .replaceAll(_internalLogTagsRe, ' ')
      .replaceAll(_logControlOrBidiRe, ' ');

  static Object? _sanitizeJsonValue(Object? value, [int depth = 0]) {
    if (value == null || value is bool) return value;
    if (value is String) return _sanitizeSingleLine(value);
    if (value is num) {
      return value.isFinite ? value : null;
    }
    if (depth >= 12) return _sanitizeSingleLine(value.toString());
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString().trim();
        final lower = key.toLowerCase();
        if (key.isEmpty ||
            _prototypePollutionKeys.contains(lower) ||
            (key.startsWith('__') && key.endsWith('__') && key.length >= 4)) {
          continue;
        }
        out[key] = _sanitizeJsonValue(entry.value, depth + 1);
      }
      return out;
    }
    if (value is Iterable) {
      return value.map((e) => _sanitizeJsonValue(e, depth + 1)).toList();
    }
    return _sanitizeSingleLine(value.toString());
  }

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'message': _sanitizeSingleLine(message),
    if (tag != null) 'tag': _sanitizeSingleLine(tag!),
    'timestamp': timestamp.toIso8601String(),
    if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
    if (metadata != null)
      'metadata': _sanitizeJsonValue(metadata) as Map<String, dynamic>,
  };

  String toJsonString() => jsonEncode(toJson());

  String formatted({bool useEmoji = true}) {
    final prefix = useEmoji ? level.emoji : '[${level.label}]';
    final safeTag = tag != null ? _sanitizeSingleLine(tag!) : null;
    final tagStr = safeTag != null ? ' [$safeTag]' : '';
    final safeMessage = _sanitizeSingleLine(message);
    return '$prefix$tagStr $safeMessage';
  }

  @override
  String toString() => formatted();
}
