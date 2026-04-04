import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:neom_cli/src/commands/exec_command.dart';
import 'package:neom_cli/src/commands/version_command.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'neom',
    'NEOM CLI - Shell execution engine for Open Neom Desktop.',
  )
    ..addCommand(ExecCommand())
    ..addCommand(VersionCommand())
    ..argParser.addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..argParser.addFlag('no-color', help: 'Disable emoji and formatting')
    ..argParser.addFlag('json', help: 'JSON output format');

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  } catch (e) {
    print('CLI execution failed: $e');
    exit(1);
  }
}
