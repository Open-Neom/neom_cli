import 'dart:async';

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

/// Stub implementation for platforms without dart:io (web).
class CliExecutor {
  final ExecutionConfig defaultConfig;

  CliExecutor({ExecutionConfig? config})
      : defaultConfig = config ?? const ExecutionConfig();

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
    'NODE_EXTRA_CA_CERTS',
    'ELECTRON_RUN_AS_NODE',
    'PYTHONPATH',
    'PYTHONSTARTUP',
    'PERL5OPT',
    'RUBYOPT',
    'JAVA_TOOL_OPTIONS',
    '_JAVA_OPTIONS',
    'DOTNET_STARTUP_HOOKS',
    'OPENSSL_CONF',
    'OPENSSL_ENGINES',
    'SSL_CERT_FILE',
    'SSL_CERT_DIR',
    'CURL_CA_BUNDLE',
    'REQUESTS_CA_BUNDLE',
    'GIT_SSH',
    'GIT_SSH_COMMAND',
    'GIT_EXEC_PATH',
    'GIT_CONFIG_PARAMETERS',
    'GIT_CONFIG_COUNT',
    'GIT_CONFIG_GLOBAL',
    'GIT_CONFIG_SYSTEM',
    'GIT_EXTERNAL_DIFF',
    'GIT_ASKPASS',
    'SSH_ASKPASS',
  };

  static bool _isBlockedEnvKey(String upperKey) =>
      blockedEnvironmentKeys.contains(upperKey) ||
      upperKey.startsWith('DYLD_') ||
      upperKey.startsWith('LD_') ||
      upperKey.startsWith('BASH_FUNC_') ||
      upperKey.startsWith('GIT_CONFIG_KEY_') ||
      upperKey.startsWith('GIT_CONFIG_VALUE_');

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
          wd.toLowerCase().contains('%00') ||
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

    if (cfg.includeParentEnvironment && parentEnvironment != null) {
      addSafeEntries(parentEnvironment);
    }
    if (cfg.environment != null) {
      addSafeEntries(cfg.environment!);
    }
    return out;
  }

  static Future<CliResult> run(
    String command, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Map<String, String>? environment,
  }) async {
    final err = validateExecutionInputs(
      command,
      config: ExecutionConfig(
        workingDirectory: workingDirectory,
        timeout: timeout,
        environment: environment,
      ),
    );
    if (err != null) {
      return CliResult(
        exitCode: -1,
        stdout: '',
        stderr: err,
        command: command,
      );
    }
    return CliResult(
      exitCode: -1,
      stdout: '',
      stderr: 'Shell no disponible en esta plataforma',
      command: command,
    );
  }

  Future<CliResult> execute(String command, {ExecutionConfig? config}) async {
    final err = validateExecutionInputs(command, config: config ?? defaultConfig);
    if (err != null) {
      return CliResult(
        exitCode: -1,
        stdout: '',
        stderr: err,
        command: command,
      );
    }
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
    final err = validateExecutionInputs(command, config: config ?? defaultConfig);
    if (err != null) {
      yield 'Error ejecutando el stream: $err';
      return;
    }
    yield 'Shell no disponible en esta plataforma';
  }

  Stream<String> ejecutarStream(String comando, {ExecutionConfig? config}) =>
      stream(comando, config: config);

  bool kill([dynamic signal]) => false;
}
