# Floating Comment Tracker (Global Hotkey Popup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Windows three global hotkeys (toggle/accept/dismiss) that open the existing tray popover with an inline, editable comment field on the active session, plus a periodic "are you still working on this?" reminder and a settings-persisted configuration for the interval and the three keybindings.

**Architecture:** `HotkeyService` wraps `hotkey_manager` behind an injectable `HotkeyRegistrar` seam and drives the existing `WindowsDesktopService.showPopover()/hidePopover()/togglePopover()` (never a parallel path). New leader-only methods `requestFocusComment()/acceptCurrentComment()/dismissCurrentComment()` on `WindowsDesktopService` round-trip a small set of new IPC method names (`focusComment`/`acceptComment`/`dismissComment`) to the follower engine, which forwards them to `MiniTrackerCubit` as a `commands` stream that `MiniPanel`'s new inline comment editor (built from the existing `InlineField`/`TextArea` pattern) subscribes to. Comment edits leave the follower the same way start/stop already do: a new `TimerActionType.updateComment` dispatched over the existing `dispatchAction` IPC channel, applied on the leader via the existing `TimeTrackerActiveEntryUpdated` bloc event. A new `app_settings` SQLite table (migration v2 -> v3) backs a `SettingsRepository` for the reminder interval and the three serialized hotkeys. `ReminderService` is a pure-Dart periodic timer, also leader-only, that calls the same `showPopover()`/`requestFocusComment()` path and auto-dismisses after ~20s via `dismissCurrentComment()`.

**Tech Stack:** Flutter (Dart), `hotkey_manager` (new dependency), existing `desktop_multi_window`, `sqflite`/`sqflite_common_ffi`, `flutter_bloc`.

## Global Constraints

- Windows only. Do not modify any file under `apps/worklog_studio/macos/` or `macos_desktop_service.dart`. `MiniPanel`/`MiniTrackerCubit` are shared cross-platform code and are explicitly in scope.
- Run all Dart commands via `fvm` (`fvm flutter test`, `fvm flutter pub run build_runner build ...`). Never bare `flutter`/`dart`.
- Resolve dependencies via `fvm exec melos bootstrap` from the repo root (`d:\work\wl_studio`). Never `flutter pub get` inside an app/package directory.
- Mandatory TDD: write the failing test before the implementation for every new piece of testable logic (per `apps/worklog_studio/CLAUDE.md`). UI/window-manager/IPC orchestration that cannot be unit tested is explicitly called out per task instead of skipped silently.
- Never use an em dash or en dash in any code, comment, commit message, or this plan's own future edits. Use a plain hyphen.
- Never add a `Co-Authored-By: Claude` trailer to commit messages.
- Do not touch `*.freezed.dart` or `*.g.dart` files directly; if a `freezed`/generated model needs to change, edit the source annotation and regenerate.
- Before writing code against a newly-added package's API, read its actual installed source under the pub cache (e.g. `C:\Users\vavilov2212\AppData\Local\Pub\Cache\hosted\pub.dev\<pkg>-<version>\lib\`) and confirm class/method names match what this plan assumes. `desktop_multi_window` resolved to a different major version than expected last time; do not assume `hotkey_manager`'s API without checking.
- All popover show/hide/toggle, anywhere in this feature (hotkeys, reminder), must go through `WindowsDesktopService.showPopover()/hidePopover()/togglePopover()` (or the new `acceptCurrentComment()`/`dismissCurrentComment()`/`requestFocusComment()` built on top of them) - never call `DesktopMultiWindow`/`WindowController` directly from new code, or the close-via-X reconciliation logic (`_reconcilePopoverState`) gets bypassed and the dead-window bug reappears.
- `MiniApp`'s `Scaffold` must stay on its current opaque `backgroundColor` (`Color(0xFFf8fafc)`) - never introduce `Colors.transparent` anywhere in the popover's widget tree.

---

## File Structure

- Modify: `apps/worklog_studio/pubspec.yaml` (add `hotkey_manager`)
- Create: `apps/worklog_studio/lib/core/services/desktop/hotkey_registrar.dart` (thin seam over `hotkey_manager`, fakeable)
- Create: `apps/worklog_studio/lib/core/services/desktop/hotkey_service.dart` (default keybindings, registration, settings load/save)
- Create: `apps/worklog_studio/test/core/hotkey_service_test.dart`
- Create: `apps/worklog_studio/lib/core/services/reminder_service.dart`
- Create: `apps/worklog_studio/test/core/reminder_service_test.dart`
- Modify: `apps/worklog_studio/lib/data/sqlite/db_create.dart` (add `app_settings` table)
- Modify: `apps/worklog_studio/lib/data/sqlite/database_provider.dart` (bump `_dbVersion` to 3, add v2->v3 migration)
- Create: `apps/worklog_studio/lib/data/sqlite/sqlite_settings_repository.dart`
- Create: `apps/worklog_studio/test/core/sqlite_settings_repository_test.dart`
- Modify: `apps/worklog_studio/lib/feature/desktop/ipc/ipc_models.dart` (`TimerActionType.updateComment`)
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart` (`updateComment`, `MiniPanelCommand`, `commands` stream)
- Create: `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart` (`updateComment` IPC handling, `requestFocusComment`/`acceptCurrentComment`/`dismissCurrentComment`, wiring `HotkeyService` + `ReminderService` into `initLeader`)
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart` (extend with `updateComment` coverage)
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/src/text_area/text_area.dart` (optional external `focusNode`)
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart` (inline comment editor, command handling)
- Modify: `apps/worklog_studio/lib/feature/settings/settings_screen.dart` (reminder interval + hotkey recorders)

---

### Task 1: Add `hotkey_manager` and confirm its real API

**Files:**
- Modify: `apps/worklog_studio/pubspec.yaml`

