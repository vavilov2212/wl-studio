import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:worklog_studio/domain/backup.dart';

/// Concrete [BackupRepository] backed by plain file copies — no archive
/// format, just timestamped `.db` snapshots next to each other in
/// [Directory backupsDir].
class FileBackupRepository implements BackupRepository {
  static final RegExp _timestampPattern = RegExp(
    r'^worklog_(\d{8}_\d{6})\.db$',
  );

  @override
  Future<BackupInfo> createBackup({
    required File dbFile,
    required Directory backupsDir,
  }) async {
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp = _formatStamp(now);
    final destination = File(p.join(backupsDir.path, 'worklog_$stamp.db'));

    await dbFile.copy(destination.path);

    return BackupInfo(file: destination, createdAt: now);
  }

  @override
  Future<List<BackupInfo>> listBackups(Directory backupsDir) async {
    if (!await backupsDir.exists()) return const [];

    final backups = <BackupInfo>[];
    for (final entity in await backupsDir.list().toList()) {
      if (entity is! File) continue;
      final match = _timestampPattern.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      backups.add(
        BackupInfo(file: entity, createdAt: _parseStamp(match.group(1)!)),
      );
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  @override
  Future<void> restoreBackup({
    required BackupInfo backup,
    required File dbFile,
  }) async {
    await backup.file.copy(dbFile.path);
  }

  @override
  Future<void> pruneBackups(Directory backupsDir, {required int keep}) async {
    final backups = await listBackups(backupsDir);
    if (backups.length <= keep) return;

    for (final stale in backups.skip(keep)) {
      if (await stale.file.exists()) {
        await stale.file.delete();
      }
    }
  }

  String _formatStamp(DateTime time) {
    String pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
    return '${time.year}${pad(time.month)}${pad(time.day)}'
        '_${pad(time.hour)}${pad(time.minute)}${pad(time.second)}';
  }

  DateTime _parseStamp(String stamp) {
    final datePart = stamp.substring(0, 8);
    final timePart = stamp.substring(9);
    return DateTime(
      int.parse(datePart.substring(0, 4)),
      int.parse(datePart.substring(4, 6)),
      int.parse(datePart.substring(6, 8)),
      int.parse(timePart.substring(0, 2)),
      int.parse(timePart.substring(2, 4)),
      int.parse(timePart.substring(4, 6)),
    );
  }
}
