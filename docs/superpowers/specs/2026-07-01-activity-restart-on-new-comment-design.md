# Design: Stop+Restart on New Comment in Activity Window

**Date:** 2026-07-01
**Branch:** dev

## Problem

When a user accepts a comment in the activity window that differs from the persisted comment of the current time entry, the intent is "I have moved on to a new activity." The current code only calls `TimeTrackerActiveEntryUpdated` which mutates the comment in place - it does not produce a new time entry boundary. The correct behaviour is: stop the current entry and immediately start a fresh one with the same project and task but the new comment.

An empty comment typed over a non-empty one also counts as a new activity (user deliberately cleared it).

## Scope

Two files change. Nothing below `MiniTrackerCubit` is touched - the leader's `_handleFollowerAction` already handles a `start` action on a running timer (stop + 200 ms delay + restart).

## Design

### `MiniTrackerCubit` - new method

Add `restartWithComment(String? projectId, String? taskId, String comment)`:

```dart
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

This is intentionally separate from `startTimer`. `startTimer` has a guard that no-ops when the same project/task is already running (correct for the mini-panel "click a task row" path). `restartWithComment` skips that guard because the intent here is always "new boundary, same task."

### `ActivityPromptPanel._commit()` - branch on comment change

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

`_lastPersistedComment` is already seeded fresh on every `focusComment` command (i.e. every time the window is shown), so it always reflects the persisted value at the moment the user opened the prompt - exactly the right baseline for the "did the user change anything?" check.

### Affected call sites of `_commit()`

`_commit()` is called from three places inside `_handleCommand`:

| Command | Trigger | Effect after this change |
|---------|---------|--------------------------|
| `acceptComment` | Enter key or global accept hotkey | Stop+restart if comment changed, else update |
| `autoDismissComment` | Reminder timer expired | Stop+restart if comment changed, else update (only called when `text != _lastPersistedComment`, so will always stop+restart in practice) |
| `dismissComment` | Escape key or global dismiss hotkey | Calls `_revert()`, not `_commit()` - unchanged |

### Guard behaviour

If the tracker stops between the window opening and the user pressing Enter, `restartWithComment` returns early (`if (!state.isRunning) return`) - same no-op semantics as `updateComment` today.

## Files Changed

| File | Change |
|------|--------|
| `apps/worklog_studio/lib/feature/desktop/presentation/mini_tracker_cubit.dart` | Add `restartWithComment` method |
| `apps/worklog_studio/lib/feature/desktop/presentation/activity_prompt_panel.dart` | Branch `_commit()` on comment change |

## Test Plan

- `MiniTrackerCubit` unit tests (`test/feature/desktop/mini_tracker_cubit_test.dart`):
  - `restartWithComment` dispatches a `start` action even when project/task match the running entry
  - `restartWithComment` is a no-op when not running
- `ActivityPromptPanel` logic is UI-only (the branching is trivial and exercised via the cubit tests above) - no additional widget test required