**Interfaces:**
- Produces: the `hotkey_manager` package available to import, and a confirmed API surface (written into this task's own notes below) that Tasks 2+ rely on.

This task has no automated test - it is dependency resolution plus reading vendor source.

- [ ] **Step 1: Add the dependency**

In `apps/worklog_studio/pubspec.yaml`, in the `dependencies:` block, add directly under the existing `desktop_multi_window: ^0.1.0` line:

```yaml
  desktop_multi_window: ^0.1.0
  hotkey_manager: ^0.2.3
```

- [ ] **Step 2: Bootstrap and verify it resolves**

Run from the repo root (`d:\work\wl_studio`):

```bash
fvm exec melos bootstrap
```

Expected: completes without dependency resolution errors. If the constraint above does not resolve, let pub pick the closest stable version, update the constraint to match, and re-run bootstrap (same lesson as `desktop_multi_window` resolving to `^0.1.0` instead of `^1.0.0` last time - do not fight the resolver).

- [ ] **Step 3: Read the installed package source and confirm the API**

Find the resolved version directory (e.g. `C:\Users\vavilov2212\AppData\Local\Pub\Cache\hosted\pub.dev\hotkey_manager-<version>\lib\`) and read `hotkey_manager.dart` plus `src/hotkey_manager_windows.dart` (or equivalent). Confirm:
- A `HotKey` class constructible as `HotKey(key: <KeyboardKey>, modifiers: <List<HotKeyModifier>?>, scope: HotKeyScope.system)`.
- A top-level `hotKeyManager` singleton (`HotKeyManager`) with `Future<void> register(HotKey hotKey, {HotKeyHandler? keyDownHandler, HotKeyHandler? keyUpHandler})`, `Future<void> unregister(HotKey hotKey)`, `Future<void> unregisterAll()`.
- A `HotKeyRecorder` widget for capturing a key combo in UI (used later in Task 11's settings screen), with an `onHotKeyRecorded: (HotKey) => ...` callback.
- `HotKey.toJson()` / a static `HotKey.fromJson(Map<String, dynamic>)` (or equivalent) for serializing a hotkey to a plain map - Task 4 persists hotkeys as JSON strings built from this.

If any of these names/shapes differ from what is written here, **update this plan's remaining tasks accordingly before continuing** - do not silently code against the assumed names. This is the same failure mode that broke `desktop_multi_window`'s frameless-window assumption last time.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/pubspec.yaml apps/worklog_studio/pubspec.lock
git commit -m "build: add hotkey_manager dependency for global hotkeys"
```

---

### Task 2: `HotkeyRegistrar` seam over `hotkey_manager`

**Why:** `hotkey_manager`'s real `register()` call goes through a native platform channel and cannot run inside `flutter_test`. Putting a thin interface between `HotkeyService` and the package lets tests inject a fake that records registrations and lets the test invoke handlers directly, without touching any platform code.

**Files:**
- Create: `apps/worklog_studio/lib/core/services/desktop/hotkey_registrar.dart`

**Interfaces:**
- Produces: `abstract interface class HotkeyRegistrar` with `Future<void> register(HotKey hotKey, {required void Function() onPressed})` and `Future<void> unregisterAll()`; `HotkeyManagerRegistrar` (default, wraps `hotKeyManager`); used by Task 3's `HotkeyService` and its test's `FakeHotkeyRegistrar`.

This is a pure wrapper with no branching logic of its own - no test of its own; `HotkeyService`'s tests (Task 3) exercise it through a fake.

- [ ] **Step 1: Write the file**

Create `apps/worklog_studio/lib/core/services/desktop/hotkey_registrar.dart`:

```dart
import 'package:hotkey_manager/hotkey_manager.dart';

/// Thin seam between [HotkeyService] and the `hotkey_manager` package.
///
/// `hotkey_manager`'s real registration goes through a native platform
/// channel that cannot run inside `flutter_test`. Tests supply a fake
/// implementation instead of this default, real one.
abstract interface class HotkeyRegistrar {
  Future<void> register(HotKey hotKey, {required void Function() onPressed});
  Future<void> unregisterAll();
}

/// Default [HotkeyRegistrar] backed by the real `hotkey_manager` package.
class HotkeyManagerRegistrar implements HotkeyRegistrar {
  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async {
    await hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed());
  }

  @override
  Future<void> unregisterAll() => hotKeyManager.unregisterAll();
}
```

(If Task 1's Step 3 found a different handler-callback signature than `keyDownHandler: (_) => onPressed()`, adjust this body to match the real one before continuing - this is the single place that absorbs that difference.)

- [ ] **Step 2: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/core/services/desktop/hotkey_registrar.dart
```

Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/hotkey_registrar.dart
git commit -m "feat: add HotkeyRegistrar seam over hotkey_manager"
```

---

### Task 3: `app_settings` table migration (DB v2 -> v3)

**Files:**
- Modify: `apps/worklog_studio/lib/data/sqlite/db_create.dart`
- Modify: `apps/worklog_studio/lib/data/sqlite/database_provider.dart`

**Interfaces:**
- Produces: an `app_settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)` table, present on both fresh installs (`onCreate`) and upgrades from v2 (`_onUpgrade`). Used by Task 4's `SqliteSettingsRepository`.

No automated test of its own - `onCreate`/`_onUpgrade` are exercised indirectly by Task 4's repository test, which opens a fresh in-memory DB through the same `onCreate` function.

- [ ] **Step 1: Add the table to `onCreate`**

In `apps/worklog_studio/lib/data/sqlite/db_create.dart`, add after the existing `time_entries` table/index block (after the `idx_single_running_entry` statement, still inside `onCreate`):

```dart
  await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
```

- [ ] **Step 2: Add the v2 -> v3 migration**

In `apps/worklog_studio/lib/data/sqlite/database_provider.dart`, bump the version constant:

```dart
  static const _dbVersion = 3; // Incremented for app_settings table
```

Then extend `_onUpgrade`:

```dart
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
```

- [ ] **Step 3: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/data/sqlite/db_create.dart lib/data/sqlite/database_provider.dart
```

Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/data/sqlite/db_create.dart apps/worklog_studio/lib/data/sqlite/database_provider.dart
git commit -m "feat: add app_settings table migration (DB v2 to v3)"
```

---

### Task 4: `SqliteSettingsRepository`

**Files:**
- Create: `apps/worklog_studio/lib/data/sqlite/sqlite_settings_repository.dart`
- Test: `apps/worklog_studio/test/core/sqlite_settings_repository_test.dart`

**Interfaces:**
- Consumes: `onCreate` (Task 3, called directly against an in-memory DB in the test).
- Produces: `class SqliteSettingsRepository` with `Future<String?> getString(String key)`, `Future<void> setString(String key, String value)`, `Future<int?> getInt(String key)`, `Future<void> setInt(String key, int value)`. Used by Task 5 (`HotkeyService`) and Task 6 (`ReminderService`) for persistence, and by Task 11 (settings screen).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/sqlite_settings_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:worklog_studio/data/sqlite/db_create.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';

void main() {
  late SqliteSettingsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: onCreate),
    );
    repository = SqliteSettingsRepository(database: db);
  });

  group('SqliteSettingsRepository', () {
    test('getString returns null when the key is absent', () async {
      expect(await repository.getString('missing_key'), isNull);
    });

    test('setString then getString round-trips the value', () async {
      await repository.setString('toggle_hotkey', '{"key":"keyM"}');

      expect(await repository.getString('toggle_hotkey'), '{"key":"keyM"}');
    });

    test('setString overwrites an existing value for the same key', () async {
      await repository.setString('reminder_interval_minutes', '5');
      await repository.setString('reminder_interval_minutes', '10');

      expect(await repository.getString('reminder_interval_minutes'), '10');
    });

    test('getInt/setInt round-trip through the same string column', () async {
      await repository.setInt('reminder_interval_minutes', 5);

      expect(await repository.getInt('reminder_interval_minutes'), 5);
    });

    test('getInt returns null when the key is absent', () async {
      expect(await repository.getInt('missing_key'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/sqlite_settings_repository_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart'" (the file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `apps/worklog_studio/lib/data/sqlite/sqlite_settings_repository.dart`:

```dart
import 'package:sqflite/sqflite.dart';
import 'package:worklog_studio/data/sqlite/database_provider.dart';

/// Key-value settings persistence backed by the `app_settings` SQLite table.
///
/// Accepts an optional [database] override so tests can supply an in-memory
/// connection instead of the real [DatabaseProvider] singleton.
class SqliteSettingsRepository {
  final Future<Database> Function() _dbProvider;

  SqliteSettingsRepository({Database? database})
      : _dbProvider = database != null
            ? (() async => database)
            : DatabaseProvider.getDatabase;

  Future<String?> getString(String key) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setString(String key, String value) async {
    final db = await _dbProvider();
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int?> getInt(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> setInt(String key, int value) =>
      setString(key, value.toString());
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
fvm flutter test test/core/sqlite_settings_repository_test.dart
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/data/sqlite/sqlite_settings_repository.dart apps/worklog_studio/test/core/sqlite_settings_repository_test.dart
git commit -m "feat: add SqliteSettingsRepository for app_settings key-value storage"
```

---

### Task 5: `TimerActionType.updateComment`

**Why:** Today `TimerAction`/`TimerActionType` only model `start`/`stop`. The popover's new comment editor needs a third action that round-trips a comment edit from the follower (popover) engine to the leader, over the exact same `dispatchAction` IPC channel start/stop already use - no new persistence path.

**Files:**
- Modify: `apps/worklog_studio/lib/feature/desktop/ipc/ipc_models.dart`
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart:277-308` (`_handleFollowerAction`)
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`

**Interfaces:**
- Produces: `TimerActionType.updateComment`; `_handleFollowerAction` dispatches `TimeTrackerActiveEntryUpdated(comment: action.comment)` on the leader bloc when it sees this type. Used by Task 6's `MiniTrackerCubit.updateComment`.

- [ ] **Step 1: Write the failing test**

In `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`, add a new test inside the existing `group('WindowsDesktopService IPC message handling', ...)`, right after the `dispatchAction(stop) is a no-op when nothing is running` test:

```dart
    test('dispatchAction(updateComment) updates the running entry comment', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'start',
        'projectId': 'p1',
        'taskId': 't1',
        'comment': 'original',
      });
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'updateComment',
        'comment': 'updated comment',
      });
      await bloc.stream.firstWhere(
        (s) => s.activeEntryOrNull?.comment == 'updated comment',
      );

      expect(bloc.state.activeEntryOrNull?.comment, 'updated comment');
      expect(bloc.state.isRunning, isTrue);
    });

    test('dispatchAction(updateComment) is a no-op when nothing is running', () async {
      await service.handleIncomingIpcMessageForTesting('dispatchAction', {
        'type': 'updateComment',
        'comment': 'ignored',
      });

      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.isRunning, isFalse);
    });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: FAIL - `TimerAction.fromJson` maps any `type` value other than `'start'` to `TimerActionType.stop` today (see its ternary), so the first new test fails because `updateComment` is silently treated as `stop` and the comment is never applied; the assertion on `bloc.state.activeEntryOrNull?.comment` times out / fails.

- [ ] **Step 3: Add the new enum value and JSON mapping**

In `apps/worklog_studio/lib/feature/desktop/ipc/ipc_models.dart`, replace:

```dart
enum TimerActionType { start, stop }
```

with:

```dart
enum TimerActionType { start, stop, updateComment }
```

Replace the `toJson`/`fromJson` methods on `TimerAction`:

```dart
  Map<String, dynamic> toJson() {
    return {
      'type': switch (type) {
        TimerActionType.start => 'start',
        TimerActionType.stop => 'stop',
        TimerActionType.updateComment => 'updateComment',
      },
      'projectId': projectId,
      'taskId': taskId,
      'comment': comment,
    };
  }

  static TimerAction fromJson(Map<String, dynamic> json) {
    return TimerAction(
      type: switch (json['type']) {
        'start' => TimerActionType.start,
        'updateComment' => TimerActionType.updateComment,
        _ => TimerActionType.stop,
      },
      projectId: json['projectId'],
      taskId: json['taskId'],
      comment: json['comment'],
    );
  }
```

- [ ] **Step 4: Handle the new type in `_handleFollowerAction`**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, in `_handleFollowerAction`, replace the closing `else if` branch:

```dart
    } else if (action.type == TimerActionType.stop) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
      }
    }
  }
```

with:

```dart
    } else if (action.type == TimerActionType.stop) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerStopped());
      }
    } else if (action.type == TimerActionType.updateComment) {
      if (isCurrentlyRunning) {
        _leaderBloc!.add(TimeTrackerActiveEntryUpdated(comment: action.comment));
      }
    }
  }
