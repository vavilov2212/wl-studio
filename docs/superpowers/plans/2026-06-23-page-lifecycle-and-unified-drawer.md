# Page Lifecycle & Unified Drawer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop History/Projects/Tasks/Dashboard/Settings from staying permanently resident in memory, while keeping view-mode and filters across tab switches, and replace the three duplicated per-page drawers with one shared drawer host driven from a single controller — without breaking the existing `AppNavigationController` deep-link flow.

**Architecture:** Replace `AppShell`'s `IndexedStack` with a direct single-widget build so inactive pages are disposed; lift view-mode/filters into a new app-level `PageUiPreferences` `ChangeNotifier` so they survive page disposal; lift drawer state into a new app-level `DrawerHostController` `ChangeNotifier` rendered by one `AppDrawerHost` widget at `AppShell` level, replacing `TimeEntryDrawer`/`TaskDrawer`/`ProjectDrawer` being each instantiated per-page.

**Tech Stack:** Flutter, `provider` (`ChangeNotifier` + `ChangeNotifierProvider`/`MultiProvider`), `flutter_test`, existing `collection` package (`firstWhereOrNull`).

Spec: `docs/superpowers/specs/2026-06-23-page-lifecycle-and-unified-drawer-design.md`

## Global Constraints

- Windows-only dev environment; use `fvm` for all Flutter/Dart commands (never bare `flutter`/`dart`).
- Tests run via `fvm flutter test test/core/ test/feature/ --reporter expanded` from `apps/worklog_studio/`.
- New `ChangeNotifier` state classes (`PageUiPreferences`, `DrawerHostController`) are business/state-machine logic → TDD required, tests under `test/feature/`.
- Widget composition changes (page bodies, `AppShell`, `AppDrawerHost`) are UI-only per `apps/worklog_studio/CLAUDE.md` and are exempt from mandatory unit tests, but must not break the existing test suite and must be manually verified (final task).
- No new dependencies. No disk persistence. View-mode/filters/drawer state are in-memory, app-session-scoped only.
- Never run bare `flutter pub get`/`dart pub get`; this plan adds no new packages so no bootstrap step is needed.

---

### Task 1: `PageUiPreferences` — session-scoped view mode & filter store

**Files:**
- Create: `apps/worklog_studio/lib/state/page_ui_preferences.dart`
- Test: `apps/worklog_studio/test/feature/page_ui_preferences_test.dart`

**Interfaces:**
- Consumes: `HistoryViewMode` (`lib/feature/history/presentation/history_page.dart`), `HistoryFilters` (`lib/domain/history_filters.dart`), `TaskViewMode` (`lib/feature/tasks/presentation/tasks_page.dart`), `TasksFilters` (`lib/domain/tasks_filters.dart`), `ProjectViewMode` (`lib/feature/projects/presentation/projects_page.dart`), `ProjectsFilters` (`lib/domain/projects_filters.dart`).
- Produces: `PageUiPreferences` class with fields `historyViewMode`, `historyFilters`, `historyFilterExpandedOverride`, `tasksViewMode`, `tasksFilters`, `tasksFilterExpandedOverride`, `projectsViewMode`, `projectsFilters`, `projectsFilterExpandedOverride`, and setters `setHistoryViewMode(HistoryViewMode)`, `setHistoryFilters(HistoryFilters)`, `setHistoryFilterExpandedOverride(bool?)`, `setTasksViewMode(TaskViewMode)`, `setTasksFilters(TasksFilters)`, `setTasksFilterExpandedOverride(bool?)`, `setProjectsViewMode(ProjectViewMode)`, `setProjectsFilters(ProjectsFilters)`, `setProjectsFilterExpandedOverride(bool?)`. Used by Tasks 6-8.

- [ ] **Step 1: Write the failing test**

