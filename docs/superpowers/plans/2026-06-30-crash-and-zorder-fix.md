# Crash Fix + Window Z-Order Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the app from silently crashing on button presses and ensure both the mini panel and activity windows reliably appear on top of other windows.

**Architecture:** Three changes across three files. The runner gets a global error zone and a follower-detection guard that prevents follower engines from opening SQLite. `ManagedPopoverWindow` gets an HWND cache so z-order calls never miss on first show. The mini panel gets the `alwaysOnTop` flag it was missing.

**Tech Stack:** Flutter (Dart), win32 FFI, `desktop_multi_window` plugin, `flutter_bloc`, `l` (logging package)

## Global Constraints

- Windows only - never add `Platform.isMacOS` / `Platform.isLinux` checks inside the files touched here
- Always use `fvm flutter test test/core/ test/feature/ --reporter expanded` to run tests (from `apps\worklog_studio\`)
- Never run `flutter` directly - always prefix with `fvm`
- No `Co-Authored-By` trailer in commit messages
- No em dash or en dash in any text (use plain hyphen or comma)
- Exclude `*.g.dart`, `*.freezed.dart`, `.dart_tool\`, `build\` from all reads/searches
- TDD is mandatory: write the failing test before any implementation code

---

### Task 1: Extract crash logger and add global error zone to runner

**Files:**
- Create: `apps/worklog_studio/lib/core/services/crash_logger.dart`
- Create: `apps/worklog_studio/test/core/crash_logger_test.dart`
- Modify: `apps/worklog_studio/lib/runner/runner.dart`

**Interfaces:**
- Produces: `Future<void> logCrash(Object error, StackTrace stack, {String? overrideLogPath})` - imported by `runner.dart`

- [ ] **Step 1: Write the failing tests**

Create `apps/worklog_studio/test/core/crash_logger_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/crash_logger.dart';

void main() {
  group('logCrash', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crash_logger_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('writes the error message and a separator to the log file', () async {
      final logPath = '${tempDir.path}/crash.log';
      final error = Exception('something went wrong');

      await logCrash(error, StackTrace.current, overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      expect(content, contains('something went wrong'));
      expect(content, contains('---'));
    });

    test('includes an ISO-8601 timestamp in each entry', () async {
      final logPath = '${tempDir.path}/crash.log';

      await logCrash(Exception('ts test'), StackTrace.current,
          overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      // ISO-8601 timestamps start with the 4-digit year.
      expect(content, matches(RegExp(r'\d{4}-\d{2}-\d{2}T')));
    });

    test('appends successive crashes rather than overwriting', () async {
      final logPath = '${tempDir.path}/crash.log';

      await logCrash(Exception('first'), StackTrace.current,
          overrideLogPath: logPath);
      await logCrash(Exception('second'), StackTrace.current,
          overrideLogPath: logPath);

      final content = await File(logPath).readAsString();
      expect(content, contains('first'));
      expect(content, contains('second'));
    });

    test('creates parent directories if they do not exist', () async {
      final logPath = '${tempDir.path}/nested/dir/crash.log';

      await logCrash(Exception('nested'), StackTrace.current,
          overrideLogPath: logPath);

      expect(File(logPath).existsSync(), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests - verify they fail**

```
cd apps\worklog_studio
fvm flutter test test/core/crash_logger_test.dart --reporter expanded
```

Expected: compile error - `crash_logger.dart` does not exist yet.

- [ ] **Step 3: Create `crash_logger.dart`**

Create `apps/worklog_studio/lib/core/services/crash_logger.dart`:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:l/l.dart';

/// Appends a timestamped crash entry to the persistent log file and also
/// routes it through the existing [l] logger for debug-mode visibility.
/// Swallows any I/O exception so a logging failure can never itself crash
/// the app. On non-Windows / non-desktop platforms (web, macOS, Linux) the
/// file write is skipped - only [l.e] runs.
///
/// [overrideLogPath] is a test seam - pass a temp-directory path in tests
/// to avoid touching LOCALAPPDATA.
Future<void> logCrash(
  Object error,
  StackTrace stack, {
  String? overrideLogPath,
}) async {
  l.e('Uncaught error: $error', stack);
  if (kIsWeb) return;
  try {
    final path = overrideLogPath ?? _defaultLogPath();
    if (path == null) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    final entry =
        '[${DateTime.now().toIso8601String()}]\n$error\n$stack\n---\n';
    await file.writeAsString(entry, mode: FileMode.append);
  } catch (_) {}
}

String? _defaultLogPath() {
  final appData = Platform.environment['LOCALAPPDATA'];
  if (appData == null) return null;
  return '$appData\\WorklogStudio\\crash.log';
}
```

- [ ] **Step 4: Run tests - verify they pass**

```
cd apps\worklog_studio
fvm flutter test test/core/crash_logger_test.dart --reporter expanded
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Wire `runZonedGuarded` and the follower DB guard into runner.dart**

Open `apps/worklog_studio/lib/runner/runner.dart`. Replace the entire file with the following (preserving all existing imports, adding the `crash_logger` import):

```dart
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
  // framework-level errors (assertion failures, layout overflows promoted to
  // errors in release mode, etc.) are also captured.
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
          await getIt<UserRepository>();
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

    if (role == 'tray:activity') {
      runApp(const ActivityPromptApp());
    } else if (role == 'tray') {
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
```

- [ ] **Step 6: Run the full test suite to confirm nothing broke**

```
cd apps\worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all existing tests PASS plus the 4 new crash_logger tests.

- [ ] **Step 7: Commit**

```
git add apps/worklog_studio/lib/core/services/crash_logger.dart
git add apps/worklog_studio/test/core/crash_logger_test.dart
git add apps/worklog_studio/lib/runner/runner.dart
git commit -m "fix: add global error zone and isolate DB init to leader engine only"
```

---

### Task 2: Cache HWND in ManagedPopoverWindow

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart`
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`

**Interfaces:**
- Consumes: `ManagedPopoverWindow` as constructed by `WindowsDesktopService` (unchanged public API)
- Produces: `int? cachedHwndForTesting` getter and `void setCachedHwndForTesting(int?)` setter (test seams only)

- [ ] **Step 1: Write the failing tests**

Open `apps/worklog_studio/test/core/windows_desktop_service_test.dart`. Add a new group after the existing groups:

```dart
  group('ManagedPopoverWindow HWND cache', () {
    test('cachedHwnd starts as null', () {
      final service = WindowsDesktopService();
      expect(service.activityWindowForTesting.cachedHwndForTesting, isNull);
    });

    test('cachedHwnd is cleared when setCachedHwndForTesting sets it then reconcile-like reset occurs', () {
      final service = WindowsDesktopService();
      final window = service.activityWindowForTesting;

      // Simulate a cached HWND having been populated (as happens after a
      // successful FindWindow call on first show).
      window.setCachedHwndForTesting(12345);
      expect(window.cachedHwndForTesting, 12345);

      // Simulate the reset path that reconcile() takes when it detects the
      // native window has been destroyed.
      window.resetWindowStateForTesting();
      expect(window.cachedHwndForTesting, isNull);
      expect(window.windowId, isNull);
      expect(window.isVisible, isFalse);
    });
  });
```

- [ ] **Step 2: Run tests - verify they fail**

```
cd apps\worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart --reporter expanded
```

Expected: compile errors - `cachedHwndForTesting`, `setCachedHwndForTesting`, `resetWindowStateForTesting` do not exist yet.

- [ ] **Step 3: Add HWND cache and test seams to `ManagedPopoverWindow`**

Open `apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart`.

After the existing `bool followerReady = false;` field (line 59), add:

```dart
  /// Cached result of the first successful `FindWindow` call for this window.
  /// Cleared whenever [windowId] is reset (i.e. the native window has been
  /// destroyed and a new one will be created on next [show]). This avoids the
  /// race between [WindowController.setTitle] returning and Win32 actually
  /// registering the new title - the HWND resolved during [show]'s initial
  /// `ShowWindow` call is reused immediately by [_applyAlwaysOnTop] and
  /// [_applyFrameless] without a second `FindWindow` round-trip.
  int? _cachedHwnd;
```

Replace the existing `_nativeHandle()` method with:

```dart
  int? _nativeHandle() {
    if (_cachedHwnd != null) return _cachedHwnd;
    final titlePtr = _nativeTitle.toNativeUtf16();
    try {
      final hwnd = win32.FindWindow(nullptr, titlePtr);
      if (hwnd == 0) {
        debugPrint(
          'ManagedPopoverWindow($role): FindWindow could not locate '
          '"$_nativeTitle" - GetLastError=${win32.GetLastError()}',
        );
        return null;
      }
      _cachedHwnd = hwnd;
      return hwnd;
    } finally {
      calloc.free(titlePtr);
    }
  }
```

Replace the existing `reconcile()` method with:

```dart
  /// If a tracked window id no longer corresponds to a real window,
  /// resets state so the next `show()`/`ensureExists()` creates a fresh
  /// one instead of silently no-op'ing against a dead id.
  Future<void> reconcile() async {
    if (windowId != null && !await isAlive()) {
      _resetWindowState();
    }
  }

  void _resetWindowState() {
    windowId = null;
    isVisible = false;
    _cachedHwnd = null;
  }
```

Also update the `checkAndRewarm()` method - replace the `alive` branch that resets state:

```dart
    if (!alive) {
      debugPrint('ManagedPopoverWindow($role): watchdog detected destruction - re-warming');
      _resetWindowState();
      followerReady = false;
      await ensureExists();
      return;
    }
```

Add the test seams at the very end of the class, before the closing `}`:

```dart
  @visibleForTesting
  int? get cachedHwndForTesting => _cachedHwnd;

  @visibleForTesting
  void setCachedHwndForTesting(int? hwnd) => _cachedHwnd = hwnd;

  /// Resets all native-window state as [reconcile] does when it detects
  /// destruction - exposed for tests that cannot drive a real Win32 window
  /// lifecycle.
  @visibleForTesting
  void resetWindowStateForTesting() => _resetWindowState();
```

- [ ] **Step 4: Run tests - verify they pass**

```
cd apps\worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart --reporter expanded
```

Expected: all tests in the file PASS including the 2 new HWND cache tests.

- [ ] **Step 5: Run the full test suite**

```
cd apps\worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```
git add apps/worklog_studio/lib/core/services/desktop/managed_popover_window.dart
git add apps/worklog_studio/test/core/windows_desktop_service_test.dart
git commit -m "fix: cache HWND after first FindWindow to prevent z-order race on show"
```

---

### Task 3: Add always-on-top to the mini panel

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_test.dart`

**Interfaces:**
- Consumes: `ManagedPopoverWindow.alwaysOnTop` (existing field, no change needed)
- Produces: `_miniPanelWindow` constructed with `alwaysOnTop: true`

- [ ] **Step 1: Write the failing test**

Open `apps/worklog_studio/test/core/windows_desktop_service_test.dart`. Add one more group:

```dart
  group('WindowsDesktopService window configuration', () {
    test('mini panel is configured as always-on-top', () {
      final service = WindowsDesktopService();
      expect(service.miniPanelWindowForTesting.alwaysOnTop, isTrue);
    });

    test('activity window is configured as always-on-top and frameless', () {
      final service = WindowsDesktopService();
      expect(service.activityWindowForTesting.alwaysOnTop, isTrue);
      expect(service.activityWindowForTesting.frameless, isTrue);
    });
  });
```

- [ ] **Step 2: Run tests - verify the mini panel test fails**

```
cd apps\worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart --reporter expanded
```

Expected: the `mini panel is configured as always-on-top` test FAILS (the `alwaysOnTop` flag is `false` by default). The activity window test passes (it already has `alwaysOnTop: true`).

- [ ] **Step 3: Add `alwaysOnTop: true` to `_miniPanelWindow`**

Open `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`.

Find the `_miniPanelWindow` field initialiser (currently around line 57-60):

```dart
  late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
    role: 'miniPanel',
    computeFrame: _computeFrameNearTray,
  );
```

Replace with:

```dart
  late final ManagedPopoverWindow _miniPanelWindow = ManagedPopoverWindow(
    role: 'miniPanel',
    computeFrame: _computeFrameNearTray,
    alwaysOnTop: true,
  );
```

- [ ] **Step 4: Run tests - verify they pass**

```
cd apps\worklog_studio
fvm flutter test test/core/windows_desktop_service_test.dart --reporter expanded
```

Expected: all tests in the file PASS.

- [ ] **Step 5: Run the full test suite**

```
cd apps\worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart
git add apps/worklog_studio/test/core/windows_desktop_service_test.dart
git commit -m "fix: make mini panel always-on-top so it reliably appears above other windows"
```

---

## Manual Verification Checklist

After all three tasks are committed, build a release and verify:

- [ ] Launch the app. Open the mini panel via the tray icon. It appears above any other open windows.
- [ ] Open the activity window via the toggle hotkey. It appears above any other open windows.
- [ ] Focus the activity window, type something, press Enter. The window closes. **The app does not quit.**
- [ ] If the app did quit, check `%LOCALAPPDATA%\WorklogStudio\crash.log` for the actual exception.
- [ ] Repeat the Enter test several times - confirm it is stable.