```

- [ ] **Step 5: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/ipc/ipc_models.dart apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart
git commit -m "feat: add TimerActionType.updateComment IPC round-trip"
```

---

### Task 6: `MiniTrackerCubit.updateComment` and the `commands` stream

**Why:** `MiniPanel`'s new inline comment editor needs (a) a way to push a comment edit out over `dispatchAction` (mirroring `startTimer`/`stopTimer`), and (b) a way to receive `focusComment`/`acceptComment`/`dismissComment` instructions pushed down from the leader by hotkeys and the reminder, since the actual edit buffer lives in the follower engine's widget state, not the leader.

**Files:**
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`
- Test: `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`

**Interfaces:**
- Produces: `enum MiniPanelCommand { focusComment, acceptComment, dismissComment }`; `MiniTrackerCubit.updateComment(String comment)`; `Stream<MiniPanelCommand> get commands`; `void emitCommand(MiniPanelCommand command)`. Used by Task 7 (`WindowsDesktopService` follower-side IPC handling) and Task 10 (`MiniPanel`).
- Consumes: `DesktopServiceRegistry.instance.dispatchAction` (existing), `TimerAction`/`TimerActionType.updateComment` (Task 5).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/no_op_desktop_service.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/desktop/ipc/ipc_models.dart';
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';

class _RecordingDesktopService extends NoOpDesktopService {
  final List<dynamic> dispatched = [];

  @override
  void dispatchAction(covariant dynamic action) {
    dispatched.add(action);
  }
}

void main() {
  late _RecordingDesktopService desktopService;
  late MiniTrackerCubit cubit;

  setUp(() {
    desktopService = _RecordingDesktopService();
    DesktopServiceRegistry.overrideForTesting(desktopService);
    cubit = MiniTrackerCubit();
  });

  tearDown(() async {
    await cubit.close();
  });

  group('MiniTrackerCubit.updateComment', () {
    test('dispatches an updateComment TimerAction when a session is running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.updateComment('new comment');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.updateComment);
      expect(action.comment, 'new comment');
    });

    test('does nothing when no session is running', () {
      cubit.updateComment('ignored');

      expect(desktopService.dispatched, isEmpty);
    });
  });

  group('MiniTrackerCubit.commands', () {
    test('emitCommand replays on the commands stream', () async {
      final received = <MiniPanelCommand>[];
      final sub = cubit.commands.listen(received.add);

      cubit.emitCommand(MiniPanelCommand.focusComment);
      cubit.emitCommand(MiniPanelCommand.acceptComment);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.focusComment, MiniPanelCommand.acceptComment]);
      await sub.cancel();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart
```

Expected: FAIL - `updateComment`, `commands`, `emitCommand`, and `MiniPanelCommand` don't exist yet (compile error).

- [ ] **Step 3: Write the implementation**

In `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`, add the import:

```dart
import 'dart:async';
```

Add the enum above `MiniTrackerState`:

```dart
enum MiniPanelCommand { focusComment, acceptComment, dismissComment }
```

Replace the `MiniTrackerCubit` class body's constructor/start with a `commands` stream and `dispose`-safe close, and add `updateComment`:

```dart
class MiniTrackerCubit extends Cubit<MiniTrackerState> {
  MiniTrackerCubit() : super(const MiniTrackerState());

  final _commandController = StreamController<MiniPanelCommand>.broadcast();

  Stream<MiniPanelCommand> get commands => _commandController.stream;

  void emitCommand(MiniPanelCommand command) {
    _commandController.add(command);
  }

  @override
  Future<void> close() {
    _commandController.close();
    return super.close();
  }

  void updateFromSnapshot(TimerSnapshot snapshot) {
    if (snapshot.timestamp < state.lastTimestamp) return;
    emit(
      state.copyWith(
        isRunning: snapshot.isRunning,
        activeEntry: snapshot.activeEntry,
        allEntries: snapshot.entries,
        tasks: snapshot.tasks,
        projects: snapshot.projects,
        lastTimestamp: snapshot.timestamp,
      ),
    );
  }

  void startTimer({String? projectId, String? taskId, String? comment}) {
    if (state.isRunning &&
        state.activeEntry?.projectId == projectId &&
        state.activeEntry?.taskId == taskId) {
      return;
    }

    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(
        type: TimerActionType.start,
        projectId: projectId,
        taskId: taskId,
        comment: comment,
      ),
    );
  }

  void stopTimer() {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(type: TimerActionType.stop),
    );
  }

  void updateComment(String comment) {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(type: TimerActionType.updateComment, comment: comment),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart
git commit -m "feat: add MiniTrackerCubit.updateComment and command stream"
```

---

### Task 7: `WindowsDesktopService` accept/dismiss/focus round-trip

