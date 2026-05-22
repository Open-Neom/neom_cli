import 'package:neom_cli/src/domain/cli_result.dart';
import 'package:neom_cli/src/domain/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('CliResult flags', () {
    test('isSuccess only when exitCode == 0', () {
      expect(CliResult(exitCode: 0, stdout: '', stderr: '').isSuccess, isTrue);
      expect(CliResult(exitCode: 1, stdout: '', stderr: '').isSuccess, isFalse);
      expect(CliResult(exitCode: -1, stdout: '', stderr: '').isSuccess, isFalse);
    });

    test('isTimeout when exitCode == -2', () {
      expect(CliResult(exitCode: -2, stdout: '', stderr: '').isTimeout, isTrue);
      expect(CliResult(exitCode: -1, stdout: '', stderr: '').isTimeout, isFalse);
      expect(CliResult(exitCode: 0, stdout: '', stderr: '').isTimeout, isFalse);
    });

    test('hasOutput / hasError', () {
      final r = CliResult(exitCode: 0, stdout: 'hi', stderr: '');
      expect(r.hasOutput, isTrue);
      expect(r.hasError, isFalse);

      final r2 = CliResult(exitCode: 1, stdout: '', stderr: 'boom');
      expect(r2.hasOutput, isFalse);
      expect(r2.hasError, isTrue);
    });
  });

  group('CliResult JSON round-trip', () {
    test('toJson/fromJson preserves fields', () {
      final r = CliResult(
        exitCode: 2,
        stdout: 'out',
        stderr: 'err',
        command: 'echo',
        duration: const Duration(milliseconds: 123),
        workingDirectory: '/tmp',
        timestamp: DateTime.utc(2025, 1, 1, 12),
      );
      final json = r.toJson();
      expect(json['exitCode'], 2);
      expect(json['isSuccess'], isFalse);
      expect(json['durationMs'], 123);

      final back = CliResult.fromJson(json);
      expect(back.exitCode, 2);
      expect(back.stdout, 'out');
      expect(back.stderr, 'err');
      expect(back.command, 'echo');
      expect(back.duration, const Duration(milliseconds: 123));
      expect(back.workingDirectory, '/tmp');
    });

    test('fromJson tolerates missing optional fields', () {
      final r = CliResult.fromJson({'exitCode': 0});
      expect(r.stdout, '');
      expect(r.stderr, '');
      expect(r.duration, isNull);
    });
  });

  group('CliResult.copyWith', () {
    test('overrides only provided fields', () {
      final r = CliResult(exitCode: 0, stdout: 'a', stderr: 'b');
      final r2 = r.copyWith(exitCode: 1);
      expect(r2.exitCode, 1);
      expect(r2.stdout, 'a');
      expect(r2.stderr, 'b');
    });
  });

  group('LogEntry', () {
    test('formatted with emoji includes level emoji', () {
      final e = LogEntry(level: LogLevel.error, message: 'boom');
      expect(e.formatted(useEmoji: true), contains(LogLevel.error.emoji));
      expect(e.formatted(useEmoji: true), contains('boom'));
    });

    test('formatted without emoji uses [LABEL]', () {
      final e = LogEntry(level: LogLevel.warning, message: 'hi');
      final s = e.formatted(useEmoji: false);
      expect(s, contains('[WARN]'));
      expect(s, contains('hi'));
    });

    test('tag appears in formatted output', () {
      final e = LogEntry(level: LogLevel.info, message: 'm', tag: 'X');
      expect(e.formatted(), contains('[X]'));
    });

    test('toJson omits null tag/elapsed/metadata', () {
      final e = LogEntry(level: LogLevel.info, message: 'm');
      final json = e.toJson();
      expect(json.containsKey('tag'), isFalse);
      expect(json.containsKey('elapsedMs'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json['level'], 'info');
      expect(json['message'], 'm');
    });

    test('toJson includes tag/elapsed/metadata when provided', () {
      final e = LogEntry(
        level: LogLevel.debug,
        message: 'm',
        tag: 'T',
        elapsed: const Duration(milliseconds: 42),
        metadata: {'k': 'v'},
      );
      final json = e.toJson();
      expect(json['tag'], 'T');
      expect(json['elapsedMs'], 42);
      expect(json['metadata'], {'k': 'v'});
    });
  });

  group('LogLevel', () {
    test('all levels have unique emoji and label', () {
      final emojis = LogLevel.values.map((l) => l.emoji).toSet();
      final labels = LogLevel.values.map((l) => l.label).toSet();
      expect(emojis.length, LogLevel.values.length);
      expect(labels.length, LogLevel.values.length);
    });

    test('level index ordering', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
      expect(LogLevel.error.index, lessThan(LogLevel.fatal.index));
    });
  });
}