```dart
// apps/worklog_studio/test/feature/page_ui_preferences_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';

void main() {
  group('PageUiPreferences', () {
    test('defaults to table view mode and empty filters for every page', () {
      final prefs = PageUiPreferences();

      expect(prefs.historyViewMode, HistoryViewMode.table);
      expect(prefs.historyFilters.taskIds, isEmpty);
      expect(prefs.historyFilterExpandedOverride, isNull);

      expect(prefs.tasksViewMode, TaskViewMode.table);
      expect(prefs.tasksFilters.activeCount, 0);
      expect(prefs.tasksFilterExpandedOverride, isNull);

      expect(prefs.projectsViewMode, ProjectViewMode.table);
      expect(prefs.projectsFilters.activeCount, 0);
      expect(prefs.projectsFilterExpandedOverride, isNull);
    });

    test('setHistoryViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryViewMode(HistoryViewMode.cards);

      expect(prefs.historyViewMode, HistoryViewMode.cards);
      expect(notified, isTrue);
    });

    test('setHistoryFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryFilters(const HistoryFilters(taskIds: {'t1'}));

      expect(prefs.historyFilters.taskIds, {'t1'});
      expect(notified, isTrue);
    });

    test('setHistoryFilterExpandedOverride updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistoryFilterExpandedOverride(true);

      expect(prefs.historyFilterExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setTasksViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setTasksViewMode(TaskViewMode.cards);

      expect(prefs.tasksViewMode, TaskViewMode.cards);
      expect(notified, isTrue);
    });

    test('setTasksFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();

      prefs.setTasksFilters(const TasksFilters(projectIds: {'p1'}));

      expect(prefs.tasksFilters.projectIds, {'p1'});
    });

    test('setTasksFilterExpandedOverride updates the value', () {
      final prefs = PageUiPreferences();

      prefs.setTasksFilterExpandedOverride(false);

      expect(prefs.tasksFilterExpandedOverride, isFalse);
    });

    test('setProjectsViewMode updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setProjectsViewMode(ProjectViewMode.cards);

      expect(prefs.projectsViewMode, ProjectViewMode.cards);
      expect(notified, isTrue);
    });

    test('setProjectsFilters updates the value and notifies listeners', () {
      final prefs = PageUiPreferences();

      prefs.setProjectsFilters(const ProjectsFilters());

      expect(prefs.projectsFilters.activeCount, 0);
    });

    test('setProjectsFilterExpandedOverride updates the value', () {
      final prefs = PageUiPreferences();

      prefs.setProjectsFilterExpandedOverride(true);

      expect(prefs.projectsFilterExpandedOverride, isTrue);
    });

    test('updating one page key does not affect the others', () {
      final prefs = PageUiPreferences();

      prefs.setHistoryViewMode(HistoryViewMode.cards);
      prefs.setHistoryFilters(const HistoryFilters(taskIds: {'t1'}));

      expect(prefs.tasksViewMode, TaskViewMode.table);
      expect(prefs.tasksFilters.projectIds, isEmpty);
      expect(prefs.projectsViewMode, ProjectViewMode.table);
      expect(prefs.projectsFilters.activeCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `apps/worklog_studio/`): `fvm flutter test test/feature/page_ui_preferences_test.dart -r expanded`
Expected: FAIL — `Error: Couldn't resolve the package 'worklog_studio/state/page_ui_preferences.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/worklog_studio/lib/state/page_ui_preferences.dart
import 'package:flutter/foundation.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';

/// Session-scoped (in-memory, lost on app restart) view-mode and filter
/// state for History/Tasks/Projects, lifted out of the page widgets so it
/// survives the pages being disposed when the user switches tabs.
class PageUiPreferences extends ChangeNotifier {
  HistoryViewMode _historyViewMode = HistoryViewMode.table;
  HistoryFilters _historyFilters = const HistoryFilters();
  bool? _historyFilterExpandedOverride;

  TaskViewMode _tasksViewMode = TaskViewMode.table;
  TasksFilters _tasksFilters = const TasksFilters();
  bool? _tasksFilterExpandedOverride;

  ProjectViewMode _projectsViewMode = ProjectViewMode.table;
  ProjectsFilters _projectsFilters = const ProjectsFilters();
  bool? _projectsFilterExpandedOverride;

  HistoryViewMode get historyViewMode => _historyViewMode;
  HistoryFilters get historyFilters => _historyFilters;
  bool? get historyFilterExpandedOverride => _historyFilterExpandedOverride;

  TaskViewMode get tasksViewMode => _tasksViewMode;
  TasksFilters get tasksFilters => _tasksFilters;
  bool? get tasksFilterExpandedOverride => _tasksFilterExpandedOverride;

  ProjectViewMode get projectsViewMode => _projectsViewMode;
  ProjectsFilters get projectsFilters => _projectsFilters;
  bool? get projectsFilterExpandedOverride => _projectsFilterExpandedOverride;

  void setHistoryViewMode(HistoryViewMode mode) {
    _historyViewMode = mode;
    notifyListeners();
  }