**Why:** The comment edit buffer lives in the follower (popover) engine's `MiniPanel` widget state, not the leader. Hotkeys and the reminder are registered and fire on the leader engine (the one that stays alive in the tray). So accepting/dismissing/focusing the comment has to be a leader-to-follower IPC instruction, mirroring the existing `broadcastSnapshot` (leader-to-follower) and `dispatchAction` (follower-to-leader) messages already on this channel.

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`
- Modify: `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`

**Interfaces:**
- Consumes: `MiniTrackerCubit.emitCommand`/`MiniPanelCommand` (Task 6).
- Produces (leader-only; not part of `IDesktopPlatformService` - this whole feature is Windows-only): `Future<void> requestFocusComment()`, `Future<void> acceptCurrentComment()`, `Future<void> dismissCurrentComment()`. Used by Task 8 (`HotkeyService`) and Task 9 (`ReminderService`).
- Produces (follower-side, testable): new `_handleIncomingIpcMessage` cases `'focusComment'`/`'acceptComment'`/`'dismissComment'` that call `_followerCubit?.emitCommand(...)`, plus a `@visibleForTesting setFollowerCubitForTesting`.

- [ ] **Step 1: Write the failing test (follower-side IPC -> cubit command)**

In `apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart`, add the import:

```dart
import 'package:worklog_studio/feature/desktop/presentation/mini_tracker_cubit.dart';
```

Add a new group after the existing `dispatchAction` tests, inside `main()`:

```dart
  group('WindowsDesktopService follower-side command forwarding', () {
    late WindowsDesktopService followerService;
    late MiniTrackerCubit followerCubit;

    setUp(() {
      followerService = WindowsDesktopService();
      followerCubit = MiniTrackerCubit();
      followerService.setFollowerCubitForTesting(followerCubit);
    });

    tearDown(() async {
      await followerCubit.close();
    });

    test('focusComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('focusComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.focusComment]);
      await sub.cancel();
    });

    test('acceptComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('acceptComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.acceptComment]);
      await sub.cancel();
    });

    test('dismissComment forwards to the follower cubit as a command', () async {
      final received = <MiniPanelCommand>[];
      final sub = followerCubit.commands.listen(received.add);

      await followerService.handleIncomingIpcMessageForTesting('dismissComment', null);
      await Future<void>.delayed(Duration.zero);

      expect(received, [MiniPanelCommand.dismissComment]);
      await sub.cancel();
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: FAIL - `setFollowerCubitForTesting` doesn't exist and the three new IPC cases aren't handled (compile error, then behavioral failure once it compiles).

- [ ] **Step 3: Add the follower-side test seam and IPC cases**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, in the `// ── Test seams ──` section at the bottom, add:

```dart
  @visibleForTesting
  void setFollowerCubitForTesting(MiniTrackerCubit cubit) =>
      _followerCubit = cubit;
```

In `_handleIncomingIpcMessage`'s `switch (method)`, add three new cases right before the `case 'dispatchAction':` line:

```dart
        case 'focusComment':
          _followerCubit?.emitCommand(MiniPanelCommand.focusComment);

        case 'acceptComment':
          _followerCubit?.emitCommand(MiniPanelCommand.acceptComment);

        case 'dismissComment':
          _followerCubit?.emitCommand(MiniPanelCommand.dismissComment);

```

(`MiniPanelCommand` is already importable from `mini_tracker_cubit.dart`, which this file already imports.)

- [ ] **Step 4: Run test to verify it passes**

```bash
fvm flutter test test/core/windows_desktop_service_ipc_test.dart
```

Expected: all tests in the new group PASS.

- [ ] **Step 5: Add the leader-side methods (no automated test - real IPC/window calls)**

These three methods make real `DesktopMultiWindow.invokeMethod` calls and call the existing `hidePopover()`, none of which can run inside `flutter_test` (same reasoning as Task 5 of the companion popover-infrastructure plan). Add them to `WindowsDesktopService`, in the `// ── IDesktopPlatformService ──` section right after `hidePopover()` (these are not interface members, just public methods on the concrete class):

```dart
  bool _pendingFocusComment = false;

  /// Asks the follower (popover) engine to put the comment field into edit
  /// mode and request keyboard focus. If the popover isn't ready yet (e.g.
  /// it was just created and hasn't sent `miniReady`), the request is
  /// deferred and replayed once `miniReady` arrives - see
  /// [_handleIncomingIpcMessage]'s `'miniReady'` case.
  Future<void> requestFocusComment() async {
    if (_followerReady && _popoverWindowId != null) {
      await _invokeFollower('focusComment', null);
    } else {
      _pendingFocusComment = true;
    }
  }

  /// Tells the follower to commit its current comment edit (if any), then
  /// hides the popover. The actual `TimerAction.updateComment` dispatch (if
  /// the comment changed) arrives asynchronously afterward over the existing
  /// `dispatchAction` channel - the popover engine stays alive while hidden,
  /// so this is safe even though we don't wait for it here.
  Future<void> acceptCurrentComment() async {
    await _invokeFollower('acceptComment', null);
    await hidePopover();
  }

  /// Tells the follower to discard its current comment edit (reverting the
  /// field to the last persisted value), then hides the popover.
  Future<void> dismissCurrentComment() async {
    await _invokeFollower('dismissComment', null);
    await hidePopover();
  }

  Future<void> _invokeFollower(String method, dynamic arguments) async {
    if (_popoverWindowId == null) return;
    try {
      await DesktopMultiWindow.invokeMethod(_popoverWindowId!, method, arguments);
    } catch (e) {
      debugPrint('WindowsDesktopService: failed to invoke follower "$method" - $e');
    }
  }
```

Then update the existing `'miniReady'` case in `_handleIncomingIpcMessage` to replay a pending focus request:

```dart
        case 'miniReady':
          _followerReady = true;
          if (_leaderBloc != null) {
            await _broadcastSnapshotIfReady(_leaderBloc!.state);
          }
          if (_pendingFocusComment) {
            _pendingFocusComment = false;
            await _invokeFollower('focusComment', null);
          }
```

- [ ] **Step 6: Static analysis and full suite**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/core/services/desktop/windows_desktop_service.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: "No issues found!" and all tests green.

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart apps/worklog_studio/test/core/windows_desktop_service_ipc_test.dart
git commit -m "feat: add accept/dismiss/focus-comment round-trip to WindowsDesktopService"
```

---

### Task 8: Shared settings keys + `HotkeyService`

**Files:**
- Create: `apps/worklog_studio/lib/core/services/settings_keys.dart`
- Create: `apps/worklog_studio/lib/core/services/desktop/hotkey_service.dart`
- Test: `apps/worklog_studio/test/core/hotkey_service_test.dart`

**Interfaces:**
- Consumes: `HotkeyRegistrar` (Task 2).
- Produces: `SettingsKeys.toggleHotkey`/`.acceptHotkey`/`.dismissHotkey`/`.reminderIntervalMinutes` (4 string constants, also used by Task 9 and Task 11); `class HotkeyService` with `Future<void> init()`, `Future<void> saveHotkey(String settingKey, HotKey hotKey)`, `void dispose()`. Used by Task 12 (wired into `WindowsDesktopService.initLeader`) and Task 11 (settings screen).

- [ ] **Step 1: Write `SettingsKeys`**

Create `apps/worklog_studio/lib/core/services/settings_keys.dart`:

```dart
/// Keys used in the `app_settings` key-value table.
///
/// Centralised here so [HotkeyService], [ReminderService], and the settings
/// screen never duplicate these strings.
abstract final class SettingsKeys {
  static const toggleHotkey = 'toggle_hotkey';
  static const acceptHotkey = 'accept_hotkey';
  static const dismissHotkey = 'dismiss_hotkey';
  static const reminderIntervalMinutes = 'reminder_interval_minutes';
}
```

- [ ] **Step 2: Write the failing test**

Create `apps/worklog_studio/test/core/hotkey_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';

class _FakeHotkeyRegistrar implements HotkeyRegistrar {
  final List<HotKey> registered = [];
  final Map<HotKey, void Function()> handlers = {};
  int unregisterAllCalls = 0;

  @override
  Future<void> register(HotKey hotKey, {required void Function() onPressed}) async {
    registered.add(hotKey);
    handlers[hotKey] = onPressed;
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCalls++;
    registered.clear();
    handlers.clear();
  }
}

void main() {
  late _FakeHotkeyRegistrar registrar;
  late Map<String, String> store;
  late int toggleCalls;
  late int acceptCalls;
  late int dismissCalls;
  late HotkeyService service;

  setUp(() {
    registrar = _FakeHotkeyRegistrar();
    store = {};
    toggleCalls = 0;
    acceptCalls = 0;
    dismissCalls = 0;
    service = HotkeyService(
      registrar: registrar,
      getSetting: (key) async => store[key],
      setSetting: (key, value) async => store[key] = value,
      onToggle: () async => toggleCalls++,
      onAccept: () async => acceptCalls++,
      onDismiss: () async => dismissCalls++,
    );
  });

  group('HotkeyService.init', () {
    test('registers three default hotkeys when no settings are stored', () async {
      await service.init();

      expect(registrar.registered, hasLength(3));
    });

    test('the registered toggle hotkey invokes onToggle when pressed', () async {
      await service.init();

      final toggleHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyM,
      );
      registrar.handlers[toggleHotKey]!();

      expect(toggleCalls, 1);
      expect(acceptCalls, 0);
      expect(dismissCalls, 0);
    });

    test('the registered accept hotkey invokes onAccept when pressed', () async {
      await service.init();

      final acceptHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.enter,
      );
      registrar.handlers[acceptHotKey]!();

      expect(acceptCalls, 1);
    });

    test('the registered dismiss hotkey invokes onDismiss when pressed', () async {
      await service.init();

      final dismissHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.escape,
      );
      registrar.handlers[dismissHotKey]!();

      expect(dismissCalls, 1);
    });

    test('uses a stored custom toggle hotkey instead of the default', () async {
      final custom = HotKey(
        key: PhysicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      store[SettingsKeys.toggleHotkey] = jsonEncode(custom.toJson());

      await service.init();

      final toggleHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyT,
      );
      registrar.handlers[toggleHotKey]!();
      expect(toggleCalls, 1);
    });
  });

  group('HotkeyService.saveHotkey', () {
    test('persists the hotkey and re-registers all three hotkeys', () async {
      await service.init();
      registrar.registered.clear();

      final custom = HotKey(
        key: PhysicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      await service.saveHotkey(SettingsKeys.toggleHotkey, custom);

      expect(store[SettingsKeys.toggleHotkey], jsonEncode(custom.toJson()));
      expect(registrar.registered, hasLength(3));
      expect(registrar.registered.any((h) => h.key == PhysicalKeyboardKey.keyT), isTrue);
    });
  });

  group('HotkeyService.dispose', () {
    test('unregisters everything', () async {
      await service.init();

      service.dispose();

      expect(registrar.unregisterAllCalls, 1);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/hotkey_service_test.dart
```

Expected: FAIL - `HotkeyService` doesn't exist yet (compile error).

- [ ] **Step 4: Write the implementation**

Create `apps/worklog_studio/lib/core/services/desktop/hotkey_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';

/// Registers the three global hotkeys (toggle / accept / dismiss) described
/// in the floating-comment-tracker spec, loading any custom bindings the
/// user has saved via [SettingsKeys] and falling back to the documented
/// defaults otherwise.
class HotkeyService {
  final HotkeyRegistrar _registrar;
  final Future<String?> Function(String key) _getSetting;
  final Future<void> Function(String key, String value) _setSetting;
  final Future<void> Function() _onToggle;
  final Future<void> Function() _onAccept;
  final Future<void> Function() _onDismiss;

  HotkeyService({
    required HotkeyRegistrar registrar,
    required Future<String?> Function(String key) getSetting,
    required Future<void> Function(String key, String value) setSetting,
    required Future<void> Function() onToggle,
    required Future<void> Function() onAccept,
    required Future<void> Function() onDismiss,
  })  : _registrar = registrar,
        _getSetting = getSetting,
        _setSetting = setSetting,
        _onToggle = onToggle,
        _onAccept = onAccept,
        _onDismiss = onDismiss;

  static HotKey _defaultHotKey(KeyboardKey key) => HotKey(
        key: key,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );

  Future<HotKey> _resolveHotKey(String settingKey, HotKey fallback) async {
    final stored = await _getSetting(settingKey);
    if (stored == null) return fallback;
    try {
      return HotKey.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('HotkeyService: failed to parse stored hotkey "$settingKey" - $e');
      return fallback;
    }
  }

  Future<void> init() async {
    await _registerAll();
  }

  Future<void> _registerAll() async {
    await _registrar.unregisterAll();

    final toggle = await _resolveHotKey(
      SettingsKeys.toggleHotkey,
      _defaultHotKey(PhysicalKeyboardKey.keyM),
    );
    final accept = await _resolveHotKey(
      SettingsKeys.acceptHotkey,
      _defaultHotKey(PhysicalKeyboardKey.enter),
    );
    final dismiss = await _resolveHotKey(
      SettingsKeys.dismissHotkey,
      _defaultHotKey(PhysicalKeyboardKey.escape),
    );

    await _registrar.register(toggle, onPressed: () => _onToggle());
    await _registrar.register(accept, onPressed: () => _onAccept());
    await _registrar.register(dismiss, onPressed: () => _onDismiss());
  }

  /// Persists [hotKey] under [settingKey] and re-registers all three
  /// hotkeys so the change takes effect immediately.
  Future<void> saveHotkey(String settingKey, HotKey hotKey) async {
    await _setSetting(settingKey, jsonEncode(hotKey.toJson()));
    await _registerAll();
  }

  void dispose() {
    _registrar.unregisterAll();
  }
}
```

If Task 1's Step 3 found that `HotKey.fromJson` is not a static factory (e.g. it is named differently or lives elsewhere), adjust `_resolveHotKey` accordingly - this is the one place that absorbs that difference.

- [ ] **Step 5: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/hotkey_service_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/core/services/settings_keys.dart apps/worklog_studio/lib/core/services/desktop/hotkey_service.dart apps/worklog_studio/test/core/hotkey_service_test.dart
git commit -m "feat: add HotkeyService with default toggle/accept/dismiss bindings"
```

---

### Task 9: `ReminderService`

**Why:** Needs a periodic nudge active only while a time entry is running, with an injectable timer so tests never wait on real minutes/seconds. `dart:async`'s `Timer` can't be faked directly (it's a concrete, non-extensible class), so this introduces a tiny `CancelableTimer` interface that the real implementation wraps `Timer` in, and tests substitute with a recording fake.

**Files:**
- Create: `apps/worklog_studio/lib/core/services/reminder_service.dart`
- Test: `apps/worklog_studio/test/core/reminder_service_test.dart`

**Interfaces:**
- Consumes: `TimeTrackerBloc` (existing), `SettingsKeys.reminderIntervalMinutes` (Task 8).
- Produces: `class ReminderService` with `Future<void> init()`, `void dispose()`. Used by Task 12 (wired into `WindowsDesktopService.initLeader`, with `onFire` calling `showPopover()` + `requestFocusComment()` and `onAutoDismiss` calling `dismissCurrentComment()`).

- [ ] **Step 1: Write the failing test**

Create `apps/worklog_studio/test/core/reminder_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

import '../helpers/test_fakes.dart';

class _FakeCancelableTimer implements CancelableTimer {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

void main() {
  late FakeClock clock;
  late FakeTimeEntryRepository repo;
  late TimeTrackerBloc bloc;
  late Map<String, String> store;
  late int fireCalls;
  late int autoDismissCalls;
  late List<Duration> periodicDurations;
  late List<void Function()> periodicCallbacks;
  late List<_FakeCancelableTimer> periodicTimers;
  late List<Duration> oneShotDurations;
  late List<void Function()> oneShotCallbacks;
  late List<_FakeCancelableTimer> oneShotTimers;
  late ReminderService service;

  setUp(() {
    clock = FakeClock(DateTime(2025, 1, 1, 9));
    repo = FakeTimeEntryRepository();
    bloc = TimeTrackerBloc(service: TimeTrackerService(repository: repo, clock: clock));
    store = {};
    fireCalls = 0;
    autoDismissCalls = 0;
    periodicDurations = [];
    periodicCallbacks = [];
    periodicTimers = [];
    oneShotDurations = [];
    oneShotCallbacks = [];
    oneShotTimers = [];

    service = ReminderService(
      bloc: bloc,
      getSetting: (key) async => store[key],
      onFire: () async => fireCalls++,
      onAutoDismiss: () async => autoDismissCalls++,
      periodicTimerFactory: (duration, onTick) {
        periodicDurations.add(duration);
        periodicCallbacks.add(onTick);
        final timer = _FakeCancelableTimer();
        periodicTimers.add(timer);
        return timer;
      },
      oneShotTimerFactory: (duration, onFire) {
        oneShotDurations.add(duration);
        oneShotCallbacks.add(onFire);
        final timer = _FakeCancelableTimer();
        oneShotTimers.add(timer);
        return timer;
      },
    );
  });

  tearDown(() async {
    service.dispose();
    await bloc.close();
  });

  group('ReminderService.init', () {
    test('starts a periodic timer at the configured interval while running', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);
      store[SettingsKeys.reminderIntervalMinutes] = '5';

      await service.init();

      expect(periodicDurations, [const Duration(minutes: 5)]);
    });

    test('does not start a timer when the interval is unset', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);

      await service.init();

      expect(periodicDurations, isEmpty);
    });

    test('does not start a timer when nothing is running', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';

      await service.init();

      expect(periodicDurations, isEmpty);
    });
  });

  group('ReminderService firing', () {
    test('on fire, calls onFire and schedules a 20s auto-dismiss', () async {
      repo.seed(TimeEntry(
        id: 'e1',
        startAt: clock.now(),
        status: TimeEntryStatus.running,
      ));
      bloc.add(TimeTrackerLoaded());
      await bloc.stream.firstWhere((s) => s.isRunning);
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      await service.init();

      periodicCallbacks.single();
      await Future<void>.delayed(Duration.zero);

      expect(fireCalls, 1);
      expect(oneShotDurations, [const Duration(seconds: 20)]);

      oneShotCallbacks.single();
      await Future<void>.delayed(Duration.zero);

      expect(autoDismissCalls, 1);
    });
  });

  group('ReminderService bloc transitions', () {
    test('starting tracking after init starts the reminder timer', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      await service.init();
      expect(periodicDurations, isEmpty);

      bloc.add(const TimeTrackerStarted(projectId: 'p1', taskId: 't1'));
      await bloc.stream.firstWhere((s) => s.isRunning);

      expect(periodicDurations, [const Duration(minutes: 5)]);
    });

    test('stopping tracking cancels the reminder timer', () async {
      store[SettingsKeys.reminderIntervalMinutes] = '5';
      bloc.add(const TimeTrackerStarted(projectId: 'p1', taskId: 't1'));
      await bloc.stream.firstWhere((s) => s.isRunning);
      await service.init();
      expect(periodicTimers, hasLength(1));

      bloc.add(TimeTrackerStopped());
      await bloc.stream.firstWhere((s) => !s.isRunning);

      expect(periodicTimers.single.cancelled, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd apps/worklog_studio
fvm flutter test test/core/reminder_service_test.dart
```

Expected: FAIL - `ReminderService`/`CancelableTimer` don't exist yet (compile error).

- [ ] **Step 3: Write the implementation**

Create `apps/worklog_studio/lib/core/services/reminder_service.dart`:

```dart
import 'dart:async';

import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

/// Minimal cancelable-timer interface so [ReminderService] never depends on
/// the concrete, non-extensible `dart:async` `Timer` class directly - tests
/// substitute a recording fake instead of waiting on real time.
abstract interface class CancelableTimer {
  void cancel();
}

class _RealTimer implements CancelableTimer {
  final Timer _timer;
  _RealTimer(this._timer);

  @override
  void cancel() => _timer.cancel();
}

typedef PeriodicTimerFactory = CancelableTimer Function(
  Duration duration,
  void Function() onTick,
);
typedef OneShotTimerFactory = CancelableTimer Function(
  Duration duration,
  void Function() onFire,
);

CancelableTimer _defaultPeriodic(Duration duration, void Function() onTick) =>
    _RealTimer(Timer.periodic(duration, (_) => onTick()));

CancelableTimer _defaultOneShot(Duration duration, void Function() onFire) =>
    _RealTimer(Timer(duration, onFire));

/// Periodically nudges the user to confirm/update the active entry's
/// comment while a time entry is running, by re-opening the popover via
/// [onFire] and auto-dismissing it via [onAutoDismiss] after ~20 seconds if
/// left untouched.
class ReminderService {
  final TimeTrackerBloc _bloc;
  final Future<String?> Function(String key) _getSetting;
  final Future<void> Function() _onFire;
  final Future<void> Function() _onAutoDismiss;
  final PeriodicTimerFactory _periodicTimerFactory;
  final OneShotTimerFactory _oneShotTimerFactory;

  static const _autoDismissDelay = Duration(seconds: 20);

  StreamSubscription<TimeTrackerBlocState>? _blocSub;
  CancelableTimer? _reminderTimer;
  CancelableTimer? _autoDismissTimer;
  bool _wasRunning = false;

  ReminderService({
    required TimeTrackerBloc bloc,
    required Future<String?> Function(String key) getSetting,
    required Future<void> Function() onFire,
    required Future<void> Function() onAutoDismiss,
    PeriodicTimerFactory periodicTimerFactory = _defaultPeriodic,
    OneShotTimerFactory oneShotTimerFactory = _defaultOneShot,
  })  : _bloc = bloc,
        _getSetting = getSetting,
        _onFire = onFire,
        _onAutoDismiss = onAutoDismiss,
        _periodicTimerFactory = periodicTimerFactory,
        _oneShotTimerFactory = oneShotTimerFactory;

  Future<void> init() async {
    _wasRunning = _bloc.state.isRunning;
    if (_wasRunning) await _startReminderTimer();
    _blocSub = _bloc.stream.listen(_onBlocState);
  }

  Future<void> _onBlocState(TimeTrackerBlocState state) async {
    if (state.isRunning && !_wasRunning) {
      _wasRunning = true;
      await _startReminderTimer();
    } else if (!state.isRunning && _wasRunning) {
      _wasRunning = false;
      _cancelTimers();
    }
  }

  Future<void> _startReminderTimer() async {
    _cancelTimers();
    final raw = await _getSetting(SettingsKeys.reminderIntervalMinutes);
    final minutes = raw != null ? int.tryParse(raw) : null;
    if (minutes == null || minutes <= 0) return;
    _reminderTimer = _periodicTimerFactory(
      Duration(minutes: minutes),
      () => _fire(),
    );
  }

  void _cancelTimers() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  Future<void> _fire() async {
    await _onFire();
    _autoDismissTimer = _oneShotTimerFactory(_autoDismissDelay, () {
      _onAutoDismiss();
    });
  }

  void dispose() {
    _blocSub?.cancel();
    _cancelTimers();
  }
}
```

- [ ] **Step 4: Run test to verify it passes, then the full suite**

```bash
cd apps/worklog_studio
fvm flutter test test/core/reminder_service_test.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/core/services/reminder_service.dart apps/worklog_studio/test/core/reminder_service_test.dart
git commit -m "feat: add ReminderService with injectable cancelable timers"
```

---

### Task 10: Inline comment editor in `MiniPanel`

**Why:** `MiniPanel` currently shows the active entry's comment only as a read-only fallback title (`activeEntry.comment ?? 'Running Task'` at `mini_panel.dart:80`). This task adds a real editable field using the same `InlineField`/`TextArea` pattern `time_entry_drawer.dart` already uses for the main app's comment field, wires it to `MiniTrackerCubit.updateComment`, and subscribes to `MiniTrackerCubit.commands` to honor `focusComment`/`acceptComment`/`dismissComment` pushed down from the leader's hotkeys/reminder (Tasks 7-9).

**Files:**
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/src/text_area/text_area.dart`
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart`

**Interfaces:**
- Consumes: `MiniTrackerCubit.updateComment`/`.commands`/`MiniPanelCommand` (Task 6), `InlineField`/`InlineFieldController` (existing).
- Produces: an optional `focusNode` parameter on `TextArea`, defaulting to its existing internally-owned node so every other call site (e.g. `time_entry_drawer.dart`) is unaffected.

This is UI wiring with no new business logic of its own - `MiniTrackerCubit.updateComment`/`.commands` already have unit coverage from Task 6. Exempt from the mandatory-test rule per `apps/worklog_studio/CLAUDE.md` ("UI-only changes are exempt"). Verified by `fvm flutter analyze` plus the manual checklist in Task 13.

- [ ] **Step 1: Add an optional external `focusNode` to `TextArea`**

In `packages/worklog_studio_style_system/lib/ui_kit/src/text_area/text_area.dart`, add a field to the widget:

```dart
class TextArea extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;
  final bool hasError;
  final bool autofocus;
  final int maxLength;
  final int? maxLines;
  final bool showCounter;
  final ControlSize size;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const TextArea({
    required this.hintText,
    required this.controller,
    this.label,
    this.enabled = true,
    this.autofocus = false,
    this.hasError = false,
    this.showCounter = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 5,
    this.maxLength = 3000,
    this.size = ControlSize.sm,
    this.onChanged,
    this.focusNode,
    super.key,
  });
```

Replace the internal `_focusNode` field/lifecycle so it only creates its own node when the caller didn't supply one:

```dart
class _TextAreaState extends State<TextArea> {
  TextEditingController get controller => widget.controller;
  get palette => context.theme.colorsPalette;
  bool _hasFocus = false;
  double? _manualHeight;
  bool _isResizing = false;
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }
```

Every other reference to `_focusNode` in the file's `build` method stays exactly as-is - they now resolve through the new getter.

- [ ] **Step 2: Static analysis on the style-system package**

```bash
cd packages/worklog_studio_style_system
fvm flutter analyze lib/ui_kit/src/text_area/text_area.dart
```

Expected: "No issues found!"

- [ ] **Step 3: Run the app's existing test suite to confirm nothing broke**

```bash
cd apps/worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green (no test directly exercises `TextArea`, but this confirms the dependent package still compiles against it).

- [ ] **Step 4: Add the inline comment editor to `MiniPanel`**

In `apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart`, add imports:

```dart
import 'dart:async';

import 'package:worklog_studio/feature/common/presentation/components/inline_field.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
```

Add fields to `_MiniPanelState`, alongside `_searchController`/`_searchFocusNode`:

```dart
  final TextEditingController _commentController = TextEditingController();
  final InlineFieldController _commentFieldController = InlineFieldController();
  final FocusNode _commentFocusNode = FocusNode();
  StreamSubscription<MiniPanelCommand>? _commandSub;
```

In `initState`, after the existing `_searchFocusNode.addListener(...)` block, add:

```dart
    _commentFieldController.addListener(_onCommentEditModeChanged);
    _commandSub = context.read<MiniTrackerCubit>().commands.listen(_handleCommand);
```

Add the new methods near `_buildActiveSession`:

```dart
  void _onCommentEditModeChanged() {
    if (!mounted) return;
    if (!_commentFieldController.isEditing) {
      final cubit = context.read<MiniTrackerCubit>();
      if (cubit.state.activeEntry?.comment != _commentController.text) {
        cubit.updateComment(_commentController.text);
      }
    }
  }

  void _handleCommand(MiniPanelCommand command) {
    if (!mounted) return;
    switch (command) {
      case MiniPanelCommand.focusComment:
        _commentFieldController.enterEditMode(_commentController.text);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _commentFocusNode.requestFocus();
        });
      case MiniPanelCommand.acceptComment:
        _commentFieldController.handleEditorCommit(_commentController.text);
      case MiniPanelCommand.dismissComment:
        final persisted = context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        _commentController.text = persisted;
        _commentFieldController.handleEditorCancel();
    }
  }
```

Update `dispose()`:

```dart
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _commentController.dispose();
    _commentFieldController.removeListener(_onCommentEditModeChanged);
    _commentFieldController.dispose();
    _commentFocusNode.dispose();
    _commandSub?.cancel();
    super.dispose();
  }
```

In `_buildActiveSession`, sync the controller from the latest snapshot (when not mid-edit) and render the field. Replace the method's signature line and the start of its body:

```dart
  Widget _buildActiveSession(
    bool isRunning,
    TimeEntry? activeEntry,
    MiniTrackerState state,
    AppThemeExtension theme,
    BuildContext context,
  ) {
    if (!isRunning || activeEntry == null) {
      return Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacings.md),
            child: Text(
              'No active session running.',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.secondary,
              ),
            ),
          ),
        ],
      );
    }

    if (!_commentFieldController.isEditing) {
      final persisted = activeEntry.comment ?? '';
      if (_commentController.text != persisted) {
        _commentController.text = persisted;
      }
    }
