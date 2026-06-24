# Drawer Associated-Entity Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `TaskDrawer`'s and `ProjectDrawer`'s "related entities" lists clickable (navigating via the existing `AppNavigationController`) and visually consistent with each other and with the rest of each drawer.

**Architecture:** Both drawers gain/refactor a section that is a `LabeledDivider` header followed by either an empty-state message or a `Column` of `MasterListCard` rows, each row's `onTap` calling into `AppNavigationController`. No new shared widget is created — both drawers already import everything needed (`MasterListCard` via the `worklog_studio_style_system` barrel, `LabeledDivider` likewise, `AppNavigationController` already imported in `tasks_drawer.dart`).

**Tech Stack:** Flutter/Dart, `provider` (`context.watch`/`context.read`), existing `EntityResolver` and `AppNavigationController` services, existing `MasterListCard`/`LabeledDivider` UI-kit components.

## Global Constraints

- Use `fvm` as a wrapper for all Flutter/Dart commands (e.g. `fvm flutter analyze`, `fvm flutter test`) — never bare `flutter`/`dart`.
- These are UI-only widget changes — no new business logic — so per the app's TDD guidelines (`apps\worklog_studio\CLAUDE.md`) no new unit tests are required. Verify behavior via `fvm flutter analyze` (must stay clean) and `fvm flutter test test/core/ test/feature/ --reporter expanded` (existing suite must stay green — these widget changes don't touch anything it covers, but a regression would still show up if it did).
- Do not modify `AppNavigationController`, its registration in `app_shell.dart`, or any `initialSelectedXId` deep-link wiring — all of it already exists and works.
- Do not make "VIEW ALL" or "Add Task" functional — out of scope.
- No `Co-Authored-By: Claude` trailer in any commit.

---

### Task 1: `TaskDrawer` — add clickable "Time Entries" section

**Files:**
- Modify: `apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_drawer.dart`

**Interfaces:**
- Consumes: `EntityResolver.getResolvedTask(String taskId) -> ResolvedTask?` (existing, in `worklog_studio/state/entity_resolver.dart`); `ResolvedTask.timeEntries -> List<TimeEntry>` and `ResolvedTask.duration(DateTime now) -> Duration` (existing, in `worklog_studio/domain/resolved_task.dart`); `TimeEntry.comment -> String?`, `TimeEntry.startAt -> DateTime`, `TimeEntry.endAt -> DateTime?`, `TimeEntry.id -> String`, `TimeEntry.duration(DateTime now) -> Duration` (existing, in `worklog_studio/domain/time_entry.dart`); `AppNavigationController.openHistoryEntry(String entryId)` (existing, already imported in this file as `context.read<AppNavigationController>().openProject(...)` is at line 357-359 — same controller instance pattern); `MasterListCard({required String title, String? metadata, Widget? trailing, VoidCallback? onTap})` (existing, exported via `worklog_studio_style_system` barrel, already imported in this file).
- Produces: nothing consumed by Task 2 — the two tasks are independent.

This task adds a new section to `_TaskDrawerState.build`'s `content` column, between the `Notes` `InlineField` (ends at line 452) and the existing `if (!_isNew) [...Activity...]` block (starts at line 453). Both blocks live inside the same outer `if (!_isNew) [...]` array that already starts at line 453 — the new section is inserted as additional items at the front of that array, so it shares the existing `!_isNew` gate and you do not add a second `if`.

- [ ] **Step 1: Add required imports**

At the top of `apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_drawer.dart`, after the existing `import 'package:worklog_studio/core/services/app_navigation_controller.dart';` (line 14), add:

```dart
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
```

- [ ] **Step 2: Add formatting helpers to `_TaskDrawerState`**

In `apps\worklog_studio\lib\feature\tasks\presentation\components\tasks_drawer.dart`, add these three private methods to `_TaskDrawerState`, placed directly above the existing `String _getStatusText(TaskStatus status) { ... }` method (currently at line 482):

