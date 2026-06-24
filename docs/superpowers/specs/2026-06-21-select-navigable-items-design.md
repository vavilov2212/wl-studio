# Select: navigable items (hover + action icon + cross-page navigation)

## Motivation

`Select<T>` (style system) is used throughout the app to pick entities — tasks, projects,
etc. Today an option row only supports click-to-select; there is no hover feedback and no
way to jump to the entity behind an option without leaving the select. This mirrors
Notion's pattern of letting a select's options act as a secondary navigation surface, but
adapted to a click-target split that's simpler and more robust in Flutter (a dedicated
small action icon per row rather than splitting text-vs-row hit testing).

## Scope

1. Reusable capability added to `Select`/`SelectOption` in
   `packages\worklog_studio_style_system\`: row hover effect, an optional per-row action
   icon, and a popup `minWidth` so the popup can exceed the trigger field's width.
2. A lightweight `AppNavigationController` so any widget, regardless of nesting depth, can
   ask the app to switch to an entity's page and open its existing edit drawer — reusing
   the navigate-and-open-drawer-and-scroll-into-view behavior the dashboard already has for
   tasks and history entries.
3. Wiring the action icon, via that controller, on the project/task `Select`s in: the
   tracking panel (`app_shell.dart`'s `_buildProjectSelector`/`_buildTaskSelector`), the
   project select nested inside `TaskDrawer` (`tasks_drawer.dart`), and the project/task
   selects nested inside `TimeEntryDrawer` (`time_entry_drawer.dart`).

   `welcome_layout.dart`'s project/task selects are explicitly excluded: `WorkLogPage`
   (which renders `WelcomeLayout`) is not mounted anywhere in the app — `work_log_page.dart`
   has no importers. Wiring it would be dead work; the actually-live tracking panel is
   `app_shell.dart`'s `InlineField`/`Select` pair.

### Out of scope

- Splitting row clicks into "label navigates / row selects" (Notion's exact model) — using
  a dedicated small action icon instead, per decision.
- Notion's +/- button.
- Lifting `TaskDrawer`/`ProjectDrawer` to a global overlay, or changing their layout from
  inline (`Row` + `Expanded`) to floating — decided to leave drawers exactly as they are.
- Any change to `TimeEntryDrawer`'s own navigability (nothing currently needs to navigate
  *to* a time entry from elsewhere).
- Real OS/page routing — the app has no router; "navigate" here means switching the
  `AppShell` tab and opening that entity's existing drawer.

## Component changes — style system

### `SelectOption<T>` (`select_option.dart`)

Add, both optional and defaulting to `null` (zero behavior change for existing callers):

- `onAction: VoidCallback?`
- `actionIcon: IconData?` (only meaningful if `onAction` is set; falls back to a sensible
  default, e.g. `Icons.open_in_new`, when `onAction` is set but `actionIcon` is not)
- `actionTooltip: String?`

### Row hover (`select_content.dart`)

Each option row is wrapped in a `MouseRegion` tracking hover state per-row (scoped so
hovering one row doesn't rebuild the whole list). On hover, apply a subtle background tint
from existing design tokens, layered with (not replacing) the existing 8% selected-accent
background.

### Action icon (`select_content.dart`)

Each row becomes a `Stack`:

- Base layer: existing row content (leading, label, selected checkmark) — unchanged
  layout/position.
- Overlay layer: if `onAction != null`, a small icon button `Positioned` near the top-right
  corner of the row, small enough that it doesn't fully cover the checkmark. Opacity 0 when
  not hovered, fading in only while that row is hovered.
- Tapping it calls `onAction()`, then closes the popover via the existing `close()` callback
  already threaded through `SelectContent`/`PopoverPrimitive`. It does **not** call
  `onChanged` — selection is left unchanged.
- Tapping anywhere else on the row keeps current behavior (select + close).

### Popup width (`popover_primitive.dart`, `select.dart`)

Add a `minWidth` parameter (default ~240). When `matchTriggerWidth` is true, popup width
becomes `max(triggerWidth, minWidth)` instead of always exactly `triggerWidth`. No visual
change for selects whose content already exceeds the minimum.

## Cross-page navigation

### `AppNavigationController`

A plain class (not tied to widget lifecycle) provided above `AppShell` (e.g. in the app's
root `MultiProvider`):

```dart
class AppNavigationController {
  void Function(String taskId)? _openTaskHandler;
  void Function(String projectId)? _openProjectHandler;
  void Function(String entryId)? _openHistoryEntryHandler;

  void registerHandlers({
    required void Function(String) openTask,
    required void Function(String) openProject,
    required void Function(String) openHistoryEntry,
  }) { ... }

  void openTask(String id) => _openTaskHandler?.call(id);
  void openProject(String id) => _openProjectHandler?.call(id);
  void openHistoryEntry(String id) => _openHistoryEntryHandler?.call(id);
}
```

`_AppShellState.initState` calls `registerHandlers(...)`, wiring in its existing
`_openTask`/`_openHistoryEntry` methods plus a new `_openProject` method that mirrors them
(see below). Any descendant widget calls
`context.read<AppNavigationController>().openProject(id)` etc., regardless of how deeply
it's nested under `AppShell`.

### `ProjectsScreen` parity with `TasksScreen`/`HistoryScreen`

`ProjectsScreen` currently has no equivalent of `TasksScreen`'s `initialSelectedTaskId` /
`_selectTaskById`. Add the same pattern:

- `ProjectsScreen({this.initialSelectedProjectId})`
- `_selectProjectById(String projectId)`: resolves the project, sets `_drawerState` to
  `edit`, and scrolls the row into view via a `GlobalKey` + `Scrollable.ensureVisible` —
  copying `tasks_page.dart:50-70` exactly.
- Called from `initState` and `didUpdateWidget` exactly as `TasksScreen` does.

`AppShell` gains `_pendingProjectId` state and an `_openProject(projectId)` method
(mirrors `_openTask`), and passes `initialSelectedProjectId: _pendingProjectId` into
`ProjectsScreen` in the `IndexedStack`.

## Wiring action icons

For each project/task `SelectOption` built in the following files, set `onAction` to call
the navigation controller with that option's entity id:

- `app_shell.dart` (tracking panel project + task selects) — calls `_openProject`/`_openTask`
  directly, since these are already methods on `_AppShellState` itself.
- `tasks_drawer.dart` (project select nested inside `TaskDrawer`) — via
  `context.read<AppNavigationController>().openProject(option.value)`.
- `time_entry_drawer.dart` (project + task selects nested inside `TimeEntryDrawer`) — via
  `context.read<AppNavigationController>().openProject/openTask(option.value)`.

No drawer layout changes; the existing drawer for the target entity opens on its own page
exactly as the dashboard's "top tasks" / "recent entries" cards already do today.

## Testing

Per the app's TDD guidelines, UI-only widget changes (hover tint, action icon rendering,
popup width) are exempt from mandatory unit tests. Logic extracted from widgets is not
exempt:

- `AppNavigationController`: unit test in `test\core\` covering that `openTask`/
  `openProject`/`openHistoryEntry` call through to registered handlers, and are no-ops
  before handlers are registered.
- `ProjectsScreen._selectProjectById` and `TasksScreen._selectTaskById` are
  widget-local UI state (no existing unit tests cover them) and are exempt per the app's
  "UI-only changes are exempt" rule.
