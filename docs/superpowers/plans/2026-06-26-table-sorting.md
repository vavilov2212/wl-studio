# Table Sorting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interactive sorting (field + direction) to the History, Tasks, and Projects tables, replacing the disabled sort icon in `TableToolbar` with a working inline sort bar.

**Architecture:** Each page gets a sort-field enum and a pure `applyXSort()` function (mirroring the existing `XFilters`/`applyXFilters()` pattern). Sort state (field, direction, bar-expanded) lives in the existing session-scoped `PageUiPreferences` `ChangeNotifier`, mirroring its existing filter-expanded-override fields. The shared `TableToolbar` widget gets its disabled sort icon wired up to toggle a new inline `XSortBar` widget per page (same expand/collapse mechanics as the existing `XFilterBar`). History's date-grouping is preserved only when sorting by Date; any other sort field flattens History into one ungrouped list.

**Tech Stack:** Flutter (fvm-pinned SDK), `provider` for state, existing `worklog_studio_style_system` UI kit (`Select`, `SelectOption`, `PrimaryButton`, `TableToolbar`).

## Global Constraints

- Windows-only paths (backslashes) when running shell commands; this plan uses forward slashes only inside Dart import strings, which is correct Dart syntax on every OS.
- Never run bare `flutter`/`dart` — always `fvm flutter ...` / `fvm dart ...`.
- Run tests from `apps\worklog_studio\` with `fvm flutter test test/core/ test/feature/ --reporter expanded`.
- New business logic (the `applyXSort` functions, `PageUiPreferences` setters) requires a failing test first (TDD), per `apps\worklog_studio\CLAUDE.md`. New widgets (`XSortBar`, `TableToolbar` prop additions) are UI-only and exempt.
- Do not touch `.freezed.dart`/`.g.dart`, `build\`, `.dart_tool\`, `.fvm\`.
- No em dash / en dash in any generated text, code, comments, or commit messages — use a plain hyphen.
- Never add `Co-Authored-By: Claude` to commit messages in this repo.
- Sort state is session-scoped (in-memory only), matching the existing `PageUiPreferences` doc comment — no persistence work.

---

### Task 1: History sort domain logic

**Files:**
- Create: `apps\worklog_studio\lib\domain\sort_direction.dart`
- Create: `apps\worklog_studio\lib\domain\history_sort.dart`
- Test: `apps\worklog_studio\test\core\history_sort_test.dart`

**Interfaces:**
- Produces: `enum SortDirection { asc, desc }` (shared by all three pages' sort files).
- Produces: `enum HistorySortField { date, duration, taskProjectName }`
- Produces: `List<ResolvedTimeEntry> applyHistorySort(List<ResolvedTimeEntry> entries, HistorySortField field, SortDirection direction)` — pure, does not mutate the input list, does not group by date.

- [ ] **Step 1: Write the failing test**

```dart
// apps\worklog_studio\test\core\history_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTimeEntry _entry({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
  bool running = false,
  String taskTitle = 'Task',
  String projectName = 'Project',
}) {
  return ResolvedTimeEntry(
    entry: TimeEntry(
      id: id,
      taskId: 't-$id',
      projectId: 'p-$id',
      startAt: startAt,
      endAt: endAt,
      status: running ? TimeEntryStatus.running : TimeEntryStatus.stopped,
    ),
    task: Task(
      id: 't-$id',
      projectId: 'p-$id',
      title: taskTitle,
      description: '',
      status: TaskStatus.open,
      createdAt: startAt,
    ),
    project: Project(id: 'p-$id', name: projectName, description: '', createdAt: startAt),
  );
}

