# Drawer associated-entity lists: clickable + visually consistent

## Motivation

`TaskDrawer` and `ProjectDrawer` each show a list of related entities (a task's
time entries, a project's tasks). Today:

- `ProjectDrawer`'s "Associated Tasks" list (`project_drawer.dart:299-395`)
  renders plain, non-interactive `Container` rows. Each row's status text is a
  copy-paste bug — it shows the **project's** status on every row instead of
  the task's own status — and the trailing time is a hardcoded `'0:00h'`
  stub.
- `TaskDrawer` has no equivalent list of the task's time entries at all.
- The two drawers' section headers are inconsistent: `Notes`/`Overview`/
  `Activity` use `LabeledDivider`, but "Associated Tasks" uses a bespoke
  `Text(h3)` + non-functional "VIEW ALL" link.

This continues the navigable-entities work already shipped for `Select`
dropdowns (`AppNavigationController`, hover/action-icon affordances) by
extending the same "click a related item, jump to it" behavior to these
list sections, and aligning the two drawers' visual structure.

## Scope

1. A reusable section pattern — `LabeledDivider` header, then either an
   empty-state message or a column of clickable rows — used identically in
   both `TaskDrawer` and `ProjectDrawer`.
2. `TaskDrawer` gains a "Time Entries" section listing the task's time
   entries, positioned between `Notes` and `Activity` (mirroring
   `ProjectDrawer`'s `Notes` → `Overview` → `Associated Tasks` flow, where the
   related-entity list comes near the end).
3. `ProjectDrawer`'s existing "Associated Tasks" rows are refactored to use
   the same row component, fixing the status-text bug and the hardcoded
   duration stub along the way (both bugs live entirely inside the code
   being rewritten for this task).
4. Each row, when tapped, navigates to that entity via the existing
   `AppNavigationController` (`openTask`/`openHistoryEntry`) — no new
   navigation plumbing; this reuses the controller and the
   `initialSelectedXId` deep-link wiring already present in `TasksScreen`,
   `ProjectsScreen`, and `HistoryScreen`.

### Out of scope

- Making "VIEW ALL" or "Add Task" functional. "VIEW ALL" is removed (see
  below); "Add Task" is untouched.
- Live-updating duration for a running time entry within these lists.
- Any change to `TimeEntryDrawer` — it has no "associated entities" list to
  update.
- Any change to `AppNavigationController` itself, or to the deep-link wiring
  in `app_shell.dart` — both already support everything this needs.

## Reusable row + section pattern

### Row component

Use the existing `MasterListCard` (`packages/worklog_studio_style_system/lib/ui_kit/src/cards/master_list_card.dart`)
as-is — no style-system changes needed. It already provides
`title` + optional `metadata` + optional `trailing` + `onTap` with hover
styling via `InkWell`.

### Section header

Both sections use `LabeledDivider(label: '<Section Title>')` followed by
`SizedBox(height: theme.spacings.lg)`, exactly matching the existing
`Notes`/`Overview`/`Activity` section headers in both drawers. The current
"Associated Tasks" header (`Text(h3)` + "VIEW ALL") is replaced by this — the
"VIEW ALL" link does nothing today, so removing it eliminates an unfinished
affordance rather than leaving it behind a new, more-finished list.

### Empty state

Both sections share the same empty-state shape (already established by
`ProjectDrawer`): centered, muted body text, `theme.spacings.xl` vertical
padding. Copy is section-specific:

- `ProjectDrawer`: "No tasks associated with this project yet." (unchanged)
- `TaskDrawer`: "No time entries logged for this task yet."

## `TaskDrawer` changes (`tasks_drawer.dart`)

Insert a new section after the `Notes` `InlineField` and before the
`if (!_isNew) [...Activity...]` block, gated the same way (`if (!_isNew)`,
since a new/unsaved task has no time entries to show):

```dart
SizedBox(height: theme.spacings.x2l),
LabeledDivider(label: 'Time Entries'),
SizedBox(height: theme.spacings.lg),
Builder(
  builder: (context) {
    final timeEntries = context
        .watch<EntityResolver>()
        .getResolvedTask(widget.task!.id)
        ?.timeEntries ?? const <TimeEntry>[];

    if (timeEntries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacings.xl),
        child: Center(
          child: Text(
            'No time entries logged for this task yet.',
            style: theme.commonTextStyles.body.copyWith(
              color: palette.text.muted,
            ),
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
            _formatExactDuration(entry.duration(DateTime.now())),
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
```

Add two private formatting helpers to `_TaskDrawerState` (no existing helper
covers entry date-range formatting; `_formatExactDuration` is copied from the
identical implementation already used in `tasks_page.dart`, kept private to
each file per existing convention — there is no shared formatting utility
module today and introducing one is out of scope):

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

New imports needed: `worklog_studio/domain/time_entry.dart`,
`worklog_studio/state/entity_resolver.dart`. (`AppNavigationController` is
already imported.)

## `ProjectDrawer` changes (`project_drawer.dart`)

Replace the header at lines 299-312 (`Row` with `Text('Associated Tasks')` +
`Text('VIEW ALL')`) with:

```dart
LabeledDivider(label: 'Associated Tasks'),
```

Replace the row-building `Column(...).map((task) { return Container(...) })`
at lines 328-395 with:

```dart
Column(
  spacing: theme.spacings.lg,
  children: projectTasks.map((task) {
    final resolvedTask = context
        .watch<EntityResolver>()
        .getResolvedTask(task.id);
    final duration = resolvedTask?.duration(DateTime.now()) ?? Duration.zero;
    return MasterListCard(
      title: task.title,
      metadata: getTaskStatusText(task.status),
      trailing: Text(
        _formatExactDuration(duration),
        style: theme.commonTextStyles.bodyBold,
      ),
      onTap: () =>
          context.read<AppNavigationController>().openTask(task.id),
    );
  }).toList(),
),
```

`getStatusText` (currently only handles `ProjectStatus`) gains a sibling
`getTaskStatusText(TaskStatus status)` method on `_ProjectDrawerState`,
mirroring `_getStatusText` from `tasks_drawer.dart` (`'OPEN'`/`'DONE'`/
`'ARCHIVED'`). `_formatExactDuration` is added the same way as in
`TaskDrawer` (private, copied — same reasoning: no shared formatter module
exists today).

New imports needed: `worklog_studio/state/entity_resolver.dart`,
`worklog_studio/core/services/app_navigation_controller.dart`.

## Testing

Per the app's TDD guidelines, these are UI-only widget changes (new list
rendering, row tap wiring, header swap) — exempt from mandatory unit tests.
No new business logic is introduced; `AppNavigationController` and the
deep-link wiring it calls into are already covered by existing tests from
the prior navigable-Select work.
