import 'package:neom_cli/neom_cli.dart';
import 'package:test/test.dart';

void main() {
  group('Lote 90 — neom_cli Web & VM hardening', () {
    test('CliExecutor.validateExecutionInputs rejects NTFS ADS, Unicode LS/PS, zero-width, and bad env keys', () {
      expect(
        CliExecutor.validateExecutionInputs(
          'echo hi',
          config: const ExecutionConfig(workingDirectory: '/tmp/work:hidden'),
        ),
        isNotNull,
      );
      expect(
        CliExecutor.validateExecutionInputs(
          'echo hi',
          config: const ExecutionConfig(workingDirectory: r'C:\work\dir:ads'),
        ),
        isNotNull,
      );
      expect(
        CliExecutor.validateExecutionInputs(
          'echo hi',
          config: const ExecutionConfig(workingDirectory: r'C:\work\dir'),
        ),
        isNull,
      );
      expect(
        CliExecutor.validateExecutionInputs(
          'echo hi',
          config: const ExecutionConfig(workingDirectory: '/tmp/work\u2028inject'),
        ),
        isNotNull,
      );
      expect(
        CliExecutor.validateExecutionInputs(
          'echo hi',
          config: const ExecutionConfig(environment: {'KEY\u200B': '1'}),
        ),
        isNotNull,
      );

      final scrubbed = CliExecutor.buildEffectiveEnvironment(
        const ExecutionConfig(
          environment: {'SAFE_VAR': '1', 'BAD\u2029KEY': '2', 'DYLD_PRINT_OPTS': '1'},
        ),
        parentEnvironment: {'PATH': '/usr/bin', 'LD_AUDIT': '/evil.so'},
      );
      expect(scrubbed, equals({'PATH': '/usr/bin', 'SAFE_VAR': '1'}));
    });

    test('LogEntry redacts tokens/URL passwords and strips Unicode LS/PS & prototype keys', () {
      final entry = LogEntry(
        level: LogLevel.warning,
        tag: 'GIT\u2028SYNC',
        message:
            'Auth failed for https://oauth2:ghp_1234567890abcdefghijklmnopqrstuvwx@github.com/org/repo '
            'with Bearer secretBearerToken12345\u2029injected',
        metadata: {
          '__proto__': {'polluted': true},
          'constructor': 'bad',
          'token': 'glpat-1234567890abcdefghijkl',
          'anthropic': 'sk-ant-api03-1234567890abcdefghijklmnop',
        },
      );

      final formatted = entry.formatted(useEmoji: false);
      expect(formatted, isNot(contains('ghp_')));
      expect(formatted, isNot(contains('secretBearerToken12345')));
      expect(formatted, isNot(contains('\u2028')));
      expect(formatted, isNot(contains('\u2029')));
      expect(formatted, contains('https://[REDACTED]@github.com/org/repo'));

      final json = entry.toJson();
      expect(json['message'], isNot(contains('ghp_')));
      expect(json['tag'], equals('GIT SYNC'));
      final meta = json['metadata'] as Map<String, dynamic>;
      expect(meta.containsKey('__proto__'), isFalse);
      expect(meta.containsKey('constructor'), isFalse);
      expect(meta['token'], '[REDACTED]');
      expect(meta['anthropic'], '[REDACTED]');
    });

    test('CliResult.fromJson clamps negative durationMs and parses float strings safely', () {
      final res = CliResult.fromJson({
        'exitCode': '0.0',
        'stdout': 'ok',
        'stderr': '',
        'durationMs': -500,
      });
      expect(res.exitCode, 0);
      expect(res.duration, Duration.zero);

      final nonFinite = CliResult.fromJson({
        'exitCode': double.nan,
        'durationMs': double.infinity,
      });
      expect(nonFinite.exitCode, -1);
      expect(nonFinite.duration, isNull);
    });
  });
}
