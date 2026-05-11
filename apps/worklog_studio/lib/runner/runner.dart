import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:l/l.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/environment/dotenv.dart';
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

import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/idle_monitor/platform_idle_monitor.dart';

Future<void> run(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }

  // 🔑 ВАЖНО: для desktop / VM
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
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

  try {
    if (!kIsWeb) {
      await getIt<
        UserRepository
      >(); // Forces initial cascade if necessary, but importantly...
      // We explicitly bootstrap the database here manually to ensure it's ready before UI
      await DatabaseProvider.getDatabase();
    }
  } catch (e, st) {
    l.e('Failed to bootstrap DB on startup', st);
  }

  String? initialRoute;
  bool isPopover = false;
  if (Platform.isMacOS) {
    try {
      const channel = MethodChannel('worklog_studio/ipc');
      final engineInfo = await channel
          .invokeMapMethod<String, dynamic>('getEngineInfo')
          .timeout(
            const Duration(seconds: 1),
            onTimeout: () {
              debugPrint('getEngineInfo timed out!');
              return {'role': 'main'}; // default fallback
            },
          );

      final role = engineInfo?['role'] as String? ?? 'main';
      debugPrint('Successfully resolved engine role: $role');

      if (role == 'tray') {
        initialRoute = '/mini';
        isPopover = true;
      }
    } catch (e) {
      debugPrint('Failed to fetch engine info: $e');
    }
  }

  debugPrint('runApp starting with initialRoute: $initialRoute');
  if (isPopover) {
    runApp(const MiniApp());
  } else {
    runApp(MainApp(initialRoute: initialRoute));
  }
}

Future<void> _initDependencies() async {
  _initDotEnv();
  await configureDependencies();
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

    // Register PlatformIdleMonitor
    getIt.registerLazySingleton<IdleMonitor>(() => PlatformIdleMonitor());
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
