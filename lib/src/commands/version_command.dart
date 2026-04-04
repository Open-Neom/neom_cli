import 'package:args/command_runner.dart';

const String neomCliVersion = '1.0.0';

class VersionCommand extends Command<void> {
  @override
  String get name => 'version';

  @override
  String get description => 'Show neom_cli version.';

  @override
  void run() {
    print('neom_cli v$neomCliVersion');
  }
}