```

(The rest of the method, computing `task`/`project`/`taskName`/`projectName` and the `Container(...)` it returns, stays exactly as it is today.) Inside that returned `Container`'s inner `Column`, add the comment field right after the existing stop-button `Row` (after its closing `),` and before the outer `Column`'s closing `],`):

```dart
                  SizedBox(height: theme.spacings.lg),
                  InlineField(
                    label: 'Comment',
                    value: _commentController.text,
                    placeholder: 'Add a comment...',
                    controller: _commentFieldController,
                    textController: _commentController,
                    isTextArea: true,
                    viewModeMaxLines: 2,
                    editWidget: TextArea(
                      label: null,
                      hintText: 'Add a comment...',
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      autofocus: true,
                    ),
                  ),
```

- [ ] **Step 5: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/feature/desktop/presentation/mini_panel.dart
```

Expected: "No issues found!"

- [ ] **Step 6: Run the full test suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green (no behavior change to anything under test).

- [ ] **Step 7: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/text_area/text_area.dart apps/worklog_studio/lib/feature/desktop/presentation/mini_panel.dart
git commit -m "feat: add inline editable comment field to MiniPanel"
```

---

### Task 11: Settings screen - reminder interval + hotkey recorders

**Why:** No UI exists today to change the reminder interval or the three hotkey bindings; `settings_screen.dart` is otherwise stateless UI over existing services (backup/restore). This adds a new section following the same `OutlinedButton`/`Text`/`SizedBox` layout style already used for the "Backup" section.

**Files:**
- Modify: `apps/worklog_studio/lib/feature/settings/settings_screen.dart`

**Interfaces:**
- Consumes: `SqliteSettingsRepository` (Task 4), `HotkeyService.saveHotkey` (Task 8), `SettingsKeys` (Task 8), `hotkey_manager`'s `HotKeyRecorder` widget (confirmed in Task 1, Step 3).

This is UI-only - exempt from the mandatory-test rule. Verified by `fvm flutter analyze` and the manual checklist in Task 13.

- [ ] **Step 1: Add state and a settings repository accessor**

In `apps/worklog_studio/lib/feature/settings/settings_screen.dart`, add imports:

```dart
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
```

Add fields and an `initState` load to `_SettingsScreenState`, alongside the existing `_dbDirPath`/`_backupsDirPath`:

```dart
  final _settingsRepository = SqliteSettingsRepository();
  int? _reminderIntervalMinutes;

  HotkeyService? get _hotkeyService {
    try {
      return GetIt.I<HotkeyService>();
    } catch (_) {
      return null;
    }
  }