```dart
  String _formatEntryRange(TimeEntry entry) {
    final start = entry.startAt;
    final datePart = '${_monthAbbrev(start.month)} ${start.day}';
    final startTime = _formatTimeOfDay(start);
    if (entry.endAt == null) {
      return '$datePart, $startTime - now';
    }
    final endTime = _formatTimeOfDay(entry.endAt!);
    return '$datePart, $startTime - $endTime';
  }

  String _formatTimeOfDay(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _monthAbbrev(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  String _formatExactDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
```

- [ ] **Step 3: Insert the "Time Entries" section**

In the same file, find this exact existing code (currently lines 453-456):

```dart
                          if (!_isNew) ...[
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Activity'),
                            SizedBox(height: theme.spacings.lg),
```

Replace it with (this inserts the new section as the first items inside the existing `!_isNew` array, then continues with the original `Activity` divider unchanged):

```dart
                          if (!_isNew) ...[
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Time Entries'),
                            SizedBox(height: theme.spacings.lg),
                            Builder(
                              builder: (context) {
                                final timeEntries = context
                                        .watch<EntityResolver>()
                                        .getResolvedTask(widget.task!.id)
                                        ?.timeEntries ??
                                    const <TimeEntry>[];

                                if (timeEntries.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: theme.spacings.xl,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No time entries logged for this task yet.',
                                        style: theme.commonTextStyles.body
                                            .copyWith(color: palette.text.muted),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  spacing: theme.spacings.lg,
                                  children: timeEntries.map((entry) {
                                    return MasterListCard(
                                      title: (entry.comment?.isNotEmpty ?? false)
                                          ? entry.comment!
                                          : 'No comment',
                                      metadata: _formatEntryRange(entry),
                                      trailing: Text(
                                        _formatExactDuration(
                                          entry.duration(DateTime.now()),
                                        ),
                                        style: theme.commonTextStyles.bodyBold,
                                      ),
                                      onTap: () => context
                                          .read<AppNavigationController>()
                                          .openHistoryEntry(entry.id),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                            SizedBox(height: theme.spacings.x2l),
                            LabeledDivider(label: 'Activity'),
                            SizedBox(height: theme.spacings.lg),
```

- [ ] **Step 4: Verify it compiles and analyzes clean**

