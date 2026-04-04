
import 'package:neom_cli/src/core/cli_executor.dart';
import 'package:test/test.dart';

void main() {
  group('CliExecutor', () {
    late CliExecutor executor;

    setUp(() {
      executor = CliExecutor();
    });

    test('execute runs simple command', () async {
      final result = await executor.execute('echo hello');

      expect(result.isSuccess, isTrue);
      expect(result.stdout, equals('hello'));
      expect(result.command, equals('echo hello'));
      expect(result.duration, isNotNull);
    });

    test('execute captures stderr', () async {
      final result = await executor.execute('echo error >&2');

      expect(result.stderr, contains('error'));
    });

    test('execute returns non-zero exit code on failure', () async {
      final result = await executor.execute('exit 42');

      expect(result.exitCode, equals(42));
      expect(result.isSuccess, isFalse);
    });

    test('execute respects working directory', () async {
      final result = await executor.execute('pwd',
        config: const ExecutionConfig(workingDirectory: '/tmp'),
      );

      expect(result.isSuccess, isTrue);
      // /tmp may resolve to /private/tmp on macOS
      expect(result.stdout, contains('tmp'));
    });

    test('execute times out', () async {
      final result = await executor.execute('sleep 10',
        config: const ExecutionConfig(timeout: Duration(milliseconds: 500)),
      );

      expect(result.isTimeout, isTrue);
      expect(result.exitCode, equals(-2));
      expect(result.stderr, contains('TIMEOUT'));
    });

    test('static run works', () async {
      final result = await CliExecutor.run('echo static');

      expect(result.isSuccess, isTrue);
      expect(result.stdout, equals('static'));
    });

    test('stream yields output lines', () async {
      final lines = await executor.stream('echo line1 && echo line2').toList();

      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines.any((l) => l.contains('line1')), isTrue);
      expect(lines.any((l) => l.contains('line2')), isTrue);
    });

    test('stream marks stderr lines', () async {
      final lines = await executor.stream('echo err >&2').toList();

      expect(lines.any((l) => l.contains('[STDERR]')), isTrue);
    });

    test('ejecutarComando is alias for execute', () async {
      final result = await executor.ejecutarComando('echo alias');
      expect(result.stdout, equals('alias'));
    });
  });
}
