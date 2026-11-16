import 'dart:convert';

import 'package:args/command_runner.dart';

import '../core/cli_executor.dart';
import '../utils/neom_logger.dart';

class ExecCommand extends Command<void> {
  @override
  String get name => 'exec';

  @override
  String get description => 'Ejecuta un comando en la terminal local.';

  @override
  String get invocation => '${runner!.executableName} exec <comando>';

  ExecCommand() {
    argParser
      ..addOption('dir', abbr: 'd', help: 'Directorio de trabajo')
      ..addOption('timeout', abbr: 't', help: 'Timeout en segundos', defaultsTo: '30')
      ..addFlag('stream', abbr: 's', help: 'Modo streaming (salida en tiempo real)');
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Falta el comando a ejecutar.');
    }

    final command = argResults!.rest.join(' ');
    final isJson = globalResults?['json'] == true;
    final logger = NeomLogger(
      jsonOutput: isJson,
      useEmoji: globalResults?['no-color'] != true,
    );

    final rawTimeout = argResults!['timeout'] as String;
    final parsedTimeout = int.tryParse(rawTimeout.trim());
    if (parsedTimeout == null || parsedTimeout < 1 || parsedTimeout > 3600) {
      usageException(
        'Timeout inválido "$rawTimeout" (debe ser un entero entre 1 y 3600 segundos).',
      );
    }

    final config = ExecutionConfig(
      workingDirectory: argResults?['dir'] as String?,
      timeout: Duration(seconds: parsedTimeout),
    );

    final executor = CliExecutor(config: config);

    if (argResults!['stream'] == true) {
      await for (final line in executor.stream(command, config: config)) {
        print(line);
      }
    } else {
      logger.startTask('exec');
      final result = await executor.execute(command, config: config);
      logger.endTask('exec');

      if (isJson) {
        print(jsonEncode(result.toJson()));
      } else {
        if (result.hasOutput) print(result.stdout);
        if (result.hasError) logger.error(result.stderr);
        if (!result.isSuccess) logger.warning('Exit code: ${result.exitCode}');
      }
    }
  }
}
