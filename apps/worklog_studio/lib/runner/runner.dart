import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:l/l.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/environment/dotenv.dart';
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

  // Initialise the desktop service singleton once — platform resolved inside
  // the factory, no inline Platform.isXxx checks needed here.
  DesktopServiceRegistry.init();

  try {
    if (!kIsWeb) {
      await getIt<UserRepository>();
      await DatabaseProvider.getDatabase();
    }
  } catch (e, st) {
    l.e('Failed to bootstrap DB on startup', st);
  }

  // Role detection is now owned by the platform service itself.
  final role = await DesktopServiceRegistry.instance.resolveStartupRole();
  debugPrint('Successfully resolved engine role: $role');

  final isPopover = role == 'tray';
  debugPrint('runApp starting with role: $role');

  if (isPopover) {
    runApp(const MiniApp());
  } else {
    runApp(const MainApp());
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
