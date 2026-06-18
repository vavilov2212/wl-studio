import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/backup_service.dart';

import '../helpers/test_fakes.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late Directory backupsDir;
  late FakeBackupRepository repository;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test');
    dbFile = File('${tempDir.path}/worklog.db');
    backupsDir = Directory('${tempDir.path}/backups');
    repository = FakeBackupRepository();
    service = BackupService(
      repository: repository,
      dbFile: dbFile,
      backupsDir: backupsDir,
      keep: 3,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('backupOnStartup', () {
    test('returns null and does not call the repository when no DB file exists', () async {
      final result = await service.backupOnStartup();

      expect(result, isNull);
      expect(repository.createCalls, 0);
    });

    test('creates a backup and prunes when the DB file exists', () async {
      await dbFile.create(recursive: true);

      final result = await service.backupOnStartup();

      expect(result, isNotNull);
      expect(repository.createCalls, 1);
    });
  });

  group('createBackupNow', () {
    test('throws StateError when no DB file exists', () async {
      expect(() => service.createBackupNow(), throwsStateError);
    });

    test('creates a backup when the DB file exists', () async {
      await dbFile.create(recursive: true);

      final info = await service.createBackupNow();

      expect(info.file.path, contains('worklog_fake_1.db'));
      expect(repository.createCalls, 1);
    });

    test('prunes down to the configured keep count', () async {
      await dbFile.create(recursive: true);

      for (var i = 0; i < 5; i++) {
        await service.createBackupNow();
      }

      expect(repository.createCalls, 5);
      expect(repository.all.length, 3);
    });
  });

  group('listBackups', () {
    test('delegates to the repository', () async {
      await dbFile.create(recursive: true);
      await service.createBackupNow();

      final backups = await service.listBackups();

      expect(backups, hasLength(1));
    });
  });

  group('restore', () {
    test('delegates to the repository with the given backup and db file', () async {
      await dbFile.create(recursive: true);
      final info = await service.createBackupNow();

      await service.restore(info);

      expect(repository.restoredFrom, same(info));
    });
  });
}
