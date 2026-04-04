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

    final config = ExecutionConfig(
      workingDirectory: argResults?['dir'] as String?,
      timeout: Duration(seconds: int.parse(argResults!['timeout'] as String)),
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
        print(result.toJson());
      } else {
        if (result.hasOutput) print(result.stdout);
        if (result.hasError) logger.error(result.stderr);
        if (!result.isSuccess) logger.warning('Exit code: ${result.exitCode}');
      }
    }
  }
}
