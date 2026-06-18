import 'dart:io';

/// Metadata for a single backup snapshot of the SQLite database file.
class BackupInfo {
  final File file;
  final DateTime createdAt;

  const BackupInfo({required this.file, required this.createdAt});

  String get fileName => file.uri.pathSegments.last;
}

/// Abstracts the raw file operations needed to snapshot and restore the
/// local database file. Kept as an interface so [BackupService] can be
/// tested without touching the real file system.
abstract class BackupRepository {
  Future<BackupInfo> createBackup({
    required File dbFile,
    required Directory backupsDir,
  });

  Future<List<BackupInfo>> listBackups(Directory backupsDir);

  Future<void> restoreBackup({required BackupInfo backup, required File dbFile});

  Future<void> pruneBackups(Directory backupsDir, {required int keep});
}
