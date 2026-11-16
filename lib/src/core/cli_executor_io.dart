import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/cli_result.dart';

/// Configuration for command execution.
class ExecutionConfig {
  final String? workingDirectory;
  final Duration timeout;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;
  final int maxOutputBytes;

  const ExecutionConfig({
    this.workingDirectory,
    this.timeout = const Duration(seconds: 30),
    this.environment,
    this.includeParentEnvironment = true,
    this.maxOutputBytes = 4 * 1024 * 1024,
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

  // ---- Input validation ----

  static final RegExp _unsafePathControlOrBidiRe = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u200B-\u200F\u2028-\u202E\u2060-\u2069\u061C\uFEFF]',
  );

  static final RegExp _cliSecretRedactRe = RegExp(
    r'(://)[^/\s:@]+:[^/\s@]+@'
    r'|(\b(?:Bearer|Basic)\s+[A-Za-z0-9._~+/=-]{8,}'
    r'|\b(?:sk_live_|sk_test_|rk_live_|rk_test_|sk-|AIza|ghp_|gho_|ghu_|ghs_|ghr_|github_pat_|glpat-|hf_|xox[baprs]-)[A-Za-z0-9_-]{10,}'
    r'|\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'
    r'|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,})',
    caseSensitive: false,
  );

  static String redactCliDiagnostic(String raw) {
    if (raw.isEmpty) return raw;
    return raw.replaceAllMapped(_cliSecretRedactRe, (m) {
      if (m.group(1) != null) return '${m.group(1)}[REDACTED]@';
      return '[REDACTED]';
    });
  }

