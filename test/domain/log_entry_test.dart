import 'dart:convert';

import 'package:neom_cli/src/domain/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    test('levels have correct ordering', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
      expect(LogLevel.error.index, lessThan(LogLevel.fatal.index));
    });

    test('levels have labels', () {
      expect(LogLevel.debug.label, equals('DEBUG'));
      expect(LogLevel.error.label, equals('ERROR'));
    });
  });

  group('LogEntry', () {
    test('toJson produces valid JSON', () {
      final entry = LogEntry(
        level: LogLevel.info,
        message: 'test message',
        tag: 'TEST',
      );
      final json = entry.toJson();

      expect(json['level'], equals('info'));
      expect(json['message'], equals('test message'));
      expect(json['tag'], equals('TEST'));
    });

    test('toJsonString is parseable', () {
      final entry = LogEntry(level: LogLevel.warning, message: 'warn');
      final parsed = jsonDecode(entry.toJsonString());

      expect(parsed['level'], equals('warning'));
      expect(parsed['message'], equals('warn'));
    });

    test('formatted with emoji', () {
      final entry = LogEntry(level: LogLevel.error, message: 'fail', tag: 'SYS');
      final formatted = entry.formatted(useEmoji: true);

      expect(formatted, contains('fail'));
      expect(formatted, contains('[SYS]'));
    });

    test('formatted without emoji', () {
      final entry = LogEntry(level: LogLevel.info, message: 'ok');
      final formatted = entry.formatted(useEmoji: false);

      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('ok'));
    });
  });
}
