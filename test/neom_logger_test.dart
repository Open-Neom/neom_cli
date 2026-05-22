import 'package:neom_cli/src/domain/log_entry.dart';
import 'package:neom_cli/src/utils/neom_logger.dart';
import 'package:test/test.dart';

void main() {
  group('NeomLogger min-level filtering', () {
    test('entries below minLevel are dropped', () {
      final l = NeomLogger(minLevel: LogLevel.warning);
      l.debug('noise');
      l.info('info');
      l.warning('warn');
      l.error('err');
      expect(l.history.map((e) => e.level).toList(),
          [LogLevel.warning, LogLevel.error]);
    });

    test('minLevel debug logs everything', () {
      final l = NeomLogger(minLevel: LogLevel.debug);
      l.debug('a');
      l.info('b');
      l.warning('c');
      l.error('d');
      l.fatal('e');
      expect(l.history.length, 5);
    });
  });

  group('NeomLogger history', () {
    test('history is unmodifiable', () {
      final l = NeomLogger();
      l.info('hi');
      expect(() => l.history.add(LogEntry(level: LogLevel.info, message: 'x')),
          throwsUnsupportedError);
    });

    test('entries preserve tags', () {
      final l = NeomLogger();
      l.info('m', tag: 'MY_TAG');
      expect(l.history.single.tag, 'MY_TAG');
    });

    test('Spanish alias log() uses NEOM_OPS tag and info level', () {
      final l = NeomLogger();
      l.log('hola');
      expect(l.history.single.level, LogLevel.info);
      expect(l.history.single.tag, 'NEOM_OPS');
    });
  });

  group('NeomLogger task stopwatch', () {
    test('startTask/endTask creates two entries', () {
      final l = NeomLogger();
      l.startTask('X');
      l.endTask('X');
      expect(l.history.length, 2);
      expect(l.history[0].message, contains('Iniciando: X'));
      expect(l.history[1].message, contains('Finalizado: X'));
    });
  });
}