void main() {
  group('applyHistorySort', () {
    final jan1 = DateTime(2026, 1, 1, 9);
    final jan2 = DateTime(2026, 1, 2, 9);
    final jan3 = DateTime(2026, 1, 3, 9);

    test('date desc returns latest startAt first', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
        _entry(id: 'c', startAt: jan2),
      ];

      final result = applyHistorySort(entries, HistorySortField.date, SortDirection.desc);

      expect(result.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('date asc returns earliest startAt first', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
        _entry(id: 'c', startAt: jan2),
      ];

      final result = applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(result.map((e) => e.id), ['a', 'c', 'b']);
    });

    test('date sort pins running entries to the top regardless of direction', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'running', startAt: jan1, running: true),
        _entry(id: 'b', startAt: jan3),
      ];

      final desc = applyHistorySort(entries, HistorySortField.date, SortDirection.desc);
      final asc = applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(desc.first.id, 'running');
      expect(asc.first.id, 'running');
    });

    test('duration desc returns longest duration first, no running pin', () {
      final entries = [
        _entry(id: 'short', startAt: jan1, endAt: jan1.add(const Duration(minutes: 5))),
        _entry(id: 'long', startAt: jan1, endAt: jan1.add(const Duration(hours: 2))),
        _entry(id: 'medium', startAt: jan1, endAt: jan1.add(const Duration(hours: 1))),
      ];

      final result = applyHistorySort(entries, HistorySortField.duration, SortDirection.desc);

      expect(result.map((e) => e.id), ['long', 'medium', 'short']);
    });

    test('duration asc returns shortest duration first', () {
      final entries = [
        _entry(id: 'short', startAt: jan1, endAt: jan1.add(const Duration(minutes: 5))),
        _entry(id: 'long', startAt: jan1, endAt: jan1.add(const Duration(hours: 2))),
      ];

      final result = applyHistorySort(entries, HistorySortField.duration, SortDirection.asc);

      expect(result.map((e) => e.id), ['short', 'long']);
    });

    test('taskProjectName asc sorts case-insensitively by task title', () {
      final entries = [
        _entry(id: 'a', startAt: jan1, taskTitle: 'Zebra'),
        _entry(id: 'b', startAt: jan1, taskTitle: 'apple'),
        _entry(id: 'c', startAt: jan1, taskTitle: 'Mango'),
      ];

      final result = applyHistorySort(entries, HistorySortField.taskProjectName, SortDirection.asc);

      expect(result.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('does not mutate the input list', () {
      final entries = [
        _entry(id: 'a', startAt: jan1),
        _entry(id: 'b', startAt: jan3),
      ];
      final original = List<ResolvedTimeEntry>.from(entries);

      applyHistorySort(entries, HistorySortField.date, SortDirection.asc);

      expect(entries.map((e) => e.id), original.map((e) => e.id));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/history_sort_test.dart --reporter expanded` (from `apps\worklog_studio\`)
Expected: FAIL — `history_sort.dart` does not exist (compile error: target of URI doesn't exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// apps\worklog_studio\lib\domain\sort_direction.dart
enum SortDirection { asc, desc }
```

```dart
// apps\worklog_studio\lib\domain\history_sort.dart
import 'resolved_time_entry.dart';
import 'sort_direction.dart';

enum HistorySortField { date, duration, taskProjectName }

List<ResolvedTimeEntry> applyHistorySort(
  List<ResolvedTimeEntry> entries,
  HistorySortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedTimeEntry>.from(entries);
  final sign = direction == SortDirection.desc ? -1 : 1;

  switch (field) {
    case HistorySortField.date:
      sorted.sort((a, b) {
        if (a.isRunning && !b.isRunning) return -1;
        if (!a.isRunning && b.isRunning) return 1;
        return sign * a.startAt.compareTo(b.startAt);
      });
    case HistorySortField.duration:
      final now = DateTime.now();
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
    case HistorySortField.taskProjectName:
      sorted.sort(
        (a, b) =>
            sign * a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase()),
      );
  }

  return sorted;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/core/history_sort_test.dart --reporter expanded`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/sort_direction.dart apps/worklog_studio/lib/domain/history_sort.dart apps/worklog_studio/test/core/history_sort_test.dart
git commit -m "feat: add History sort domain logic"
```

---

### Task 2: Tasks sort domain logic

**Files:**
- Create: `apps\worklog_studio\lib\domain\tasks_sort.dart`
- Test: `apps\worklog_studio\test\core\tasks_sort_test.dart`

**Interfaces:**
- Consumes: `SortDirection` from `apps\worklog_studio\lib\domain\sort_direction.dart` (Task 1).
- Produces: `enum TasksSortField { name, timeTracked }`
- Produces: `List<ResolvedTask> applyTasksSort(List<ResolvedTask> tasks, TasksSortField field, SortDirection direction)` — pure, does not mutate input.

- [ ] **Step 1: Write the failing test**

```dart
// apps\worklog_studio\test\core\tasks_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedTask _task({
  required String id,
  required String title,
  Duration tracked = Duration.zero,
}) {
  final start = DateTime(2026, 1, 1);
  return ResolvedTask(
    task: Task(
      id: id,
      projectId: 'p1',
      title: title,
      description: '',
      status: TaskStatus.open,
      createdAt: start,
    ),
    timeEntries: tracked == Duration.zero
        ? const []
        : [
            TimeEntry(
              id: 'te-$id',
              taskId: id,
              projectId: 'p1',
              startAt: start,
              endAt: start.add(tracked),
              status: TimeEntryStatus.stopped,
            ),
          ],
  );
}

void main() {
  group('applyTasksSort', () {
    test('name asc sorts case-insensitively', () {
      final tasks = [
        _task(id: 'a', title: 'Zebra'),
        _task(id: 'b', title: 'apple'),
        _task(id: 'c', title: 'Mango'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.name, SortDirection.asc);

      expect(result.map((t) => t.id), ['b', 'c', 'a']);
    });

    test('name desc reverses the order', () {
      final tasks = [
        _task(id: 'a', title: 'Zebra'),
        _task(id: 'b', title: 'apple'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.name, SortDirection.desc);

      expect(result.map((t) => t.id), ['a', 'b']);
    });

    test('timeTracked desc returns most-tracked first', () {
      final tasks = [
        _task(id: 'short', title: 'A', tracked: const Duration(minutes: 10)),
        _task(id: 'long', title: 'B', tracked: const Duration(hours: 3)),
        _task(id: 'none', title: 'C'),
      ];

      final result = applyTasksSort(tasks, TasksSortField.timeTracked, SortDirection.desc);

      expect(result.map((t) => t.id), ['long', 'short', 'none']);
    });

    test('does not mutate the input list', () {
      final tasks = [_task(id: 'a', title: 'Zebra'), _task(id: 'b', title: 'apple')];
      final originalOrder = tasks.map((t) => t.id).toList();

      applyTasksSort(tasks, TasksSortField.name, SortDirection.asc);

      expect(tasks.map((t) => t.id), originalOrder);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/tasks_sort_test.dart --reporter expanded`
Expected: FAIL — `tasks_sort.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps\worklog_studio\lib\domain\tasks_sort.dart
import 'resolved_task.dart';
import 'sort_direction.dart';

enum TasksSortField { name, timeTracked }

List<ResolvedTask> applyTasksSort(
  List<ResolvedTask> tasks,
  TasksSortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedTask>.from(tasks);
  final sign = direction == SortDirection.desc ? -1 : 1;
  final now = DateTime.now();

  switch (field) {
    case TasksSortField.name:
      sorted.sort(
        (a, b) => sign * a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case TasksSortField.timeTracked:
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
  }

  return sorted;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/core/tasks_sort_test.dart --reporter expanded`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/tasks_sort.dart apps/worklog_studio/test/core/tasks_sort_test.dart
git commit -m "feat: add Tasks sort domain logic"
```

---

### Task 3: Projects sort domain logic

**Files:**
- Create: `apps\worklog_studio\lib\domain\projects_sort.dart`
- Test: `apps\worklog_studio\test\core\projects_sort_test.dart`

**Interfaces:**
- Consumes: `SortDirection` from `apps\worklog_studio\lib\domain\sort_direction.dart` (Task 1).
- Produces: `enum ProjectsSortField { name, timeTracked }`
- Produces: `List<ResolvedProject> applyProjectsSort(List<ResolvedProject> projects, ProjectsSortField field, SortDirection direction)` — pure, does not mutate input.

- [ ] **Step 1: Write the failing test**

```dart
// apps\worklog_studio\test\core\projects_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/resolved_project.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/time_entry.dart';

ResolvedProject _project({
  required String id,
  required String name,
  Duration tracked = Duration.zero,
}) {
  final start = DateTime(2026, 1, 1);
  return ResolvedProject(
    project: Project(id: id, name: name, description: '', createdAt: start),
    timeEntries: tracked == Duration.zero
        ? const []
        : [
            TimeEntry(
              id: 'te-$id',
              taskId: 't1',
              projectId: id,
              startAt: start,
              endAt: start.add(tracked),
              status: TimeEntryStatus.stopped,
            ),
          ],
  );
}

void main() {
  group('applyProjectsSort', () {
    test('name asc sorts case-insensitively', () {
      final projects = [
        _project(id: 'a', name: 'Zebra'),
        _project(id: 'b', name: 'apple'),
        _project(id: 'c', name: 'Mango'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.name, SortDirection.asc);

      expect(result.map((p) => p.id), ['b', 'c', 'a']);
    });

    test('name desc reverses the order', () {
      final projects = [
        _project(id: 'a', name: 'Zebra'),
        _project(id: 'b', name: 'apple'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.name, SortDirection.desc);

      expect(result.map((p) => p.id), ['a', 'b']);
    });

    test('timeTracked desc returns most-tracked first', () {
      final projects = [
        _project(id: 'short', name: 'A', tracked: const Duration(minutes: 10)),
        _project(id: 'long', name: 'B', tracked: const Duration(hours: 3)),
        _project(id: 'none', name: 'C'),
      ];

      final result = applyProjectsSort(projects, ProjectsSortField.timeTracked, SortDirection.desc);

      expect(result.map((p) => p.id), ['long', 'short', 'none']);
    });

    test('does not mutate the input list', () {
      final projects = [_project(id: 'a', name: 'Zebra'), _project(id: 'b', name: 'apple')];
      final originalOrder = projects.map((p) => p.id).toList();

      applyProjectsSort(projects, ProjectsSortField.name, SortDirection.asc);

      expect(projects.map((p) => p.id), originalOrder);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/projects_sort_test.dart --reporter expanded`
Expected: FAIL — `projects_sort.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// apps\worklog_studio\lib\domain\projects_sort.dart
import 'resolved_project.dart';
import 'sort_direction.dart';

enum ProjectsSortField { name, timeTracked }

List<ResolvedProject> applyProjectsSort(
  List<ResolvedProject> projects,
  ProjectsSortField field,
  SortDirection direction,
) {
  final sorted = List<ResolvedProject>.from(projects);
  final sign = direction == SortDirection.desc ? -1 : 1;
  final now = DateTime.now();

  switch (field) {
    case ProjectsSortField.name:
      sorted.sort(
        (a, b) => sign * a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    case ProjectsSortField.timeTracked:
      sorted.sort((a, b) => sign * a.duration(now).compareTo(b.duration(now)));
  }

  return sorted;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/core/projects_sort_test.dart --reporter expanded`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/domain/projects_sort.dart apps/worklog_studio/test/core/projects_sort_test.dart
git commit -m "feat: add Projects sort domain logic"
```

---

### Task 4: Add sort state to PageUiPreferences

**Files:**
- Modify: `apps\worklog_studio\lib\state\page_ui_preferences.dart`
- Test: `apps\worklog_studio\test\feature\page_ui_preferences_test.dart`

**Interfaces:**
- Consumes: `HistorySortField`, `SortDirection` (Task 1), `TasksSortField` (Task 2), `ProjectsSortField` (Task 3).
- Produces on `PageUiPreferences`:
  - `HistorySortField get historySortField`, `SortDirection get historySortDirection`, `bool? get historySortExpandedOverride`
  - `void setHistorySortField(HistorySortField field)`, `void setHistorySortDirection(SortDirection direction)`, `void setHistorySortExpandedOverride(bool? value)`
  - Same triplet of getters/setters for `tasksSort*` (`TasksSortField`) and `projectsSort*` (`ProjectsSortField`).
  - Defaults: `historySortField = HistorySortField.date`, `historySortDirection = SortDirection.desc`; `tasksSortField = TasksSortField.name`, `tasksSortDirection = SortDirection.asc`; `projectsSortField = ProjectsSortField.name`, `projectsSortDirection = SortDirection.asc`. All `*SortExpandedOverride` default to `null`.

- [ ] **Step 1: Write the failing test**

Add to the end of the `group('PageUiPreferences', ...)` block in `apps\worklog_studio\test\feature\page_ui_preferences_test.dart` (before the final closing `});`), and add the three new imports at the top of the file:

```dart
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
```

```dart
    test('defaults to date-desc, name-asc, name-asc sort with no expanded override', () {
      final prefs = PageUiPreferences();

      expect(prefs.historySortField, HistorySortField.date);
      expect(prefs.historySortDirection, SortDirection.desc);
      expect(prefs.historySortExpandedOverride, isNull);

      expect(prefs.tasksSortField, TasksSortField.name);
      expect(prefs.tasksSortDirection, SortDirection.asc);
      expect(prefs.tasksSortExpandedOverride, isNull);

      expect(prefs.projectsSortField, ProjectsSortField.name);
      expect(prefs.projectsSortDirection, SortDirection.asc);
      expect(prefs.projectsSortExpandedOverride, isNull);
    });

    test('setHistorySortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setHistorySortField(HistorySortField.duration);
      prefs.setHistorySortDirection(SortDirection.asc);
      prefs.setHistorySortExpandedOverride(true);

      expect(prefs.historySortField, HistorySortField.duration);
      expect(prefs.historySortDirection, SortDirection.asc);
      expect(prefs.historySortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setTasksSortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setTasksSortField(TasksSortField.timeTracked);
      prefs.setTasksSortDirection(SortDirection.desc);
      prefs.setTasksSortExpandedOverride(true);

      expect(prefs.tasksSortField, TasksSortField.timeTracked);
      expect(prefs.tasksSortDirection, SortDirection.desc);
      expect(prefs.tasksSortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('setProjectsSortField/Direction/ExpandedOverride update and notify', () {
      final prefs = PageUiPreferences();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.setProjectsSortField(ProjectsSortField.timeTracked);
      prefs.setProjectsSortDirection(SortDirection.desc);
      prefs.setProjectsSortExpandedOverride(true);

      expect(prefs.projectsSortField, ProjectsSortField.timeTracked);
      expect(prefs.projectsSortDirection, SortDirection.desc);
      expect(prefs.projectsSortExpandedOverride, isTrue);
      expect(notified, isTrue);
    });

    test('updating History sort does not affect Tasks/Projects sort', () {
      final prefs = PageUiPreferences();

      prefs.setHistorySortField(HistorySortField.duration);
      prefs.setHistorySortDirection(SortDirection.asc);

      expect(prefs.tasksSortField, TasksSortField.name);
      expect(prefs.tasksSortDirection, SortDirection.asc);
      expect(prefs.projectsSortField, ProjectsSortField.name);
      expect(prefs.projectsSortDirection, SortDirection.asc);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/feature/page_ui_preferences_test.dart --reporter expanded`
Expected: FAIL — `historySortField` etc. are undefined getters on `PageUiPreferences`.

- [ ] **Step 3: Write minimal implementation**

In `apps\worklog_studio\lib\state\page_ui_preferences.dart`, add imports and fields/getters/setters:

```dart
import 'package:flutter/foundation.dart';
import 'package:worklog_studio/domain/history_filters.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/projects_filters.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_filters.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'package:worklog_studio/feature/history/presentation/history_page.dart';
import 'package:worklog_studio/feature/projects/presentation/projects_page.dart';
import 'package:worklog_studio/feature/tasks/presentation/tasks_page.dart';

/// Session-scoped (in-memory, lost on app restart) view-mode, filter, and
/// sort state for History/Tasks/Projects, lifted out of the page widgets so
/// it survives the pages being disposed when the user switches tabs.
class PageUiPreferences extends ChangeNotifier {
  HistoryViewMode _historyViewMode = HistoryViewMode.table;
  HistoryFilters _historyFilters = const HistoryFilters();
  bool? _historyFilterExpandedOverride;
  HistorySortField _historySortField = HistorySortField.date;
  SortDirection _historySortDirection = SortDirection.desc;
  bool? _historySortExpandedOverride;

  TaskViewMode _tasksViewMode = TaskViewMode.table;
  TasksFilters _tasksFilters = const TasksFilters();
  bool? _tasksFilterExpandedOverride;
  TasksSortField _tasksSortField = TasksSortField.name;
  SortDirection _tasksSortDirection = SortDirection.asc;
  bool? _tasksSortExpandedOverride;

  ProjectViewMode _projectsViewMode = ProjectViewMode.table;
  ProjectsFilters _projectsFilters = const ProjectsFilters();
  bool? _projectsFilterExpandedOverride;
  ProjectsSortField _projectsSortField = ProjectsSortField.name;
  SortDirection _projectsSortDirection = SortDirection.asc;
  bool? _projectsSortExpandedOverride;

  HistoryViewMode get historyViewMode => _historyViewMode;
  HistoryFilters get historyFilters => _historyFilters;
  bool? get historyFilterExpandedOverride => _historyFilterExpandedOverride;
  HistorySortField get historySortField => _historySortField;
  SortDirection get historySortDirection => _historySortDirection;
  bool? get historySortExpandedOverride => _historySortExpandedOverride;

  TaskViewMode get tasksViewMode => _tasksViewMode;
  TasksFilters get tasksFilters => _tasksFilters;
  bool? get tasksFilterExpandedOverride => _tasksFilterExpandedOverride;
  TasksSortField get tasksSortField => _tasksSortField;
  SortDirection get tasksSortDirection => _tasksSortDirection;
  bool? get tasksSortExpandedOverride => _tasksSortExpandedOverride;

  ProjectViewMode get projectsViewMode => _projectsViewMode;
  ProjectsFilters get projectsFilters => _projectsFilters;
  bool? get projectsFilterExpandedOverride => _projectsFilterExpandedOverride;
  ProjectsSortField get projectsSortField => _projectsSortField;
  SortDirection get projectsSortDirection => _projectsSortDirection;
  bool? get projectsSortExpandedOverride => _projectsSortExpandedOverride;

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

  void setHistorySortField(HistorySortField field) {
    _historySortField = field;
    notifyListeners();
  }

  void setHistorySortDirection(SortDirection direction) {
    _historySortDirection = direction;
    notifyListeners();
  }

  void setHistorySortExpandedOverride(bool? value) {
    _historySortExpandedOverride = value;
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

  void setTasksSortField(TasksSortField field) {
    _tasksSortField = field;
    notifyListeners();
  }

  void setTasksSortDirection(SortDirection direction) {
    _tasksSortDirection = direction;
    notifyListeners();
  }

  void setTasksSortExpandedOverride(bool? value) {
    _tasksSortExpandedOverride = value;
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

  void setProjectsSortField(ProjectsSortField field) {
    _projectsSortField = field;
    notifyListeners();
  }

  void setProjectsSortDirection(SortDirection direction) {
    _projectsSortDirection = direction;
    notifyListeners();
  }

  void setProjectsSortExpandedOverride(bool? value) {
    _projectsSortExpandedOverride = value;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/feature/page_ui_preferences_test.dart --reporter expanded`
Expected: PASS (all tests, including the 5 new ones).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/state/page_ui_preferences.dart apps/worklog_studio/test/feature/page_ui_preferences_test.dart
git commit -m "feat: add sort state to PageUiPreferences"
```

---

### Task 5: Enable the sort icon in TableToolbar

**Files:**
- Modify: `packages\worklog_studio_style_system\lib\ui_kit\src\table\table_toolbar.dart`

**Interfaces:**
- Produces: `TableToolbar` gains two new *optional* constructor params: `bool isSortExpanded = false` and `VoidCallback? onSortTap`. They default to "disabled, collapsed" so the three existing call sites (History/Tasks/Projects, none of which pass them yet) keep compiling unchanged until each is updated in Tasks 6-8. This keeps every commit in this plan independently buildable.
- Consumes (by callers in Task 6/7/8): `PageUiPreferences.historySortExpandedOverride` / equivalent, same shape as the existing `isFilterExpanded` computation.

This is a small, self-contained widget change. No automated test (UI-only, no extracted logic) — verified via `fvm flutter analyze` in this task, and visually once Tasks 6-8 wire it up.

- [ ] **Step 1: Modify `table_toolbar.dart`**

```dart
// packages\worklog_studio_style_system\lib\ui_kit\src\table\table_toolbar.dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class TableToolbar extends StatelessWidget {
  final bool isFilterExpanded;
  final VoidCallback onFilterTap;
  final int activeFilterCount;
  final bool isSortExpanded;
  final VoidCallback? onSortTap;
  final MainAxisAlignment mainAxisAlignment;

  const TableToolbar({
    super.key,
    required this.isFilterExpanded,
    required this.onFilterTap,
    this.activeFilterCount = 0,
    this.isSortExpanded = false,
    this.onSortTap,
    this.mainAxisAlignment =  MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: [
        _ToolbarIconButton(
          icon: Icons.filter_list,
          isActive: isFilterExpanded,
          badgeCount: activeFilterCount,
          onTap: onFilterTap,
        ),
        SizedBox(width: theme.spacings.sm),
        _ToolbarIconButton(
          icon: Icons.sort,
          enabled: onSortTap != null,
          isActive: isSortExpanded,
          onTap: onSortTap,
        ),
        SizedBox(width: theme.spacings.sm),
        const _ToolbarIconButton(icon: Icons.settings_outlined, enabled: false),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isActive;
  final int badgeCount;
  final VoidCallback? onTap;

  const _ToolbarIconButton({
    required this.icon,
    this.enabled = true,
    this.isActive = false,
    this.badgeCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PrimaryButton(
          onTap: enabled ? onTap : null,
          isDisabled: !enabled,
          type: isActive ? ButtonType.secondary : ButtonType.ghost,
          size: ButtonSize.xs,
          leftIconWidget: Icon(icon),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 14),
              decoration: BoxDecoration(
                color: palette.accent.primary,
                borderRadius: theme.radiuses.pill.circular,
              ),
              child: Text(
                '$badgeCount',
                textAlign: TextAlign.center,
                style: theme.commonTextStyles.caption2.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

The only changes from the current file: `isSortExpanded`/`onSortTap` are added as optional params (defaulting to collapsed/disabled, so existing call sites are unaffected), and the `_ToolbarIconButton(icon: Icons.sort, enabled: false)` line now derives `enabled` from whether a caller supplied `onSortTap`.

- [ ] **Step 2: Verify it compiles with no behavior change yet**

Run (from `apps\worklog_studio\`): `fvm flutter analyze`
Expected: no errors. The three existing call sites (History, Tasks, Projects) don't pass the new params yet, so the sort icon stays disabled exactly as before — this task changes no visible behavior, it only makes the toggle wireable.

- [ ] **Step 3: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/table/table_toolbar.dart
git commit -m "feat: make the sort toggle button in TableToolbar wireable"
```

---

### Task 6: Wire sorting into the History page

**Files:**
- Create: `apps\worklog_studio\lib\feature\history\presentation\components\history_sort_bar.dart`
- Modify: `apps\worklog_studio\lib\feature\history\presentation\history_page.dart`

**Interfaces:**
- Consumes: `applyHistorySort` (Task 1), `PageUiPreferences.historySortField/historySortDirection/historySortExpandedOverride` + setters (Task 4), `TableToolbar(isSortExpanded:, onSortTap:)` (Task 5).
- Produces: `HistorySortBar` widget — `const HistorySortBar({required HistorySortField field, required SortDirection direction, required ValueChanged<HistorySortField> onFieldChanged, required ValueChanged<SortDirection> onDirectionChanged})`.

This task is UI wiring (no new pure logic beyond what Task 1 already tests), so no new automated test — verify by running the app's existing widget/golden tests (none currently cover this page) and `fvm flutter analyze`, per the UI-only exemption in `apps\worklog_studio\CLAUDE.md`.

- [ ] **Step 1: Create `HistorySortBar`**

```dart
// apps\worklog_studio\lib\feature\history\presentation\components\history_sort_bar.dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

class HistorySortBar extends StatelessWidget {
  final HistorySortField field;
  final SortDirection direction;
  final ValueChanged<HistorySortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const HistorySortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: HistorySortField.date, label: 'Date'),
    SelectOption(value: HistorySortField.duration, label: 'Duration'),
    SelectOption(value: HistorySortField.taskProjectName, label: 'Task & Project'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: theme.spacings.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: Select<HistorySortField>(
                value: field,
                onChanged: (value) {
                  if (value != null) onFieldChanged(value);
                },
                options: _fieldOptions,
                placeholder: 'Sort by',
                size: ControlSize.xs,
              ),
            ),
            SizedBox(width: theme.spacings.sm),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.xs,
              leftIconWidget: Icon(
                direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
              onTap: () => onDirectionChanged(
                direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire state through `_HistoryScreenState`/`TimeEntryList` and update the toolbar call**

In `history_page.dart`, locate the screen `build()` method that constructs `TimeEntryList(...)` (around line 60-92) and add the new props alongside the existing filter props:

```dart
    return TimeEntryList(
      entries: entries,
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
      sortField: prefs.historySortField,
      sortDirection: prefs.historySortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setHistorySortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setHistorySortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setHistorySortExpandedOverride(!isSortExpanded),
    );
```

Immediately above that `return`, alongside the existing `isFilterExpanded` computation, add:

```dart
    final isSortExpanded = prefs.historySortExpandedOverride ?? false;
```

Add the matching fields to the `TimeEntryList` class declaration and constructor (next to the existing `filters`/`onFiltersChanged`/`isFilterExpanded`/`onFilterExpandedToggle` fields):

```dart
  final HistorySortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<HistorySortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;
```

and to its constructor parameter list:

```dart
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
```

Add the import at the top of `history_page.dart`:

```dart
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'components/history_sort_bar.dart';
```

- [ ] **Step 3: Update the `TableToolbar(...)` call and add the expandable sort bar**

Replace the existing `TableToolbar(...)` call (the one around line 257-261) with:

```dart
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            HistorySortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
```

(This sits right before the existing `if (isFilterExpanded) ...` block, so the two expandable rows stack independently if both are open.)

- [ ] **Step 4: Apply the sort and flatten grouping when field is not Date**

Replace the existing inline sort-and-group logic (the block currently reading, around lines 129-156):

```dart
    final filteredEntries = applyHistoryFilters(entries, filters);

    // Sort entries: latest first
    final sortedEntries = List<ResolvedTimeEntry>.from(filteredEntries)
      ..sort((a, b) {
        // Active entries always at the top
        if (a.isRunning && !b.isRunning) return -1;
        if (!a.isRunning && b.isRunning) return 1;
        return b.startAt.compareTo(a.startAt);
      });

    // Group by date
    final Map<DateTime, List<ResolvedTimeEntry>> groupedEntries = {};
    for (final resolvedEntry in sortedEntries) {
      final entry = resolvedEntry.entry;
      final date = DateTime(
        entry.startAt.year,
        entry.startAt.month,
        entry.startAt.day,
      );
      if (!groupedEntries.containsKey(date)) {
        groupedEntries[date] = [];
      }
      groupedEntries[date]!.add(resolvedEntry);
    }

    final sortedDates = groupedEntries.keys.toList()
      ..sort((a, b) => b.compareTo(a));
```

with:

```dart
    final filteredEntries = applyHistoryFilters(entries, filters);
    final sortedEntries = applyHistorySort(filteredEntries, sortField, sortDirection);
    final isGroupedByDate = sortField == HistorySortField.date;

    // Group by date (only meaningful when sorted by date; otherwise rendered flat)
    final Map<DateTime, List<ResolvedTimeEntry>> groupedEntries = {};
    if (isGroupedByDate) {
      for (final resolvedEntry in sortedEntries) {
        final entry = resolvedEntry.entry;
        final date = DateTime(
          entry.startAt.year,
          entry.startAt.month,
          entry.startAt.day,
        );
        groupedEntries.putIfAbsent(date, () => []).add(resolvedEntry);
      }
    }

    final sortedDates = isGroupedByDate
        ? (groupedEntries.keys.toList()
            ..sort((a, b) => sortDirection == SortDirection.desc
                ? b.compareTo(a)
                : a.compareTo(b)))
        : <DateTime>[];
```

Note: this preserves the original `b.compareTo(a)` (desc) date-group ordering as the default, and now also supports asc when the user picks that direction while sorting by Date.

- [ ] **Step 5: Render a flat list when not grouped by date**

Find the `Expanded(child: SingleChildScrollView(child: Column(... children: [ ...sortedDates.map(...), if (entries.isNotEmpty) Container(...footer...) ])))` block (around lines 312-447). Wrap the existing `...sortedDates.map((date) { ... })` section so it is only used when `isGroupedByDate`, and add a flat-list branch otherwise. Change:

```dart
                children: [
                  ...sortedDates.map((date) {
```

to:

```dart
                children: [
                  if (isGroupedByDate)
                    ...sortedDates.map((date) {
```

and find the closing of that `.map` callback — currently:

```dart
                        SizedBox(height: theme.spacings.xl),
                      ],
                    );
                  }),
```

Change it to close the new `if`:

```dart
                        SizedBox(height: theme.spacings.xl),
                      ],
                    );
                  })
                  else if (viewMode == HistoryViewMode.cards)
                    Column(
                      spacing: theme.spacings.md,
                      children: sortedEntries.map((resolvedEntry) {
                        final entry = resolvedEntry.entry;
                        final isSelected = selectedEntry?.id == entry.id;
                        return TimeEntryCard(
                          key: isSelected ? selectedRowKey : null,
                          resolvedEntry: resolvedEntry,
                          isSelected: isSelected,
                          onTap: () => onEntrySelected(entry),
                        );
                      }).toList(),
                    )
                  else
                    WsTable<ResolvedTimeEntry>(
                      showHeader: true,
                      data: sortedEntries,
                      selectedItem: sortedEntries.firstWhereOrNull(
                        (e) => e.entry.id == selectedEntry?.id,
                      ),
                      rowKeyBuilder: (item) =>
                          item.entry.id == selectedEntry?.id ? selectedRowKey : null,
                      onRowTap: (item) => onEntrySelected(item.entry),
                      isSelected: (item, selected) =>
                          item.entry.id == selected?.entry.id,
                      columns: _getTableColumns(theme),
                    ),
```

This reuses the exact same `TimeEntryCard`/`WsTable` rendering the date-grouped branch already used per-day, just applied to the whole flat `sortedEntries` list with no date header.

- [ ] **Step 6: Run static analysis and the full test suite**

Run (from `apps\worklog_studio\`):
```
fvm flutter analyze
fvm flutter test test/core/ test/feature/ --reporter expanded
```
Expected: no analyzer errors, all tests pass.

- [ ] **Step 7: Manually verify in the running app is out of scope**

Per project memory, do not run `flutter run` / the `run` skill to launch the app. Rely on `fvm flutter analyze` plus the test suite for verification.

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/feature/history/presentation/components/history_sort_bar.dart apps/worklog_studio/lib/feature/history/presentation/history_page.dart
git commit -m "feat: wire interactive sorting into the History table"
```

---

### Task 7: Wire sorting into the Tasks page

**Files:**
- Create: `apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_sort_bar.dart`
- Modify: `apps\worklog_studio\lib\feature\tasks\presentation\tasks_page.dart`

**Interfaces:**
- Consumes: `applyTasksSort` (Task 2), `PageUiPreferences.tasksSortField/tasksSortDirection/tasksSortExpandedOverride` + setters (Task 4), `TableToolbar(isSortExpanded:, onSortTap:)` (Task 5).
- Produces: `TasksSortBar` widget — same shape as `HistorySortBar` but for `TasksSortField`.

UI wiring only; no new automated test, verified via `fvm flutter analyze` and the existing suite.

- [ ] **Step 1: Create `TasksSortBar`**

```dart
// apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_sort_bar.dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';

class TasksSortBar extends StatelessWidget {
  final TasksSortField field;
  final SortDirection direction;
  final ValueChanged<TasksSortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const TasksSortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: TasksSortField.name, label: 'Name'),
    SelectOption(value: TasksSortField.timeTracked, label: 'Time tracked'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: theme.spacings.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: Select<TasksSortField>(
                value: field,
                onChanged: (value) {
                  if (value != null) onFieldChanged(value);
                },
                options: _fieldOptions,
                placeholder: 'Sort by',
                size: ControlSize.xs,
              ),
            ),
            SizedBox(width: theme.spacings.sm),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.xs,
              leftIconWidget: Icon(
                direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
              onTap: () => onDirectionChanged(
                direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire state through `_TasksScreenState`/`TaskList`**

In `tasks_page.dart`, add the import:

```dart
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';
import 'components/tasks_sort_bar.dart';
```

In `_TasksScreenState.build()`, above the `return TaskList(...)`, add:

```dart
    final isSortExpanded = prefs.tasksSortExpandedOverride ?? false;
```

and inside the `TaskList(...)` constructor call, add after the existing `onFilterExpandedToggle:` line:

```dart
      sortField: prefs.tasksSortField,
      sortDirection: prefs.tasksSortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setTasksSortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setTasksSortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setTasksSortExpandedOverride(!isSortExpanded),
```

In the `TaskList` class, add fields next to the existing filter fields:

```dart
  final TasksSortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<TasksSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;
```

and to its constructor:

```dart
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
```

- [ ] **Step 3: Update the `TableToolbar` call, add the sort bar, and apply sorting**

Replace the existing `TableToolbar(...)` call in `TaskList.build()`:

```dart
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            TasksSortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
```

Then update the data pipeline. Find:

```dart
                final filteredTasks = applyTasksFilters(tasks, filters);
```

and change it to:

```dart
                final filteredTasks = applyTasksSort(
                  applyTasksFilters(tasks, filters),
                  sortField,
                  sortDirection,
                );
```

(`filteredTasks` is used unchanged by the rest of the method, in both the `WsTable` and `Column`-of-cards branches, so no further changes are needed there.)

- [ ] **Step 4: Run static analysis and the full test suite**

Run (from `apps\worklog_studio\`):
```
fvm flutter analyze
fvm flutter test test/core/ test/feature/ --reporter expanded
```
Expected: no analyzer errors, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/tasks/presentation/components/tasks_sort_bar.dart apps/worklog_studio/lib/feature/tasks/presentation/tasks_page.dart
git commit -m "feat: wire interactive sorting into the Tasks table"
```

---

### Task 8: Wire sorting into the Projects page

**Files:**
- Create: `apps\worklog_studio\lib\feature\projects\presentation\components\projects_sort_bar.dart`
- Modify: `apps\worklog_studio\lib\feature\projects\presentation\projects_page.dart`

**Interfaces:**
- Consumes: `applyProjectsSort` (Task 3), `PageUiPreferences.projectsSortField/projectsSortDirection/projectsSortExpandedOverride` + setters (Task 4), `TableToolbar(isSortExpanded:, onSortTap:)` (Task 5).
- Produces: `ProjectsSortBar` widget — same shape as `HistorySortBar`/`TasksSortBar` but for `ProjectsSortField`.

UI wiring only; no new automated test, verified via `fvm flutter analyze` and the existing suite. This is the last task — after this commit, the full feature from the spec is delivered end to end.

- [ ] **Step 1: Create `ProjectsSortBar`**

```dart
// apps\worklog_studio\lib\feature\projects\presentation\components\projects_sort_bar.dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

class ProjectsSortBar extends StatelessWidget {
  final ProjectsSortField field;
  final SortDirection direction;
  final ValueChanged<ProjectsSortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const ProjectsSortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: ProjectsSortField.name, label: 'Name'),
    SelectOption(value: ProjectsSortField.timeTracked, label: 'Time tracked'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: theme.spacings.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: Select<ProjectsSortField>(
                value: field,
                onChanged: (value) {
                  if (value != null) onFieldChanged(value);
                },
                options: _fieldOptions,
                placeholder: 'Sort by',
                size: ControlSize.xs,
              ),
            ),
            SizedBox(width: theme.spacings.sm),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.xs,
              leftIconWidget: Icon(
                direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
              onTap: () => onDirectionChanged(
                direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire state through `_ProjectsScreenState`/`ProjectList`**

In `projects_page.dart`, add the import:

```dart
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'components/projects_sort_bar.dart';
```

In `_ProjectsScreenState.build()`, above the `return ProjectList(...)`, add:

```dart
    final isSortExpanded = prefs.projectsSortExpandedOverride ?? false;
```

and inside the `ProjectList(...)` constructor call, add after the existing `onFilterExpandedToggle:` line:

```dart
      sortField: prefs.projectsSortField,
      sortDirection: prefs.projectsSortDirection,
      onSortFieldChanged: (field) =>
          context.read<PageUiPreferences>().setProjectsSortField(field),
      onSortDirectionChanged: (direction) =>
          context.read<PageUiPreferences>().setProjectsSortDirection(direction),
      isSortExpanded: isSortExpanded,
      onSortExpandedToggle: () => context
          .read<PageUiPreferences>()
          .setProjectsSortExpandedOverride(!isSortExpanded),
```

In the `ProjectList` class, add fields next to the existing filter fields:

```dart
  final ProjectsSortField sortField;
  final SortDirection sortDirection;
  final ValueChanged<ProjectsSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;
  final bool isSortExpanded;
  final VoidCallback onSortExpandedToggle;
```

and to its constructor:

```dart
    required this.sortField,
    required this.sortDirection,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.isSortExpanded,
    required this.onSortExpandedToggle,
```

- [ ] **Step 3: Update the `TableToolbar` call, add the sort bar, and apply sorting**

Replace the existing `TableToolbar(...)` call in `ProjectList.build()`:

```dart
          TableToolbar(
            isFilterExpanded: isFilterExpanded,
            onFilterTap: onFilterExpandedToggle,
            activeFilterCount: filters.activeCount,
            isSortExpanded: isSortExpanded,
            onSortTap: onSortExpandedToggle,
          ),
          if (isSortExpanded) ...[
            SizedBox(height: theme.spacings.sm),
            ProjectsSortBar(
              field: sortField,
              direction: sortDirection,
              onFieldChanged: onSortFieldChanged,
              onDirectionChanged: onSortDirectionChanged,
            ),
          ],
```

Then update the data pipeline. Find:

```dart
                final filteredProjects = applyProjectsFilters(projects, filters);
```

and change it to:

```dart
                final filteredProjects = applyProjectsSort(
                  applyProjectsFilters(projects, filters),
                  sortField,
                  sortDirection,
                );
```

- [ ] **Step 4: Run static analysis and the full test suite**

Run (from `apps\worklog_studio\`):
```
fvm flutter analyze
fvm flutter test test/core/ test/feature/ --reporter expanded
```
Expected: no analyzer errors, all tests pass. This is the final task, so this run also confirms the whole feature compiles and the full suite (Tasks 1-4's new tests plus every pre-existing test) is green.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/projects/presentation/components/projects_sort_bar.dart apps/worklog_studio/lib/feature/projects/presentation/projects_page.dart
git commit -m "feat: wire interactive sorting into the Projects table"
```
