import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:l/l.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/environment/dotenv.dart';
import 'package:worklog_studio/core/services/crash_logger.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/entity/session/data/repository/session_storage_repository.dart';
import 'package:worklog_studio/entity/user/data/repository/user_repository.dart';
import 'package:worklog_studio/feature/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_service.dart';
import 'package:worklog_studio/firebase_options.dart';
import 'package:worklog_studio_style_system/ui_kit/ui_kit.dart';

import 'package:worklog_studio/data/sqlite/database_provider.dart';
import 'package:worklog_studio/data/backup/file_backup_repository.dart';
import 'package:worklog_studio/core/services/backup_service.dart';

import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/idle_monitor/no_op_idle_monitor.dart';
import 'package:worklog_studio/core/services/idle_monitor/platform_idle_monitor.dart';

Future<void> run(List<String> args) async {
  // Set up the Flutter framework error hook before binding initialisation so
  // framework-level errors are also captured by the crash logger.
  FlutterError.onError = (details) {
    logCrash(details.exception, details.stack ?? StackTrace.empty);
  };

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase already initialized: $e');
    }

    // 🔑 ВАЖНО: для desktop / VM
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    if (kIsWeb) {
      usePathUrlStrategy();
    }

    await _initDependencies();
    _initRepositories();

    DesktopServiceRegistry.init();

    // Follower engines (miniPanel, activity) share the same OS process as the
    // leader but must not open SQLite or run backup: three engines opening the
    // same DB file simultaneously risks lock contention, and copying the DB
    // from a follower races the leader's active writes.
    final isFollower = args.firstOrNull == 'multi_window';
    if (!isFollower) {
      try {
        if (!kIsWeb) {
          getIt<UserRepository>();
          await _initBackupService();
          await DatabaseProvider.getDatabase();
        }
      } catch (e, st) {
        l.e('Failed to bootstrap DB on startup', st);
      }
    }

    final role = await DesktopServiceRegistry.instance.resolveStartupRole(args);
    debugPrint('Successfully resolved engine role: $role');
    debugPrint('runApp starting with role: $role');

    if (role == 'tray') {
      runApp(const MiniApp());
    } else {
      runApp(const MainApp());
    }
  }, (error, stack) => logCrash(error, stack));
}

Future<void> _initDependencies() async {
  _initDotEnv();
  await configureDependencies();
}

/// Registers [BackupService] and snapshots the previous session's DB file
/// (if any) before [DatabaseProvider] opens a fresh connection to it.
Future<void> _initBackupService() async {
  final backupService = BackupService(
    repository: FileBackupRepository(),
    dbFile: await DatabaseProvider.getDbFile(),
    backupsDir: await DatabaseProvider.getBackupsDir(),
  );
  getIt.registerSingleton<BackupService>(backupService);
  await backupService.backupOnStartup();
}

void _initRepositories() {
  try {
    getIt.registerSingleton<SessionStorageRepository>(
      SessionStorageRepository(),
    );
    getIt.registerLazySingleton<UserRepository>(
      () => UserRepository(getIt<SessionStorageRepository>()),
    );

    getIt.registerSingleton(AppBarService());
    getIt.registerSingleton<DrawerService>(DrawerService());

    // Register IdleMonitor - only macOS has a native channel implementation.
    // Windows/Linux/web get a silent no-op so start/stop calls are safe.
    getIt.registerLazySingleton<IdleMonitor>(
      () => (!kIsWeb && Platform.isMacOS)
          ? PlatformIdleMonitor()
          : const NoOpIdleMonitor(),
    );
  } on Object catch (e, stackTrace) {
    l.e(e, stackTrace);
    rethrow;
  }
}

void _initDotEnv() {
  final config = appEnvironment.config;
  appEnvironment.config = config.copyWith(
    url: DotEnv.apiHost,
    jwtSecret: DotEnv.jwtSecret,
  );
}
