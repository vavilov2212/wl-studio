import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/crash_logger.dart';

void main() {
  group('logCrash', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crash_logger_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('writes the error message and a separator to the log file', () async {
      final logPath = '${tempDir.path}/crash.log';
      final error = Exception('something went wrong');

      await logCrash(error, StackTrace.current, overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      expect(content, contains('something went wrong'));
      expect(content, contains('---'));
    });

    test('includes an ISO-8601 timestamp in each entry', () async {
      final logPath = '${tempDir.path}/crash.log';

      await logCrash(Exception('ts test'), StackTrace.current,
          overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      expect(content, matches(RegExp(r'\d{4}-\d{2}-\d{2}T')));
    });

    test('appends successive crashes rather than overwriting', () async {
      final logPath = '${tempDir.path}/crash.log';

      await logCrash(Exception('first'), StackTrace.current,
          overrideLogPath: logPath);
      await logCrash(Exception('second'), StackTrace.current,
          overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      expect(content, contains('first'));
      expect(content, contains('second'));
    });

    test('creates parent directories if they do not exist', () async {
      final logPath = '${tempDir.path}/nested/dir/crash.log';

      await logCrash(Exception('nested'), StackTrace.current,
          overrideLogPath: logPath);

      expect(File(logPath).existsSync(), isTrue);
    });
  });
}
