import 'dart:async';

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

/// Stub implementation for platforms without dart:io (web).
class CliExecutor {
  final ExecutionConfig defaultConfig;

  CliExecutor({ExecutionConfig? config})
      : defaultConfig = config ?? const ExecutionConfig();

  static Future<CliResult> run(
    String command, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? environment,
  }) async {
    return CliResult(
      exitCode: -1,
      stdout: '',
      stderr: 'Shell no disponible en esta plataforma',
      command: command,
    );
  }

  Future<CliResult> execute(String command, {ExecutionConfig? config}) async {
    return CliResult(
      exitCode: -1,
      stdout: '',
      stderr: 'Shell no disponible en esta plataforma',
      command: command,
    );
  }

  Future<CliResult> ejecutarComando(String comando, {ExecutionConfig? config}) =>
      execute(comando, config: config);

  Stream<String> stream(String command, {ExecutionConfig? config}) async* {
    yield 'Shell no disponible en esta plataforma';
  }

  Stream<String> ejecutarStream(String comando, {ExecutionConfig? config}) =>
      stream(comando, config: config);

  bool kill([dynamic signal]) => false;
}