  static bool _hasNtfsAdsStream(String trimmedPath) {
    final rest = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmedPath)
        ? trimmedPath.substring(2)
        : trimmedPath;
    return rest.contains(':');
  }

  /// Dynamic-linker, shell-startup, and runtime-hook environment keys that
  /// must never be injected through [ExecutionConfig.environment].
  static const Set<String> blockedEnvironmentKeys = {
    'LD_PRELOAD',
    'LD_LIBRARY_PATH',
    'LD_AUDIT',
    'DYLD_INSERT_LIBRARIES',
    'DYLD_LIBRARY_PATH',
    'DYLD_FRAMEWORK_PATH',
    'DYLD_FALLBACK_LIBRARY_PATH',
    'BASH_ENV',
    'ENV',
    'PROMPT_COMMAND',
    'ZDOTDIR',
    'IFS',
    'SHELLOPTS',
    'BASHOPTS',
    'CDPATH',
    'NODE_OPTIONS',
    'NODE_PATH',
    'NODE_EXTRA_CA_CERTS',
    'ELECTRON_RUN_AS_NODE',
    'PYTHONPATH',
    'PYTHONHOME',
    'PYTHONSTARTUP',
    'PERL5OPT',
    'RUBYOPT',
    'JAVA_TOOL_OPTIONS',
    'JDK_JAVA_OPTIONS',
    '_JAVA_OPTIONS',
    'DART_VM_OPTIONS',
    'DOTNET_STARTUP_HOOKS',
    'OPENSSL_CONF',
    'OPENSSL_ENGINES',
    'SSL_CERT_FILE',
    'SSL_CERT_DIR',
    'CURL_CA_BUNDLE',
    'REQUESTS_CA_BUNDLE',
    'GCONV_PATH',
    'HOSTALIASES',
    'LOCALDOMAIN',
    'RES_OPTIONS',
    'GIT_SSH',
    'GIT_SSH_COMMAND',
    'GIT_EXEC_PATH',
    'GIT_TEMPLATE_DIR',
    'GIT_EDITOR',
    'GIT_PAGER',
    'GIT_CONFIG_PARAMETERS',
    'GIT_CONFIG_COUNT',
    'GIT_CONFIG_GLOBAL',
    'GIT_CONFIG_SYSTEM',
    'GIT_EXTERNAL_DIFF',
    'GIT_ASKPASS',
    'SSH_ASKPASS',
  };

  static final RegExp _encodedWdUnsafeRe = RegExp(
    r'%(?:00|2e|2f|5c|25|c2%[89][0-9a-f]|d8%9c|e2%80%(?:8[b-f]|a[8-e])|e2%81%a[0-46-9]|ef%bb%bf)',
    caseSensitive: false,
  );

  static bool _isBlockedEnvKey(String upperKey) =>
      blockedEnvironmentKeys.contains(upperKey) ||
      upperKey.startsWith('DYLD_') ||
      upperKey.startsWith('LD_') ||
      upperKey.startsWith('BASH_FUNC_') ||
      upperKey.startsWith('GIT_CONFIG_KEY_') ||
      upperKey.startsWith('GIT_CONFIG_VALUE_');

  /// Validates command, working directory, environment variables, and limits
  /// against NUL-byte injection, UNC paths, dangerous loader/interpreter env
  /// keys, malformed env keys, and invalid bounds.
  /// Returns `null` when valid, or a descriptive error string when rejected.
  static String? validateExecutionInputs(
    String command, {
    ExecutionConfig? config,
  }) {
    if (command.contains('\x00')) {
      return 'Comando rechazado: contiene bytes NUL (\\x00).';
    }
    final cfg = config ?? const ExecutionConfig();
    if (cfg.timeout <= Duration.zero) {
      return 'Configuración inválida: timeout debe ser mayor a 0.';
    }
    if (!cfg.maxOutputBytes.isFinite || cfg.maxOutputBytes <= 0) {
      return 'Configuración inválida: maxOutputBytes debe ser mayor a 0.';
    }
    final wd = cfg.workingDirectory;
    if (wd != null) {
      final trimmedWd = wd.trim();
      if (trimmedWd.isEmpty ||
          _unsafePathControlOrBidiRe.hasMatch(wd) ||
          _encodedWdUnsafeRe.hasMatch(wd) ||
          trimmedWd.startsWith('//') ||
          trimmedWd.startsWith(r'\\') ||
          trimmedWd.startsWith(r'\??\') ||
          _hasNtfsAdsStream(trimmedWd)) {
        return 'Directorio de trabajo inválido o ruta UNC bloqueada.';
      }
    }
    final env = cfg.environment;
    if (env != null) {
      for (final entry in env.entries) {
        final key = entry.key;
        if (key.isEmpty ||
            key.contains('=') ||
            _unsafePathControlOrBidiRe.hasMatch(key) ||
            entry.value.contains('\x00')) {
          return 'Variable de entorno inválida: "$key".';
        }
        final upperKey = key.toUpperCase();
        if (_isBlockedEnvKey(upperKey)) {
          return 'Variable de entorno bloqueada por seguridad: "$key".';
        }
      }
    }
    return null;
  }

  /// Builds a sanitized subprocess environment map so inherited parent
  /// variables (`DYLD_INSERT_LIBRARIES`, `LD_PRELOAD`, `BASH_ENV`, `NODE_OPTIONS`,
  /// `BASH_FUNC_*`, etc.) are stripped even when [ExecutionConfig.includeParentEnvironment]
  /// is `true`, while preserving safe lookup variables (`PATH`, `HOME`, `TMPDIR`).
  static Map<String, String> buildEffectiveEnvironment(
    ExecutionConfig cfg, {
    Map<String, String>? parentEnvironment,
  }) {
    final out = <String, String>{};
    void addSafeEntries(Map<String, String> src) {
      for (final entry in src.entries) {
        final key = entry.key;
        if (key.isEmpty ||
            key.contains('=') ||
            _unsafePathControlOrBidiRe.hasMatch(key) ||
            entry.value.contains('\x00')) {
          continue;
        }
        final upperKey = key.toUpperCase();
        if (_isBlockedEnvKey(upperKey)) {
          continue;
        }
        out[key] = entry.value;
      }
    }

    if (cfg.includeParentEnvironment) {
      addSafeEntries(parentEnvironment ?? Platform.environment);
    }
    if (cfg.environment != null) {
      addSafeEntries(cfg.environment!);
    }
    return out;
  }

  // ---- Instance methods ----

  /// Execute a command and wait for result.
  ///
  /// Uses [Process.start] instead of [Process.run] so timed-out child processes
  /// are actively terminated rather than left running as orphan background jobs,
  /// and caps buffered stdout/stderr at [ExecutionConfig.maxOutputBytes].
  Future<CliResult> execute(String command, {ExecutionConfig? config}) async {
    final cfg = config ?? defaultConfig;
    final validationError = validateExecutionInputs(command, config: cfg);
    if (validationError != null) {
      return CliResult(
        exitCode: -1,
        stdout: '',
        stderr: validationError,
        command: command,
        duration: Duration.zero,
        workingDirectory: cfg.workingDirectory,
      );
    }
    final stopwatch = Stopwatch()..start();
    Process? process;
    StreamSubscription<List<int>>? stdoutSub;
    StreamSubscription<List<int>>? stderrSub;

    final stdoutBytes = BytesBuilder(copy: false);
    final stderrBytes = BytesBuilder(copy: false);
    var stdoutTruncated = false;
    var stderrTruncated = false;

    try {
      final shell = Platform.isWindows ? 'cmd' : 'bash';
      final args = Platform.isWindows ? ['/c', command] : ['-c', command];

      final effectiveEnv = buildEffectiveEnvironment(cfg);
      process = await Process.start(
        shell,
        args,
        workingDirectory: cfg.workingDirectory,
        environment: effectiveEnv,
        includeParentEnvironment: false,
      );
      _activeProcess = process;

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      stdoutSub = process.stdout.listen(
        (chunk) {
          if (stdoutTruncated) return;
          final remaining = cfg.maxOutputBytes - stdoutBytes.length;
          if (chunk.length <= remaining) {
            stdoutBytes.add(chunk);
          } else {
            if (remaining > 0) stdoutBytes.add(chunk.sublist(0, remaining));
            stdoutTruncated = true;
          }
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (_) {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );

      stderrSub = process.stderr.listen(
        (chunk) {
          if (stderrTruncated) return;
          final remaining = cfg.maxOutputBytes - stderrBytes.length;
          if (chunk.length <= remaining) {
            stderrBytes.add(chunk);
          } else {
            if (remaining > 0) stderrBytes.add(chunk.sublist(0, remaining));
            stderrTruncated = true;
          }
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (_) {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

      final exitCode = await process.exitCode.timeout(cfg.timeout);
      await Future.wait([stdoutDone.future, stderrDone.future])
          .timeout(const Duration(seconds: 1), onTimeout: () => const []);

      stopwatch.stop();
      var outStr = _decodeSystemBytes(stdoutBytes.takeBytes()).trim();
      var errStr = _decodeSystemBytes(stderrBytes.takeBytes()).trim();
      if (stdoutTruncated) {
        outStr = '$outStr\n[TRUNCATED: output exceeded ${cfg.maxOutputBytes}B]';
      }
      if (stderrTruncated) {
        errStr = '$errStr\n[TRUNCATED: stderr exceeded ${cfg.maxOutputBytes}B]';
      }

      return CliResult(
        exitCode: exitCode,
        stdout: outStr,
        stderr: errStr,
        command: command,
        duration: stopwatch.elapsed,
        workingDirectory: cfg.workingDirectory,
      );
    } on TimeoutException {
      if (process != null) {
        await _terminateProcess(process);
      }
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
      if (process != null) {
        await _terminateProcess(process);
      }
      stopwatch.stop();
      return CliResult(
        exitCode: -1,
        stdout: '',
        stderr: redactCliDiagnostic(e.toString()),
        command: command,
        duration: stopwatch.elapsed,
        workingDirectory: cfg.workingDirectory,
      );
    } finally {
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  /// Spanish alias for [execute].
  Future<CliResult> ejecutarComando(String comando, {ExecutionConfig? config}) =>
      execute(comando, config: config);

  /// Execute a command and stream output in real-time (stdout + stderr merged).
  Stream<String> stream(String command, {ExecutionConfig? config}) async* {
    final cfg = config ?? defaultConfig;
    final validationError = validateExecutionInputs(command, config: cfg);
    if (validationError != null) {
      yield 'Error ejecutando el stream: $validationError';
      return;
    }
    try {
      final shell = Platform.isWindows ? 'cmd' : 'bash';
      final args = Platform.isWindows ? ['/c', command] : ['-c', command];

      final effectiveEnv = buildEffectiveEnvironment(cfg);
      final process = await Process.start(
        shell,
        args,
        workingDirectory: cfg.workingDirectory,
        environment: effectiveEnv,
        includeParentEnvironment: false,
      );
      _activeProcess = process;

      var exited = false;
      var rawReceivedBytes = 0;
      var emittedBytes = 0;
      var truncated = false;
      Timer? timeoutTimer;
      unawaited(process.exitCode.then((_) => exited = true));

      late final StreamSubscription<List<int>> stdoutSub;
      late final StreamSubscription<List<int>> stderrSub;

      final controller = StreamController<String>(
        onCancel: () async {
          timeoutTimer?.cancel();
          await stdoutSub.cancel();
          await stderrSub.cancel();
          if (!exited) {
            await _terminateProcess(process);
          }
          if (identical(_activeProcess, process)) {
            _activeProcess = null;
          }
        },
      );

      void triggerTruncation() {
        if (truncated || controller.isClosed) return;
        truncated = true;
        controller.add('[TRUNCATED: output exceeded ${cfg.maxOutputBytes}B]');
        timeoutTimer?.cancel();
        unawaited(() async {
          await stdoutSub.cancel();
          await stderrSub.cancel();
          if (!exited) {
            await _terminateProcess(process);
          }
          if (!controller.isClosed) {
            await controller.close();
          }
        }());
      }

      void addBoundedLine(String line) {
        if (controller.isClosed || truncated) return;
        final lineBytes = utf8.encode(line).length + 1;
        if (emittedBytes + lineBytes > cfg.maxOutputBytes) {
          triggerTruncation();
          return;
        }
        emittedBytes += lineBytes;
        controller.add(line);
      }

      timeoutTimer = Timer(cfg.timeout, () {
        if (controller.isClosed || truncated) return;
        controller.add(
          '[STDERR] TIMEOUT: Comando excedio ${cfg.timeout.inSeconds}s',
        );
        unawaited(() async {
          await stdoutSub.cancel();
          await stderrSub.cancel();
          if (!exited) {
            await _terminateProcess(process);
          }
          if (!controller.isClosed) {
            await controller.close();
          }
        }());
      });

      // Enforce [cfg.maxOutputBytes] on raw byte chunks BEFORE LineSplitter
      // so newline-free output floods cannot cause unbounded buffering / OOM.
      const decoder = Utf8Decoder(allowMalformed: true);
      final stdoutLineSink = const LineSplitter().startChunkedConversion(
        _LineCallbackSink(addBoundedLine),
      );
      final stdoutByteSink = decoder.startChunkedConversion(stdoutLineSink);

      final stderrLineSink = const LineSplitter().startChunkedConversion(
        _LineCallbackSink((line) => addBoundedLine('[STDERR] $line')),
      );
      final stderrByteSink = decoder.startChunkedConversion(stderrLineSink);

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      stdoutSub = process.stdout.listen(
        (chunk) {
          if (truncated || controller.isClosed) return;
          if (rawReceivedBytes + chunk.length > cfg.maxOutputBytes) {
            final remaining = cfg.maxOutputBytes - rawReceivedBytes;
            if (remaining > 0) {
              rawReceivedBytes += remaining;
              stdoutByteSink.add(chunk.sublist(0, remaining));
            }
            triggerTruncation();
            if (!stdoutDone.isCompleted) stdoutDone.complete();
            return;
          }
          rawReceivedBytes += chunk.length;
          stdoutByteSink.add(chunk);
        },
        onDone: () {
          if (!truncated && !controller.isClosed) {
            stdoutByteSink.close();
          }
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (_) {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );

      stderrSub = process.stderr.listen(
        (chunk) {
          if (truncated || controller.isClosed) return;
          if (rawReceivedBytes + chunk.length > cfg.maxOutputBytes) {
            final remaining = cfg.maxOutputBytes - rawReceivedBytes;
            if (remaining > 0) {
              rawReceivedBytes += remaining;
              stderrByteSink.add(chunk.sublist(0, remaining));
            }
            triggerTruncation();
            if (!stderrDone.isCompleted) stderrDone.complete();
            return;
          }
          rawReceivedBytes += chunk.length;
          stderrByteSink.add(chunk);
        },
        onDone: () {
          if (!truncated && !controller.isClosed) {
            stderrByteSink.close();
          }
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (_) {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

      unawaited(Future.wait([stdoutDone.future, stderrDone.future]).then(
        (_) async {
          timeoutTimer?.cancel();
          await stdoutSub.cancel();
          await stderrSub.cancel();
          if (!controller.isClosed) await controller.close();
        },
      ));

      yield* controller.stream;

      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    } catch (e) {
      yield 'Error ejecutando el stream: ${redactCliDiagnostic(e.toString())}';
    }
  }

  /// Spanish alias for [stream].
  Stream<String> ejecutarStream(String comando, {ExecutionConfig? config}) =>
      stream(comando, config: config);

  /// Kill the active streaming or running process safely across POSIX and Windows.
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    final proc = _activeProcess;
    if (proc == null) return false;
    bool killed = false;
    try {
      killed = Platform.isWindows ? proc.kill() : proc.kill(signal);
    } catch (_) {
      try {
        killed = proc.kill();
      } catch (_) {
        killed = false;
      }
    }
    if (killed) _activeProcess = null;
    return killed;
  }

  static String _decodeSystemBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return const SystemEncoding().decode(bytes);
    }
  }

  static Future<void> _terminateProcess(Process process) async {
    try {
      process.kill();
    } catch (_) {}
    if (!Platform.isWindows) {
      try {
        await process.exitCode.timeout(const Duration(milliseconds: 200));
        return;
      } catch (_) {
        try {
          process.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
  }
}

class _LineCallbackSink implements Sink<String> {
  final void Function(String) _onLine;

  const _LineCallbackSink(this._onLine);

  @override
  void add(String data) => _onLine(data);

  @override
  void close() {}
}