```

In `initState`, after the existing `_loadDirPaths();` call, add:

```dart
    _loadReminderInterval();
```

Add the loader method next to `_loadDirPaths`:

```dart
  Future<void> _loadReminderInterval() async {
    final minutes = await _settingsRepository.getInt(SettingsKeys.reminderIntervalMinutes);
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes);
  }

  Future<void> _setReminderInterval(int? minutes) async {
    if (minutes == null) {
      await _settingsRepository.setString(SettingsKeys.reminderIntervalMinutes, '0');
    } else {
      await _settingsRepository.setInt(SettingsKeys.reminderIntervalMinutes, minutes);
    }
    if (!mounted) return;
    setState(() => _reminderIntervalMinutes = minutes);
  }
```

(`'0'` represents "off", consistent with `ReminderService._startReminderTimer`'s `minutes <= 0` check from Task 9.)

- [ ] **Step 2: Add the section UI**

In `build`, after the existing "Backup" section's closing `Row(...)`'s `],`,`)`, (i.e. right after the backup buttons row and before the outer `Column`'s closing `],`), add:

```dart
          SizedBox(height: theme.spacings.x2l),
          Text('Floating comment tracker', style: theme.commonTextStyles.title), // TODO: l10n
          SizedBox(height: theme.spacings.md),
          Row(
            children: [
              Text('Reminder interval: ', style: theme.commonTextStyles.body), // TODO: l10n
              SizedBox(width: theme.spacings.sm),
              DropdownButton<int?>(
                value: _reminderIntervalMinutes == 0 ? null : _reminderIntervalMinutes,
                hint: const Text('Off'), // TODO: l10n
                items: const [
                  DropdownMenuItem(value: null, child: Text('Off')), // TODO: l10n
                  DropdownMenuItem(value: 1, child: Text('1 minute')), // TODO: l10n
                  DropdownMenuItem(value: 2, child: Text('2 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 5, child: Text('5 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 10, child: Text('10 minutes')), // TODO: l10n
                  DropdownMenuItem(value: 30, child: Text('30 minutes')), // TODO: l10n
                ],
                onChanged: _setReminderInterval,
              ),
            ],
          ),
          SizedBox(height: theme.spacings.md),
          _HotkeyRecorderRow(
            label: 'Toggle popover', // TODO: l10n
            settingKey: SettingsKeys.toggleHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Accept comment', // TODO: l10n
            settingKey: SettingsKeys.acceptHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
          SizedBox(height: theme.spacings.sm),
          _HotkeyRecorderRow(
            label: 'Dismiss comment', // TODO: l10n
            settingKey: SettingsKeys.dismissHotkey,
            repository: _settingsRepository,
            hotkeyService: _hotkeyService,
          ),
```

- [ ] **Step 3: Add the `_HotkeyRecorderRow` widget**

At the bottom of the file, after the existing `_DirectoryPathRow` class, add:

```dart
/// A label + `HotKeyRecorder` that persists the recorded combo through
/// [HotkeyService.saveHotkey] (which re-registers all three hotkeys
/// immediately) and falls back to writing straight through [repository]
/// when the service isn't available (e.g. running on a non-Windows target).
class _HotkeyRecorderRow extends StatefulWidget {
  final String label;
  final String settingKey;
  final SqliteSettingsRepository repository;
  final HotkeyService? hotkeyService;

  const _HotkeyRecorderRow({
    required this.label,
    required this.settingKey,
    required this.repository,
    required this.hotkeyService,
  });

  @override
  State<_HotkeyRecorderRow> createState() => _HotkeyRecorderRowState();
}

class _HotkeyRecorderRowState extends State<_HotkeyRecorderRow> {
  Future<void> _onRecorded(HotKey hotKey) async {
    final service = widget.hotkeyService;
    if (service != null) {
      await service.saveHotkey(widget.settingKey, hotKey);
    } else {
      await widget.repository.setString(
        widget.settingKey,
        jsonEncode(hotKey.toJson()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(widget.label, style: theme.commonTextStyles.body),
        ),
        SizedBox(width: theme.spacings.sm),
        SizedBox(
          width: 220,
          child: HotKeyRecorder(onHotKeyRecorded: _onRecorded),
        ),
      ],
    );
  }
}
```

Add the missing `dart:convert` import (for `jsonEncode`) at the top of the file alongside the other imports:

```dart
import 'dart:convert';
```

- [ ] **Step 4: Static analysis**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/feature/settings/settings_screen.dart
```

Expected: "No issues found!"

- [ ] **Step 5: Run the full test suite**

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/settings/settings_screen.dart
git commit -m "feat: add reminder interval and hotkey recorder settings UI"
```

---

### Task 12: Wire `HotkeyService` + `ReminderService` into `WindowsDesktopService`

**Files:**
- Modify: `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`

**Interfaces:**
- Consumes: `HotkeyService`/`HotkeyManagerRegistrar` (Task 8), `ReminderService` (Task 9), `SqliteSettingsRepository` (Task 4), `requestFocusComment`/`acceptCurrentComment`/`dismissCurrentComment` (Task 7).

No automated test - this is the leader-side bootstrap wiring real services together; `HotkeyService`/`ReminderService` already have their own unit coverage in isolation. Verified by static analysis, the full suite (compile-check), and Task 13's manual checklist.

- [ ] **Step 1: Add imports and fields**

In `apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart`, add imports:

```dart
import 'package:get_it/get_it.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/reminder_service.dart';
import 'package:worklog_studio/data/sqlite/sqlite_settings_repository.dart';
```

Add fields next to `_followerReady`:

```dart
  final _settingsRepository = SqliteSettingsRepository();
  HotkeyService? _hotkeyService;
  ReminderService? _reminderService;
```

- [ ] **Step 2: Initialise both services at the end of `initLeader`**

In `initLeader`, replace its final statement:

```dart
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });
  }
