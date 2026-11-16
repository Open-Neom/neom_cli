import 'dart:io';

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

    test('execute actively kills timed-out child process (no orphan leak)', () async {
      if (Platform.isWindows) return;
      final tmp = Directory.systemTemp.createTempSync('neom_cli_timeout_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final pidFile = File('${tmp.path}/child.pid');

      final result = await executor.execute(
        'echo \$\$ > "${pidFile.path}" && exec sleep 30',
        config: const ExecutionConfig(timeout: Duration(milliseconds: 400)),
      );

      expect(result.isTimeout, isTrue);
      expect(pidFile.existsSync(), isTrue);
      final pid = int.parse(pidFile.readAsStringSync().trim());

      // Give kernel a brief moment to reap the terminated process.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final probe = await Process.run('kill', ['-0', '$pid']);
      expect(probe.exitCode, isNot(0));
    });

    test('execute enforces maxOutputBytes cap without OOM', () async {
      final result = await executor.execute(
        'printf "%0512d" 0',
        config: const ExecutionConfig(maxOutputBytes: 128),
      );

      expect(result.isSuccess, isTrue);
      expect(result.stdout, contains('[TRUNCATED: output exceeded 128B]'));
    });

    test('stream cancellation terminates underlying child process', () async {
      if (Platform.isWindows) return;
      final tmp = Directory.systemTemp.createTempSync('neom_cli_stream_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      final pidFile = File('${tmp.path}/stream.pid');

      final firstLines = await executor
          .stream('echo \$\$ > "${pidFile.path}"; echo ready1; echo ready2; exec sleep 30')
          .take(2)
          .toList();

      expect(firstLines, equals(['ready1', 'ready2']));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final pid = int.parse(pidFile.readAsStringSync().trim());
      final probe = await Process.run('kill', ['-0', '$pid']);
      expect(probe.exitCode, isNot(0));
    });
  });
}
