import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:l/l.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';

import 'package:worklog_studio/data/sqlite/db_create.dart';

class DatabaseProvider {
  static const _dbName = 'worklog.db';
  static const _dbVersion = 3; // Incremented for app_settings table

  static Database? _db;
  static Future<Database>? _initFuture;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    try {
      _initFuture ??= _initDb();
      _db = await _initFuture;
      return _db!;
    } catch (e) {
      _initFuture = null;
      rethrow;
    } finally {
      _initFuture = null;
    }
  }

  /// Closes the active connection, releasing the OS-level file lock.
  /// Required before overwriting the DB file on disk (e.g. restoring a
  /// backup) — Windows refuses to replace a file that's still open.
  /// A later [getDatabase] call will lazily reopen a fresh connection.
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _initFuture = null;
  }

  /// Resolves the OS application-support directory, namespaced under the
  /// active [Flavor.appFolder] so dev and prod never share the same files.
  static Future<Directory> _resolveBaseDir() async {
    Directory osDir;
    try {
      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        osDir = await getApplicationSupportDirectory();
      } else {
        final fallbackPath = await getDatabasesPath();
        osDir = Directory(fallbackPath);
      }
    } catch (e) {
      l.w(
        'DatabaseProvider: Failed to get Application Support Directory. Error: $e',
      );
      final fallbackPath = await getDatabasesPath();
      osDir = Directory(fallbackPath);
    }

    final flavor = appEnvironment.config.flavor;
    final baseDir = Directory(join(osDir.path, flavor.appFolder));

    if (!kIsWeb && !await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return baseDir;
  }

  /// The live database file for the active flavor.
  static Future<File> getDbFile() async =>
      File(join((await _resolveBaseDir()).path, _dbName));

  /// Where backups for the active flavor's database are stored.
  static Future<Directory> getBackupsDir() async {
    final dir = Directory(join((await _resolveBaseDir()).path, 'backups'));
    if (!kIsWeb && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Database> _initDb() async {
    final flavor = appEnvironment.config.flavor;
    l.i(
      'DatabaseProvider: Bootstrapping DB for environment: ${flavor.appTitle}',
    );

    final dbFile = await getDbFile();
    final path = dbFile.path;
    l.i('DatabaseProvider: Final DB path: $path');

    final watch = Stopwatch()..start();

    Future<void> onCreateCallback(Database db, int version) async {
      l.i('DatabaseProvider: Creating database schema (v$version)...');
      await onCreate(db, version);
      l.i('DatabaseProvider: Database schema created successfully.');
    }

    Future<void> onUpgradeCallback(
      Database db,
      int oldVersion,
      int newVersion,
    ) async {
      l.i(
        'DatabaseProvider: Upgrading database from v$oldVersion to v$newVersion...',
      );
      await _onUpgrade(db, oldVersion, newVersion);
      l.i('DatabaseProvider: Database upgraded successfully.');
    }

    void onOpenCallback(Database db) {
      l.i(
        'DatabaseProvider: Database opened successfully in ${watch.elapsedMilliseconds}ms.',
      );
    }

    try {
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: onCreateCallback,
        onUpgrade: onUpgradeCallback,
        onOpen: onOpenCallback,
      );
    } catch (e, st) {
      l.e('DatabaseProvider: DB open failed, recreating...', st, {
        'error': e.toString(),
      });
      try {
        await deleteDatabase(path);
      } catch (deletionError) {
        l.e('DatabaseProvider: DB delete failed');
        l.e(deletionError);
      }
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: onCreateCallback,
        onUpgrade: onUpgradeCallback,
        onOpen: onOpenCallback,
      );
    }
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        '''CREATE UNIQUE INDEX IF NOT EXISTS idx_single_running_entry
           ON time_entries(status)
           WHERE status = 'running';''',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        ''');
    }
  }
}
