import 'dart:io';

import 'package:worklog_studio/domain/backup.dart';

/// Coordinates DB backup/restore around a [BackupRepository], enforcing the
/// app-level policy: rotate to the last [keep] backups after every snapshot.
class BackupService {
  final BackupRepository repository;
  final File dbFile;
  final Directory backupsDir;
  final int keep;

  BackupService({
    required this.repository,
    required this.dbFile,
    required this.backupsDir,
    this.keep = 10,
  });

  /// Snapshots the current DB file, if one exists yet, and prunes old
  /// backups down to [keep]. Safe to call before the DB connection is
  /// opened — copying a closed file avoids partial/inconsistent snapshots.
  /// Returns `null` when there is nothing to back up yet (first run).
  Future<BackupInfo?> backupOnStartup() async {
    if (!await dbFile.exists()) return null;
    return _createAndPrune();
  }

  /// Same as [backupOnStartup] but throws if there is no DB file to back up
  /// — used for the manual "Backup now" action, where a missing file is a
  /// real error rather than an expected first-run state.
  Future<BackupInfo> createBackupNow() async {
    if (!await dbFile.exists()) {
      throw StateError('Database file not found at ${dbFile.path}');
    }
    return _createAndPrune();
  }

  Future<List<BackupInfo>> listBackups() => repository.listBackups(backupsDir);

  Future<void> restore(BackupInfo backup) =>
      repository.restoreBackup(backup: backup, dbFile: dbFile);

  Future<BackupInfo> _createAndPrune() async {
    final info = await repository.createBackup(
      dbFile: dbFile,
      backupsDir: backupsDir,
    );
    await repository.pruneBackups(backupsDir, keep: keep);
    return info;
  }
}
