import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/data/backup/file_backup_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late Directory backupsDir;
  late FileBackupRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'file_backup_repository_test',
    );
    dbFile = File('${tempDir.path}/worklog.db')
      ..writeAsStringSync('initial-content');
    backupsDir = Directory('${tempDir.path}/backups');
    repository = FileBackupRepository();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('createBackup copies the DB file content into backupsDir', () async {
    final info = await repository.createBackup(
      dbFile: dbFile,
      backupsDir: backupsDir,
    );

    expect(await info.file.exists(), isTrue);
    expect(await info.file.readAsString(), 'initial-content');
  });

  test('listBackups returns snapshots sorted most-recent-first', () async {
    final first = await repository.createBackup(
      dbFile: dbFile,
      backupsDir: backupsDir,
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    final second = await repository.createBackup(
      dbFile: dbFile,
      backupsDir: backupsDir,
    );

    final backups = await repository.listBackups(backupsDir);

    expect(backups.map((b) => b.fileName), [
      second.file.uri.pathSegments.last,
      first.file.uri.pathSegments.last,
    ]);
  });

  test('listBackups ignores files that do not match the backup naming pattern', () async {
    await backupsDir.create(recursive: true);
    await File('${backupsDir.path}/not_a_backup.txt').writeAsString('noise');

    final backups = await repository.listBackups(backupsDir);

    expect(backups, isEmpty);
  });

  test('pruneBackups deletes everything beyond the keep count', () async {
    for (var i = 0; i < 5; i++) {
      await repository.createBackup(dbFile: dbFile, backupsDir: backupsDir);
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    await repository.pruneBackups(backupsDir, keep: 2);

    final remaining = await repository.listBackups(backupsDir);
    expect(remaining, hasLength(2));
  });

  test('restoreBackup overwrites the DB file with the backup content', () async {
    final info = await repository.createBackup(
      dbFile: dbFile,
      backupsDir: backupsDir,
    );
    await dbFile.writeAsString('overwritten-after-backup');

    await repository.restoreBackup(backup: info, dbFile: dbFile);

    expect(await dbFile.readAsString(), 'initial-content');
  });
}
