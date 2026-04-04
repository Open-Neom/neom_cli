import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/cli_result.dart';

/// Configuration for command execution.
class ExecutionConfig {
  final String? workingDirectory;
  final Duration timeout;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;

  const ExecutionConfig({
    this.workingDirectory,
    this.timeout = const Duration(seconds: 30),
    this.environment,
    this.includeParentEnvironment = true,
  });
}

class CliExecutor {
  final ExecutionConfig defaultConfig;
  Process? _activeProcess;

  CliExecutor({ExecutionConfig? config})
      : defaultConfig = config ?? const ExecutionConfig();

  // ---- Static convenience method for command execution ----

  static Future<CliResult> run(
    String command, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? environment,
  }) {
    return CliExecutor().execute(command,
      config: ExecutionConfig(
        workingDirectory: workingDirectory,
        timeout: timeout,
        environment: environment,
      ),
    );
  }

  // ---- Instance methods ----

  /// Execute a command and wait for result.
  Future<CliResult> execute(String command, {ExecutionConfig? config}) async {
    final cfg = config ?? defaultConfig;
    final stopwatch = Stopwatch()..start();
    try {
      final shell = Platform.isWindows ? 'cmd' : 'bash';
      final args = Platform.isWindows ? ['/c', command] : ['-c', command];

      final result = await Process.run(
        shell,
        args,
        workingDirectory: cfg.workingDirectory,
        environment: cfg.environment,
        includeParentEnvironment: cfg.includeParentEnvironment,
      ).timeout(cfg.timeout);

      stopwatch.stop();
      return CliResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString().trim(),
        stderr: result.stderr.toString().trim(),
        command: command,
        duration: stopwatch.elapsed,
        workingDirectory: cfg.workingDirectory,
      );
    } on TimeoutException {
      stopwatch.stop();
      return CliResult(
        exitCode: -2,
        stdout: '',
        stderr: 'TIMEOUT: Comando excedio ${cfg.timeout.inSeconds}s',
        command: command,
        duration: stopwatch.elapsed,
        workingDirectory: cfg.workingDirectory,
      );
    } catch (e) {
      stopwatch.stop();
      return CliResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
        command: command,
        duration: stopwatch.elapsed,
        workingDirectory: cfg.workingDirectory,
      );
    }
  }

  /// Spanish alias for [execute].
  Future<CliResult> ejecutarComando(String comando, {ExecutionConfig? config}) =>
      execute(comando, config: config);

  /// Execute a command and stream output in real-time (stdout + stderr merged).
  Stream<String> stream(String command, {ExecutionConfig? config}) async* {
    final cfg = config ?? defaultConfig;
    try {
      final shell = Platform.isWindows ? 'cmd' : 'bash';
      final args = Platform.isWindows ? ['/c', command] : ['-c', command];

      final process = await Process.start(
        shell,
        args,
        workingDirectory: cfg.workingDirectory,
        environment: cfg.environment,
        includeParentEnvironment: cfg.includeParentEnvironment,
      );
      _activeProcess = process;

      final controller = StreamController<String>();
      final decoder = const SystemEncoding().decoder;

      final stdoutSub = process.stdout
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add(line));
      final stderrSub = process.stderr
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('[STDERR] $line'));

      unawaited(Future.wait([
        stdoutSub.asFuture<void>(),
        stderrSub.asFuture<void>(),
      ]).then((_) {
        stdoutSub.cancel();
        stderrSub.cancel();
        controller.close();
      }));

      yield* controller.stream;

      _activeProcess = null;
    } catch (e) {
      yield 'Error ejecutando el stream: $e';
    }
  }

  /// Spanish alias for [stream].
  Stream<String> ejecutarStream(String comando, {ExecutionConfig? config}) =>
      stream(comando, config: config);

  /// Kill the active streaming process.
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    final killed = _activeProcess?.kill(signal) ?? false;
    if (killed) _activeProcess = null;
    return killed;
  }
}
