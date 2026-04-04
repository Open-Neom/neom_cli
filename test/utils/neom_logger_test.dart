import 'package:neom_cli/src/domain/log_entry.dart';
import 'package:neom_cli/src/utils/neom_logger.dart';
import 'package:test/test.dart';

void main() {
  group('NeomLogger', () {
    test('filters by minimum level', () {
      final logger = NeomLogger(minLevel: LogLevel.warning);

      logger.debug('should be filtered');
      logger.info('should be filtered');
      logger.warning('should appear');
      logger.error('should appear');

      expect(logger.history.length, equals(2));
      expect(logger.history[0].level, equals(LogLevel.warning));
      expect(logger.history[1].level, equals(LogLevel.error));
    });

    test('startTask/endTask tracked in history', () {
      final logger = NeomLogger();

      logger.startTask('Test Task');
      logger.endTask('Test Task');

      expect(logger.history.length, equals(2));
      expect(logger.history[0].message, contains('Iniciando'));
      expect(logger.history[1].message, contains('Finalizado'));
    });

    test('log alias uses info level', () {
      final logger = NeomLogger();
      logger.log('test message');

      expect(logger.history.length, equals(1));
      expect(logger.history[0].level, equals(LogLevel.info));
      expect(logger.history[0].tag, equals('NEOM_OPS'));
    });

    test('history is unmodifiable', () {
      final logger = NeomLogger();
      logger.info('test');

      expect(() => logger.history.add(
        LogEntry(level: LogLevel.debug, message: 'hack'),
      ), throwsUnsupportedError);
    });
  });
}