  void setHistoryFilters(HistoryFilters filters) {
    _historyFilters = filters;
    notifyListeners();
  }

  void setHistoryFilterExpandedOverride(bool? value) {
    _historyFilterExpandedOverride = value;
    notifyListeners();
  }

  void setTasksViewMode(TaskViewMode mode) {
    _tasksViewMode = mode;
    notifyListeners();
  }

  void setTasksFilters(TasksFilters filters) {
    _tasksFilters = filters;
    notifyListeners();
  }

  void setTasksFilterExpandedOverride(bool? value) {
    _tasksFilterExpandedOverride = value;
    notifyListeners();
  }

  void setProjectsViewMode(ProjectViewMode mode) {
    _projectsViewMode = mode;
    notifyListeners();
  }

  void setProjectsFilters(ProjectsFilters filters) {
    _projectsFilters = filters;
    notifyListeners();
  }

  void setProjectsFilterExpandedOverride(bool? value) {
    _projectsFilterExpandedOverride = value;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/feature/page_ui_preferences_test.dart -r expanded`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/state/page_ui_preferences.dart apps/worklog_studio/test/feature/page_ui_preferences_test.dart
git commit -m "Add PageUiPreferences store for cross-navigation view mode and filters"
```

---

### Task 2: `DrawerHostController` — unified drawer state

**Files:**
- Create: `apps/worklog_studio/lib/state/drawer_host_controller.dart`
- Test: `apps/worklog_studio/test/feature/drawer_host_controller_test.dart`

**Interfaces:**
- Consumes: `DrawerState` enum (`lib/feature/common/presentation/drawer_controller_state.dart`), `TimeEntry` (`lib/domain/time_entry.dart`), `Task` (`lib/domain/task.dart`), `Project` (`lib/domain/project.dart`).
- Produces: `DrawerEntityKind` enum (`none`, `timeEntry`, `task`, `project`); `DrawerHostController` class with `kind`, `isOpen`, `timeEntry`, `task`, `project` getters and `openTimeEntryEdit(TimeEntry)`, `openTimeEntryCreate()`, `openTaskEdit(Task)`, `openTaskCreate()`, `openProjectEdit(Project)`, `openProjectCreate()`, `close()`. Used by Tasks 4, 5, 6, 7, 8.

- [ ] **Step 1: Write the failing test**

```dart
// apps/worklog_studio/test/feature/drawer_host_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';

void main() {
  final entry = TimeEntry(
    id: 'e1',
    projectId: 'p1',
    taskId: 't1',
    startAt: DateTime(2026, 1, 1, 9),
    endAt: DateTime(2026, 1, 1, 10),
    status: TimeEntryStatus.stopped,
  );
  final task = Task(
    id: 't1',
    projectId: 'p1',
    title: 'Task 1',
    description: '',
    status: TaskStatus.open,
    createdAt: DateTime(2026, 1, 1),
  );
  final project = Project(
    id: 'p1',
    name: 'Project 1',
    description: '',
    createdAt: DateTime(2026, 1, 1),
    status: ProjectStatus.open,
  );

  group('DrawerHostController', () {
    test('starts closed with no entity', () {
      final controller = DrawerHostController();

      expect(controller.kind, DrawerEntityKind.none);
      expect(controller.isOpen, isFalse);
      expect(controller.timeEntry, isNull);
      expect(controller.task, isNull);
      expect(controller.project, isNull);
    });

    test('openTimeEntryEdit opens with the given entry and notifies', () {
      final controller = DrawerHostController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.openTimeEntryEdit(entry);

      expect(controller.kind, DrawerEntityKind.timeEntry);
      expect(controller.isOpen, isTrue);
      expect(controller.timeEntry, entry);
      expect(controller.task, isNull);
      expect(controller.project, isNull);
      expect(notified, isTrue);
    });

    test('openTimeEntryCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openTimeEntryCreate();

      expect(controller.kind, DrawerEntityKind.timeEntry);
      expect(controller.isOpen, isTrue);
      expect(controller.timeEntry, isNull);
    });

    test('openTaskEdit opens with the given task', () {
      final controller = DrawerHostController();

      controller.openTaskEdit(task);

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.isOpen, isTrue);
      expect(controller.task, task);
      expect(controller.timeEntry, isNull);
    });

    test('openTaskCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openTaskCreate();

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.isOpen, isTrue);
      expect(controller.task, isNull);
    });

    test('openProjectEdit opens with the given project', () {
      final controller = DrawerHostController();

      controller.openProjectEdit(project);

      expect(controller.kind, DrawerEntityKind.project);
      expect(controller.isOpen, isTrue);
      expect(controller.project, project);
      expect(controller.task, isNull);
    });

    test('openProjectCreate opens with no entity', () {
      final controller = DrawerHostController();

      controller.openProjectCreate();

      expect(controller.kind, DrawerEntityKind.project);
      expect(controller.isOpen, isTrue);
      expect(controller.project, isNull);
    });

    test('opening a different kind clears the previous kind entity', () {
      final controller = DrawerHostController();

      controller.openTimeEntryEdit(entry);
      controller.openTaskEdit(task);

      expect(controller.kind, DrawerEntityKind.task);
      expect(controller.timeEntry, isNull);
      expect(controller.task, task);
    });

    test('close resets to none/closed and notifies', () {
      final controller = DrawerHostController();
      controller.openProjectEdit(project);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.close();

      expect(controller.kind, DrawerEntityKind.none);
      expect(controller.isOpen, isFalse);
      expect(controller.project, isNull);
      expect(notified, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/feature/drawer_host_controller_test.dart -r expanded`
Expected: FAIL — `drawer_host_controller.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps/worklog_studio/lib/state/drawer_host_controller.dart
import 'package:flutter/foundation.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/common/presentation/drawer_controller_state.dart';

enum DrawerEntityKind { none, timeEntry, task, project }

/// Single app-level drawer state, replacing the three independent
/// per-page DrawerControllerState<T> instances. Only one entity (or none)
/// can be open at a time, in one of the three DrawerState modes
/// (closed/create/edit) the existing drawer widgets already understand.
class DrawerHostController extends ChangeNotifier {
  DrawerEntityKind _kind = DrawerEntityKind.none;
  DrawerState _mode = DrawerState.closed;
  Object? _entity;

  DrawerEntityKind get kind => _kind;
  bool get isOpen => _mode != DrawerState.closed;

  TimeEntry? get timeEntry =>
      _kind == DrawerEntityKind.timeEntry ? _entity as TimeEntry? : null;
  Task? get task => _kind == DrawerEntityKind.task ? _entity as Task? : null;
  Project? get project =>
      _kind == DrawerEntityKind.project ? _entity as Project? : null;

  void openTimeEntryEdit(TimeEntry entry) {
    _kind = DrawerEntityKind.timeEntry;
    _mode = DrawerState.edit;
    _entity = entry;
    notifyListeners();
  }

  void openTimeEntryCreate() {
    _kind = DrawerEntityKind.timeEntry;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void openTaskEdit(Task task) {
    _kind = DrawerEntityKind.task;
    _mode = DrawerState.edit;
    _entity = task;
    notifyListeners();
  }

  void openTaskCreate() {
    _kind = DrawerEntityKind.task;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void openProjectEdit(Project project) {
    _kind = DrawerEntityKind.project;
    _mode = DrawerState.edit;
    _entity = project;
    notifyListeners();
  }

  void openProjectCreate() {
    _kind = DrawerEntityKind.project;
    _mode = DrawerState.create;
    _entity = null;
    notifyListeners();
  }

  void close() {
    _kind = DrawerEntityKind.none;
    _mode = DrawerState.closed;
    _entity = null;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/feature/drawer_host_controller_test.dart -r expanded`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/state/drawer_host_controller.dart apps/worklog_studio/test/feature/drawer_host_controller_test.dart
git commit -m "Add DrawerHostController for unified drawer state"
```

---

### Task 3: Wire `PageUiPreferences` and `DrawerHostController` into the app

**Files:**
- Modify: `apps/worklog_studio/lib/feature/app/app.dart:64-115`

**Interfaces:**
- Consumes: `PageUiPreferences` (Task 1), `DrawerHostController` (Task 2).
- Produces: both available via `context.read`/`context.watch` anywhere under `MainApp`. Used by Tasks 5-8.

- [ ] **Step 1: Add imports and providers**

In `apps/worklog_studio/lib/feature/app/app.dart`, add imports near the other `worklog_studio/state/...` imports:

```dart
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
```

Add two providers to the `providers` list in `MainApp.build` (`app.dart:64-115`), alongside the existing `Provider<AppNavigationController>`:

```dart
        Provider<AppNavigationController>(
          create: (_) => AppNavigationController(),
        ),
        ChangeNotifierProvider(create: (_) => PageUiPreferences()),
        ChangeNotifierProvider(create: (_) => DrawerHostController()),
```

- [ ] **Step 2: Verify the app still compiles**

Run (from `apps/worklog_studio/`): `fvm flutter analyze lib/feature/app/app.dart`
Expected: No errors (the two new providers are unused by anything yet — that's fine, later tasks consume them).

- [ ] **Step 3: Run full test suite to confirm no regressions**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All existing tests still PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/app.dart
git commit -m "Provide PageUiPreferences and DrawerHostController at the app root"
```

---

### Task 4: `AppDrawerHost` — single shared drawer widget

**Files:**
- Create: `apps/worklog_studio/lib/feature/app/layout/app_drawer_host.dart`

**Interfaces:**
- Consumes: `DrawerHostController`/`DrawerEntityKind` (Task 2), `EntityResolver.getResolvedTimeEntries()` (`lib/state/entity_resolver.dart`), `TimeEntryDrawer` (`lib/feature/history/presentation/components/time_entry_drawer.dart`), `TaskDrawer` (`lib/feature/tasks/presentation/components/tasks_drawer.dart`), `ProjectDrawer` (`lib/feature/projects/presentation/components/project_drawer.dart`).
- Produces: `AppDrawerHost` widget, a `StatelessWidget` with no constructor params besides `key`. Used by Task 5.

- [ ] **Step 1: Create the widget**

```dart
// apps/worklog_studio/lib/feature/app/layout/app_drawer_host.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_drawer.dart';
import 'package:worklog_studio/feature/projects/presentation/components/project_drawer.dart';
import 'package:worklog_studio/feature/tasks/presentation/components/tasks_drawer.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

/// Single drawer instance shared by History/Tasks/Projects, driven by
/// [DrawerHostController] instead of each page owning its own drawer.
/// Mounted once at the AppShell level so it survives page disposal.
class AppDrawerHost extends StatelessWidget {
  const AppDrawerHost({super.key});

  @override
  Widget build(BuildContext context) {
    final drawer = context.watch<DrawerHostController>();

    switch (drawer.kind) {
      case DrawerEntityKind.timeEntry:
        final entry = drawer.timeEntry;
        final resolvedEntry = entry == null
            ? null
            : context
                .watch<EntityResolver>()
                .getResolvedTimeEntries()
                .firstWhereOrNull((e) => e.entry.id == entry.id);
        return TimeEntryDrawer(
          resolvedEntry: resolvedEntry,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.task:
        return TaskDrawer(
          task: drawer.task,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.project:
        return ProjectDrawer(
          project: drawer.project,
          isOpen: drawer.isOpen,
          onClose: drawer.close,
        );
      case DrawerEntityKind.none:
        return const SizedBox.shrink();
    }
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/feature/app/layout/app_drawer_host.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/layout/app_drawer_host.dart
git commit -m "Add AppDrawerHost widget driven by DrawerHostController"
```

---

### Task 5: Refactor `AppShell` — lazy page switcher + drawer host + simplified deep-links

**Files:**
- Modify: `apps/worklog_studio/lib/feature/app/layout/app_shell.dart:1-152`

**Interfaces:**
- Consumes: `AppDrawerHost` (Task 4), `DrawerHostController` (Task 2), `EntityResolver` (existing).
- Produces: `HistoryScreen()`, `TasksScreen()`, `ProjectsScreen()` are now constructed with no constructor args (their `initialSelectedEntryId`/`createRequestToken`/`initialSelectedTaskId`/`initialSelectedProjectId` params are removed in Tasks 6-8 — this task drops the call sites first). Until Tasks 6-8 land, those three widgets still declare the old optional params, so passing none is valid Dart (they default to `null`/`0`) — no compile break in between tasks.

- [ ] **Step 1: Replace the `_AppShellState` fields and handlers**

In `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`, replace lines 34-122 (the entire `_AppShellState` body from field declarations through `_buildActiveScreen`) with:

```dart
class _AppShellState extends State<AppShell> {
  AppRoute _currentRoute = AppRoute.dashboard;
  StreamSubscription<String>? _navSub;

  @override
  void initState() {
    super.initState();
    context.read<AppNavigationController>().registerHandlers(
      openTask: _openTask,
      openProject: _openProject,
      openHistoryEntry: _openHistoryEntry,
    );
    _navSub = DesktopServiceRegistry.instance.navigationStream.listen((route) {
      if (route == 'history') {
        _onRouteSelected(AppRoute.history);
      } else if (route == 'tasks') {
        _onRouteSelected(AppRoute.tasks);
      } else if (route == 'projects') {
        _onRouteSelected(AppRoute.projects);
      }
    });
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  /// Plain tab switch — no entity carried over, so the shared drawer closes.
  void _onRouteSelected(AppRoute route) {
    context.read<DrawerHostController>().close();
    setState(() {
      _currentRoute = route;
    });
  }

  /// Deep-link navigation — resolves the entity and opens the shared drawer
  /// *before* switching tabs, so the freshly-mounted page already sees it.
  void _openHistoryEntry(String entryId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTimeEntries()
        .firstWhereOrNull((e) => e.entry.id == entryId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTimeEntryEdit(resolved.entry);
    }
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openHistoryCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
    setState(() {
      _currentRoute = AppRoute.history;
    });
  }

  void _openTask(String taskId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedTasks()
        .firstWhereOrNull((t) => t.id == taskId);
    if (resolved != null) {
      context.read<DrawerHostController>().openTaskEdit(resolved.task);
    }
    setState(() {
      _currentRoute = AppRoute.tasks;
    });
  }

  void _openProject(String projectId) {
    final resolved = context
        .read<EntityResolver>()
        .getResolvedProjects()
        .firstWhereOrNull((p) => p.id == projectId);
    if (resolved != null) {
      context.read<DrawerHostController>().openProjectEdit(resolved.project);
    }
    setState(() {
      _currentRoute = AppRoute.projects;
    });
  }

  /// Builds only the active page. Replacing the previous IndexedStack means
  /// the previous page's widget leaves the tree and Flutter disposes it —
  /// this is the fix for pages staying resident in memory forever.
  Widget _buildActiveScreen() {
    switch (_currentRoute) {
      case AppRoute.dashboard:
        return HomePage(
          title: 'Dashboard',
          onViewAllTasks: () => _onRouteSelected(AppRoute.tasks),
          onViewAllHistory: () => _onRouteSelected(AppRoute.history),
          onSelectHistoryEntry: _openHistoryEntry,
          onAddTimeEntry: _openHistoryCreateEntry,
          onSelectTask: _openTask,
        );
      case AppRoute.history:
        return const HistoryScreen();
      case AppRoute.projects:
        return const ProjectsScreen();
      case AppRoute.tasks:
        return const TasksScreen();
      case AppRoute.settings:
        return const SettingsScreen();
    }
  }
```

- [ ] **Step 2: Add the drawer host next to the active screen in `build()`**

Replace the `Expanded(child: _buildActiveScreen())` line inside `build()` (`app_shell.dart`, originally line 144) with:

```dart
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildActiveScreen()),
                      const AppDrawerHost(),
                    ],
                  ),
                ),
```

- [ ] **Step 3: Add the new import**

```dart
import 'package:worklog_studio/feature/app/layout/app_drawer_host.dart';
```

- [ ] **Step 4: Verify it compiles**

Run: `fvm flutter analyze lib/feature/app/layout/app_shell.dart`
Expected: No errors. (`HistoryScreen`/`TasksScreen`/`ProjectsScreen` still have their old optional constructor params at this point — calling them with none is valid.)

- [ ] **Step 5: Run full test suite to confirm no regressions**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All existing tests PASS (`app_navigation_controller_test.dart` is unaffected — `AppNavigationController` itself didn't change, only what `AppShell` does with it).

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/layout/app_shell.dart
git commit -m "Replace IndexedStack with lazy page switcher and unified drawer host in AppShell"
```

---

### Task 6: Migrate `HistoryScreen` to `PageUiPreferences` + `DrawerHostController`

**Files:**
- Modify: `apps/worklog_studio/lib/feature/history/presentation/history_page.dart:1-153`

**Interfaces:**
- Consumes: `PageUiPreferences` (Task 1), `DrawerHostController`/`DrawerEntityKind` (Task 2).
- Produces: `HistoryScreen` with a no-arg `const HistoryScreen({super.key})` constructor (matches the call site from Task 5). `TimeEntryList` (lines 155-181) is unchanged — same constructor signature.

- [ ] **Step 1: Replace `HistoryScreen` and `_HistoryScreenState`**

Replace lines 1-153 of `history_page.dart` (everything from the imports through the closing `}` of `_HistoryScreenState`) with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/time_entry_card.dart';
import 'components/time_entry_actions_cell.dart';
import 'components/history_filter_bar.dart';

enum HistoryViewMode { cards, table }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.timeEntry && drawer.timeEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

  void _handleEntrySelected(TimeEntry entry) {
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.timeEntry &&
        drawer.timeEntry?.id == entry.id) {
      drawer.close(); // Toggle off
    } else {
      drawer.openTimeEntryEdit(entry);
    }
  }

  void _handleCreateEntry() {
    context.read<DrawerHostController>().openTimeEntryCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEntries = context
        .watch<EntityResolver>()
        .getResolvedTimeEntries();
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedEntry =
        drawer.kind == DrawerEntityKind.timeEntry ? drawer.timeEntry : null;
    final isFilterExpanded =
        prefs.historyFilterExpandedOverride ?? prefs.historyFilters.isActive;

    return TimeEntryList(
      entries: resolvedEntries,
      selectedEntry: selectedEntry,
      selectedRowKey: _selectedRowKey,
      onEntrySelected: _handleEntrySelected,
      onCreateEntry: _handleCreateEntry,
      viewMode: prefs.historyViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setHistoryViewMode(mode),
      filters: prefs.historyFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setHistoryFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setHistoryFilterExpandedOverride(!isFilterExpanded),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/feature/history/presentation/history_page.dart`
Expected: No errors. (`TimeEntryList` below in the same file is untouched and still matches this call site.)

- [ ] **Step 3: Run full test suite to confirm no regressions**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All tests PASS (`history_filters_test.dart` is untouched — `HistoryFilters` itself didn't change).

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/feature/history/presentation/history_page.dart
git commit -m "Migrate HistoryScreen to PageUiPreferences and DrawerHostController"
```

---

### Task 7: Migrate `TasksScreen` to `PageUiPreferences` + `DrawerHostController`

**Files:**
- Modify: `apps/worklog_studio/lib/feature/tasks/presentation/tasks_page.dart:1-132`

**Interfaces:**
- Consumes: `PageUiPreferences` (Task 1), `DrawerHostController`/`DrawerEntityKind` (Task 2).
- Produces: `TasksScreen` with a no-arg `const TasksScreen({super.key})` constructor (matches the call site from Task 5). `TaskList` (line 134 onward) is unchanged.

- [ ] **Step 1: Replace `TasksScreen` and `_TasksScreenState`**

Replace lines 1-132 of `tasks_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/tasks_card.dart';
import 'components/tasks_filter_bar.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/task_actions_cell.dart';

enum TaskViewMode { cards, table }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.task && drawer.task != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

  void _handleTaskSelected(Task task) {
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.task && drawer.task?.id == task.id) {
      drawer.close();
    } else {
      drawer.openTaskEdit(task);
    }
  }

  void _handleCreateTask() {
    context.read<DrawerHostController>().openTaskCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTasks = context.watch<EntityResolver>().getResolvedTasks();
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedTask =
        drawer.kind == DrawerEntityKind.task ? drawer.task : null;
    final isFilterExpanded =
        prefs.tasksFilterExpandedOverride ?? prefs.tasksFilters.isActive;

    return TaskList(
      tasks: resolvedTasks,
      selectedTask: selectedTask,
      selectedRowKey: _selectedRowKey,
      onTaskSelected: _handleTaskSelected,
      onCreateTask: _handleCreateTask,
      viewMode: prefs.tasksViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setTasksViewMode(mode),
      filters: prefs.tasksFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setTasksFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setTasksFilterExpandedOverride(!isFilterExpanded),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/feature/tasks/presentation/tasks_page.dart`
Expected: No errors.

- [ ] **Step 3: Run full test suite to confirm no regressions**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All tests PASS (`tasks_filters_test.dart` untouched).

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/feature/tasks/presentation/tasks_page.dart
git commit -m "Migrate TasksScreen to PageUiPreferences and DrawerHostController"
```

---

### Task 8: Migrate `ProjectsScreen` to `PageUiPreferences` + `DrawerHostController`

**Files:**
- Modify: `apps/worklog_studio/lib/feature/projects/presentation/projects_page.dart:1-132`

**Interfaces:**
- Consumes: `PageUiPreferences` (Task 1), `DrawerHostController`/`DrawerEntityKind` (Task 2).
- Produces: `ProjectsScreen` with a no-arg `const ProjectsScreen({super.key})` constructor (matches the call site from Task 5). `ProjectList` (line 134 onward) is unchanged.

- [ ] **Step 1: Replace `ProjectsScreen` and `_ProjectsScreenState`**

Replace lines 1-132 of `projects_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/page_ui_preferences.dart';
import 'package:worklog_studio/state/drawer_host_controller.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'components/project_card.dart';
import 'components/projects_filter_bar.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';
import 'components/project_actions_cell.dart';

enum ProjectViewMode { cards, table }

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final GlobalKey _selectedRowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.project && drawer.project != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final rowContext = _selectedRowKey.currentContext;
        if (rowContext != null) {
          Scrollable.ensureVisible(
            rowContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      });
    }
  }

  void _handleProjectSelected(Project project) {
    final drawer = context.read<DrawerHostController>();
    if (drawer.kind == DrawerEntityKind.project &&
        drawer.project?.id == project.id) {
      drawer.close();
    } else {
      drawer.openProjectEdit(project);
    }
  }

  void _handleCreateProject() {
    context.read<DrawerHostController>().openProjectCreate();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedProjects = context
        .watch<EntityResolver>()
        .getResolvedProjects();
    final prefs = context.watch<PageUiPreferences>();
    final drawer = context.watch<DrawerHostController>();
    final selectedProject =
        drawer.kind == DrawerEntityKind.project ? drawer.project : null;
    final isFilterExpanded =
        prefs.projectsFilterExpandedOverride ?? prefs.projectsFilters.isActive;

    return ProjectList(
      projects: resolvedProjects,
      selectedProject: selectedProject,
      selectedRowKey: _selectedRowKey,
      onProjectSelected: _handleProjectSelected,
      onCreateProject: _handleCreateProject,
      viewMode: prefs.projectsViewMode,
      onViewModeChanged: (mode) =>
          context.read<PageUiPreferences>().setProjectsViewMode(mode),
      filters: prefs.projectsFilters,
      onFiltersChanged: (f) =>
          context.read<PageUiPreferences>().setProjectsFilters(f),
      isFilterExpanded: isFilterExpanded,
      onFilterExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setProjectsFilterExpandedOverride(!isFilterExpanded),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/feature/projects/presentation/projects_page.dart`
Expected: No errors.

- [ ] **Step 3: Run full test suite to confirm no regressions**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All tests PASS (`projects_filters_test.dart` untouched).

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/feature/projects/presentation/projects_page.dart
git commit -m "Migrate ProjectsScreen to PageUiPreferences and DrawerHostController"
```

---

### Task 9: Full-suite check and manual verification

**Files:** none (verification only).

**Interfaces:** none — this task exercises the integrated behavior from Tasks 1-8.

- [ ] **Step 1: Run the full automated test suite**

Run (from `apps/worklog_studio/`): `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: All tests PASS, including the new `page_ui_preferences_test.dart` and `drawer_host_controller_test.dart` from Tasks 1-2.

- [ ] **Step 2: Run static analysis on the full app**

Run: `fvm flutter analyze`
Expected: No errors (warnings pre-existing and unrelated to this change are acceptable).

- [ ] **Step 3: Launch the app and manually verify each behavior from the design**

Run: `fvm flutter run -d windows` (or the project's usual `build-windows`/run flow).

Check each of the following:
1. Open History, switch to a table/cards toggle and apply a filter, switch to Tasks, switch back to History — view mode and filter are still applied (Part 1 of the design).
2. Open History, select a row (drawer opens), switch to Projects — drawer is closed when you arrive on Projects, and stays closed if you switch back to History (Part 2, reset rule).
3. From the Dashboard, click a task in a "recent tasks" widget that calls `onSelectTask` — Tasks tab opens with that task's drawer already open and the row scrolled into view (deep-link flow, Part 2 items 5-6).
4. From the top app bar, use the project/task selectors' "Open project"/"Open task" action — same deep-link check for Projects and Tasks.
5. Click "New Entry"/"New Task"/"New Project" on each page — drawer opens in create mode (blank draft, matching pre-refactor behavior).
6. Toggle the filter-expanded chevron on each page, navigate away and back — expanded/collapsed state is preserved.

- [ ] **Step 4: Report results**

If all checks pass, this plan is complete. If any check fails, file it as a fix-up task referencing the specific step above before considering the plan done — do not silently patch around it without updating the relevant task's code.