```

with:

```dart
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      await _handleIncomingIpcMessage(call.method, call.arguments);
      return null;
    });

    _hotkeyService = HotkeyService(
      registrar: HotkeyManagerRegistrar(),
      getSetting: _settingsRepository.getString,
      setSetting: _settingsRepository.setString,
      onToggle: togglePopover,
      onAccept: acceptCurrentComment,
      onDismiss: dismissCurrentComment,
    );
    await _hotkeyService!.init();
    if (GetIt.I.isRegistered<HotkeyService>()) {
      GetIt.I.unregister<HotkeyService>();
    }
    GetIt.I.registerSingleton<HotkeyService>(_hotkeyService!);

    _reminderService = ReminderService(
      bloc: bloc,
      getSetting: _settingsRepository.getString,
      onFire: () async {
        await showPopover();
        await requestFocusComment();
      },
      onAutoDismiss: dismissCurrentComment,
    );
    await _reminderService!.init();
  }
```

(`GetIt.I` is already a dependency via the `get_it` package, used elsewhere in the app - see `settings_screen.dart`'s `GetIt.I<BackupService>()` lookup, which Task 11's `_hotkeyService` getter mirrors.)

- [ ] **Step 3: Focus the comment field when the toggle hotkey opens the popover**

Replace `togglePopover`:

```dart
  @override
  Future<void> togglePopover() async {
    // _isPopoverVisible only ever gets corrected by our own hidePopover()
    // call. If the user destroyed the popover via its native close button
    // instead, _isPopoverVisible is left stuck at true even though nothing
    // is on screen - reconcile against the plugin's live-window list before
    // deciding which branch to take, or the first click after a close-via-X
    // would silently call hidePopover() on an already-dead window (a no-op)
    // instead of actually reopening it.
    await _reconcilePopoverState();
    if (_isPopoverVisible) {
      await hidePopover();
    } else {
      await showPopover();
      await requestFocusComment();
    }
  }