Run (from `apps\worklog_studio\`): `fvm flutter analyze`
Expected: No errors or warnings introduced by this change (pre-existing warnings elsewhere are not your concern).

- [ ] **Step 5: Manual smoke check**

Run (from `apps\worklog_studio\`): `fvm flutter run -d windows`
Open the Tasks screen, open a task that has at least one time entry (or create one and log time against it via the existing tracking panel), open its drawer, and confirm: a "Time Entries" section appears between Notes and Activity, shows a row per entry with comment/date-range/duration, and tapping a row switches to the History screen with that entry's drawer open and the row scrolled into view (this last part is exercised by the pre-existing `openHistoryEntry`/`HistoryScreen.initialSelectedEntryId` wiring — confirm it fires, don't re-implement it). Also open a task with zero time entries and confirm the empty-state message shows instead.

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/tasks/presentation/components/tasks_drawer.dart
git commit -m "Add clickable time-entries list to TaskDrawer"
```

---

### Task 2: `ProjectDrawer` — make "Associated Tasks" rows clickable and fix row bugs

**Files:**
- Modify: `apps\worklog_studio\lib\feature\projects\presentation\components\project_drawer.dart`

**Interfaces:**
- Consumes: `EntityResolver.getResolvedTask(String taskId) -> ResolvedTask?` and `ResolvedTask.duration(DateTime now) -> Duration` (existing — same as Task 1, independent usage); `AppNavigationController.openTask(String taskId)` (existing); `MasterListCard` (existing, same as Task 1).
- Produces: nothing — independent of Task 1.

This task replaces the "Associated Tasks" header and row-rendering code in `_ProjectDrawerState.build`. The two bugs being fixed (status text shows the project's status instead of the task's; duration is a hardcoded `'0:00h'` stub) live entirely inside the code block being rewritten here.

- [ ] **Step 1: Add required imports**

At the top of `apps\worklog_studio\lib\feature\projects\presentation\components\project_drawer.dart`, after the existing `import 'package:worklog_studio/feature/common/presentation/components/entity_meta_info_row.dart';` (line 11), add:

```dart
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/core/services/app_navigation_controller.dart';
```

- [ ] **Step 2: Add helper methods to `_ProjectDrawerState`**

In the same file, add these two private/public methods directly above the existing `String getStatusText(ProjectStatus status) { ... }` method (currently at line 435):

```dart
  String getTaskStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'OPEN';
      case TaskStatus.done:
        return 'DONE';
      case TaskStatus.archived:
        return 'ARCHIVED';
    }
  }

  String _formatExactDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
```

This requires importing the `TaskStatus` enum. Add, alongside the other domain imports near the top of the file (after `import 'package:worklog_studio/domain/project.dart';` at line 3):

```dart
import 'package:worklog_studio/domain/task.dart';
```

- [ ] **Step 3: Replace the header**

Find this exact existing code (currently lines 299-312):

```dart
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Associated Tasks',
                                  style: theme.commonTextStyles.h3,
                                ),
                                Text(
                                  'VIEW ALL',
                                  style: theme.commonTextStyles.caption3Bold
                                      .copyWith(color: palette.accent.primary),
                                ),
                              ],
                            ),
```

Replace it with:

```dart
                            LabeledDivider(label: 'Associated Tasks'),
```

- [ ] **Step 4: Replace the row-rendering block**

Find this exact existing code (currently lines 328-395, the `else` branch's `Column(...)`):

```dart
                            else
                              Column(
                                spacing: theme.spacings.lg,
                                children: projectTasks.map((task) {
                                  return Container(
                                    padding: EdgeInsets.all(theme.spacings.lg),
                                    decoration: BoxDecoration(
                                      color: palette.background.surfaceMuted,
                                      borderRadius: theme.radiuses.md.circular,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            theme.spacings.sm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.background.surface,
                                            borderRadius:
                                                theme.radiuses.sm.circular,
                                          ),
                                          child: Icon(
                                            Icons.task_alt, // Default icon
                                            color: palette.accent.primary,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: theme.spacings.lg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task.title,
                                                style: theme
                                                    .commonTextStyles
                                                    .bodyBold,
                                              ),
                                              SizedBox(
                                                height: theme.spacings.xxs,
                                              ),
                                              Text(
                                                getStatusText(
                                                  widget.project!.status,
                                                ),
                                                style: theme
                                                    .commonTextStyles
                                                    .caption
                                                    .copyWith(
                                                      color: palette
                                                          .text
                                                          .secondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '0:00h', // Default time
                                          style:
                                              theme.commonTextStyles.bodyBold,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
```

Replace it with:

```dart
                            else
                              Column(
                                spacing: theme.spacings.lg,
                                children: projectTasks.map((task) {
                                  final duration = context
                                          .watch<EntityResolver>()
                                          .getResolvedTask(task.id)
                                          ?.duration(DateTime.now()) ??
                                      Duration.zero;
                                  return MasterListCard(
                                    title: task.title,
                                    metadata: getTaskStatusText(task.status),
                                    trailing: Text(
                                      _formatExactDuration(duration),
                                      style: theme.commonTextStyles.bodyBold,
                                    ),
                                    onTap: () => context
                                        .read<AppNavigationController>()
                                        .openTask(task.id),
                                  );
                                }).toList(),
                              ),
```

- [ ] **Step 5: Verify it compiles and analyzes clean**

Run (from `apps\worklog_studio\`): `fvm flutter analyze`
Expected: No errors or warnings introduced by this change.

- [ ] **Step 6: Manual smoke check**

Run (from `apps\worklog_studio\`): `fvm flutter run -d windows`
Open the Projects screen, open a project that has at least one task, open its drawer, and confirm: the "Associated Tasks" header now matches the `LabeledDivider` style of `Notes`/`Overview`, each row shows the task's own status (not the project's) and a real (non-zero, if time has been logged) duration, and tapping a row switches to the Tasks screen with that task's drawer open and the row scrolled into view. Also open a project with zero tasks and confirm the existing empty-state message still shows.

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/feature/projects/presentation/components/project_drawer.dart
git commit -m "Make ProjectDrawer's associated-tasks list clickable; fix status/duration bugs"
```
