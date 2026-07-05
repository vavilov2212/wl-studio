import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worklog_studio/data/sqlite/db_create.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';

void main() {
  late SqliteSettingsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: onCreate),
    );
    repository = SqliteSettingsRepository(database: db);
  });

  group('SqliteSettingsRepository', () {
    test('getString returns null when the key is absent', () async {
      expect(await repository.getString('missing_key'), isNull);
    });

    test('setString then getString round-trips the value', () async {
      await repository.setString('toggle_hotkey', '{"key":"keyM"}');

      expect(await repository.getString('toggle_hotkey'), '{"key":"keyM"}');
    });

    test('setString overwrites an existing value for the same key', () async {
      await repository.setString('reminder_interval_minutes', '5');
      await repository.setString('reminder_interval_minutes', '10');

      expect(await repository.getString('reminder_interval_minutes'), '10');
    });

    test('getInt/setInt round-trip through the same string column', () async {
      await repository.setInt('reminder_interval_minutes', 5);

      expect(await repository.getInt('reminder_interval_minutes'), 5);
    });

    test('getInt returns null when the key is absent', () async {
      expect(await repository.getInt('missing_key'), isNull);
    });
  });
}
