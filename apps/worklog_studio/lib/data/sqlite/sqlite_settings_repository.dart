import 'package:sqflite/sqflite.dart';
import 'package:worklog_studio/data/sqlite/database_provider.dart';

/// Key-value settings persistence backed by the `app_settings` SQLite table.
///
/// Accepts an optional [database] override so tests can supply an in-memory
/// connection instead of the real [DatabaseProvider] singleton.
class SqliteSettingsRepository {
  final Future<Database> Function() _dbProvider;

  SqliteSettingsRepository({Database? database})
      : _dbProvider = database != null
            ? (() async => database)
            : DatabaseProvider.getDatabase;

  Future<String?> getString(String key) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setString(String key, String value) async {
    final db = await _dbProvider();
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getInt(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> setInt(String key, int value) =>
      setString(key, value.toString());
}
