import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> onCreate(Database db, int version) async {
  await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        archived_at INTEGER NULL
      );
    ''');

  await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER NULL
      );
    ''');

  await db.execute('''
      CREATE TABLE time_entries (
        id TEXT PRIMARY KEY,
        project_id TEXT NULL,
        task_id TEXT NULL,
        comment TEXT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER NULL,
        status TEXT NOT NULL
      );
    ''');

  await db.execute(
    'CREATE INDEX idx_time_entries_status ON time_entries(status);',
  );
  await db.execute(
    'CREATE INDEX idx_time_entries_start_at ON time_entries(start_at);',
  );
  await db.execute(
    '''CREATE UNIQUE INDEX IF NOT EXISTS idx_single_running_entry
         ON time_entries(status)
         WHERE status = 'running';''',
  );

  await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
}