```

- [ ] **Step 4: Dispose both services**

Replace `dispose`:

```dart
  @override
  void dispose() {
    _hotkeyService?.dispose();
    _reminderService?.dispose();
    _blocSubscription?.cancel();
    WindowsTrayService().dispose();
    _navigationStreamController.close();
  }
```

- [ ] **Step 5: Static analysis and full suite**

```bash
cd apps/worklog_studio
fvm flutter analyze lib/core/services/desktop/windows_desktop_service.dart
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: "No issues found!" and all tests green.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/core/services/desktop/windows_desktop_service.dart
git commit -m "feat: wire HotkeyService and ReminderService into WindowsDesktopService"
```

---

### Task 13: Manual verification on Windows

**Files:** none (no code changes).

This task cannot be automated - it exercises real global hotkeys, OS-level focus, and timed reminders, none of which run inside `flutter test`. This plan's companion popover-infrastructure plan's own Task 7 must already pass (tray click opens/closes the popover correctly) before any of this is meaningful.

- [ ] **Step 1: Build and run the dev flavor**

```bash
cd apps/worklog_studio
fvm flutter run -d windows -t lib/main_development.dart
```

- [ ] **Step 2: Verify the toggle hotkey**

Start tracking a task from the main window. With the main window unfocused (click into some other application), press `Ctrl+Shift+M`. Expected: the popover opens anchored above the tray icon, and the active session's comment field is already in edit mode with keyboard focus (a cursor visible, ready to type).

Press `Ctrl+Shift+M` again. Expected: the popover closes.

- [ ] **Step 3: Verify the accept hotkey**

Press `Ctrl+Shift+M` to reopen, type a new comment into the focused field, then press `Ctrl+Shift+Enter`. Expected: the popover closes; reopening it (or checking the main window's active entry) shows the new comment persisted.

- [ ] **Step 4: Verify the dismiss hotkey**

Reopen the popover, type a different comment, then press `Ctrl+Shift+Escape`. Expected: the popover closes; the comment is unchanged from Step 3's accepted value (the in-progress edit was discarded).

- [ ] **Step 5: Verify the reminder**

In Settings, set the reminder interval to "1 minute". Start tracking a task, then leave the app alone (don't touch the popover) for slightly over a minute. Expected: the popover opens on its own with the comment field focused. Leave it alone for ~20 more seconds without typing. Expected: the popover closes on its own and the comment is unchanged (same discard-on-timeout behavior as Step 4).

- [ ] **Step 6: Verify hotkey customization**

In Settings, click the "Toggle popover" recorder and press a different combo (e.g. `Ctrl+Shift+K`). Expected: the old `Ctrl+Shift+M` binding stops working immediately and the new combo opens the popover. Restart the app and confirm the custom binding survived (read back from `app_settings`).

- [ ] **Step 7: Record the outcome**

If any step fails, root-cause it by reading the actual `hotkey_manager`/`desktop_multi_window` native source under the pub cache rather than guessing - the prior popover-infrastructure work was repeatedly miscorrected by assumptions about plugin behavior that turned out wrong on inspection. Use `systematic-debugging` for any such investigation.

