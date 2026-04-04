import 'package:neom_cli/src/domain/cli_result.dart';
import 'package:test/test.dart';

void main() {
  group('CliResult', () {
    test('isSuccess returns true for exit code 0', () {
      final result = CliResult(exitCode: 0, stdout: 'ok', stderr: '');
      expect(result.isSuccess, isTrue);
    });

    test('isSuccess returns false for non-zero exit code', () {
      final result = CliResult(exitCode: 1, stdout: '', stderr: 'error');
      expect(result.isSuccess, isFalse);
    });

    test('isTimeout returns true for exit code -2', () {
      final result = CliResult(exitCode: -2, stdout: '', stderr: 'TIMEOUT');
      expect(result.isTimeout, isTrue);
    });

    test('hasOutput and hasError', () {
      final result = CliResult(exitCode: 0, stdout: 'data', stderr: 'warn');
      expect(result.hasOutput, isTrue);
      expect(result.hasError, isTrue);

      final empty = CliResult(exitCode: 0, stdout: '', stderr: '');
      expect(empty.hasOutput, isFalse);
      expect(empty.hasError, isFalse);
    });

    test('toJson/fromJson round-trip', () {
      final original = CliResult(
        exitCode: 0,
        stdout: 'hello',
        stderr: '',
        command: 'echo hello',
        duration: const Duration(milliseconds: 42),
        workingDirectory: '/tmp',
      );

      final json = original.toJson();
      final restored = CliResult.fromJson(json);

      expect(restored.exitCode, equals(0));
      expect(restored.stdout, equals('hello'));
      expect(restored.command, equals('echo hello'));
      expect(restored.duration?.inMilliseconds, equals(42));
      expect(restored.workingDirectory, equals('/tmp'));
    });

    test('copyWith preserves unmodified fields', () {
      final original = CliResult(
        exitCode: 0, stdout: 'a', stderr: 'b', command: 'test',
      );
      final copy = original.copyWith(exitCode: 1);

      expect(copy.exitCode, equals(1));
      expect(copy.stdout, equals('a'));
      expect(copy.command, equals('test'));
    });
  });
}
