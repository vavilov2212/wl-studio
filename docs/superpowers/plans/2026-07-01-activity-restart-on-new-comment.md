# Activity Window Stop+Restart on New Comment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the user accepts a comment in the activity window that differs from the persisted comment, stop the current time entry and start a fresh one with the same project/task but the new comment.

**Architecture:** One new method on `MiniTrackerCubit` (`restartWithComment`) dispatches a `start` TimerAction unconditionally, bypassing `startTimer`'s same-task guard. `ActivityPromptPanel._commit()` branches on whether the comment changed - calling `restartWithComment` if it did, `updateComment` if it didn't. Nothing below the cubit changes; the leader's `_handleFollowerAction` already handles a `start` on a running timer (stop + 200 ms + restart).

**Tech Stack:** Flutter/Dart, `flutter_bloc`, `desktop_multi_window` IPC

## Global Constraints

- Run tests from `apps\worklog_studio\` with: `fvm flutter test test/core/ test/feature/ --reporter expanded`
- Never run `flutter` directly - always prefix with `fvm`
- No `Co-Authored-By` trailer in commit messages
- No em dash or en dash anywhere (use plain hyphen or comma)
- TDD is mandatory: write the failing test before any implementation code
- Exclude `*.g.dart`, `*.freezed.dart`, `.dart_tool\`, `build\` from all reads

---

### Task 1: Add `restartWithComment` to `MiniTrackerCubit` and branch `_commit()`

**Files:**
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`
- Modify: `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart`
- Test: `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`

**Interfaces:**
- Consumes: `DesktopServiceRegistry.instance.dispatchAction(TimerAction(...))` (existing)
- Consumes: `MiniTrackerCubit.state.activeEntry` (`TimeEntry?` with `.projectId`, `.taskId`) (existing)
- Consumes: `ActivityPromptPanel._lastPersistedComment` (existing field, seeded on every `focusComment`)
- Produces: `MiniTrackerCubit.restartWithComment(String? projectId, String? taskId, String comment)` - called by `ActivityPromptPanel._commit()`

- [ ] **Step 1: Write the failing tests**

Open `apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart`. Add a new group after the existing `'MiniTrackerCubit.updateComment'` group:

```dart
  group('MiniTrackerCubit.restartWithComment', () {
    test('dispatches a start action with the given projectId, taskId and comment when running', () {
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
            projectId: 'p1',
            taskId: 't1',
            comment: 'old comment',
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.restartWithComment('p1', 't1', 'new comment');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.start);
      expect(action.projectId, 'p1');
      expect(action.taskId, 't1');
      expect(action.comment, 'new comment');
    });

    test('dispatches start even when project and task match the running entry', () {
      // Contrast with startTimer which no-ops in this case.
      // restartWithComment always fires to create a new time-entry boundary.
      cubit.updateFromSnapshot(
        TimerSnapshot(
          isRunning: true,
          activeEntry: TimeEntry(
            id: 'e1',
            startAt: DateTime(2025, 1, 1, 9),
            status: TimeEntryStatus.running,
            projectId: 'p1',
            taskId: 't1',
            comment: 'old',
          ),
          entries: const [],
          tasks: const [],
          projects: const [],
          timestamp: 1,
        ),
      );

      cubit.restartWithComment('p1', 't1', '');

      expect(desktopService.dispatched, hasLength(1));
      final action = desktopService.dispatched.single as TimerAction;
      expect(action.type, TimerActionType.start);
    });

    test('does nothing when no session is running', () {
      cubit.restartWithComment('p1', 't1', 'new comment');

      expect(desktopService.dispatched, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests - verify they fail**

```
cd apps\worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart --reporter expanded
```

Expected: compile error - `restartWithComment` is not defined on `MiniTrackerCubit`.

- [ ] **Step 3: Add `restartWithComment` to `MiniTrackerCubit`**

Open `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart`. Add this method directly after `updateComment`:

```dart
  /// Stops the current time entry and starts a fresh one with the same
  /// project and task but a new comment. Unlike [startTimer], this bypasses
  /// the "already tracking same task" guard - the caller has determined that
  /// the comment change represents a new activity, so a new entry boundary
  /// is always required.
  void restartWithComment(String? projectId, String? taskId, String comment) {
    if (!state.isRunning) return;
    DesktopServiceRegistry.instance.dispatchAction(
      TimerAction(
        type: TimerActionType.start,
        projectId: projectId,
        taskId: taskId,
        comment: comment,
      ),
    );
  }
```

- [ ] **Step 4: Run tests - verify they pass**

```
cd apps\worklog_studio
fvm flutter test test/feature/desktop/mini_tracker_cubit_test.dart --reporter expanded
```

Expected: all tests in the file PASS.

- [ ] **Step 5: Branch `_commit()` in `ActivityPromptPanel`**

Open `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart`. Replace the existing `_commit()` method:

```dart
  void _commit() {
    final newComment = _commentController.text;
    final cubit = context.read<MiniTrackerCubit>();
    if (newComment != _lastPersistedComment) {
      final entry = cubit.state.activeEntry;
      cubit.restartWithComment(entry?.projectId, entry?.taskId, newComment);
    } else {
      cubit.updateComment(newComment);
    }
  }
```

- [ ] **Step 6: Run the full test suite**

```
cd apps\worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```
git add apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart
git add apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart
git add apps/worklog_studio/test/feature/desktop/mini_tracker_cubit_test.dart
git commit -m "feat: stop+restart time entry when activity window comment changes"
```
