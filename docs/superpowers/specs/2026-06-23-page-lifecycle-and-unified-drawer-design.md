# Page Lifecycle & Unified Drawer Architecture

## Problem

`AppShell` (`apps/worklog_studio/lib/feature/app/layout/app_shell.dart`) currently renders Dashboard, History, Projects, Tasks, and Settings inside an `IndexedStack`. All five pages stay mounted for the lifetime of the app — switching tabs never disposes a page, so every page's local state (selected row, open drawer, applied filters, view mode) lives in memory indefinitely, whether or not the page is visible.

Each of History, Projects, and Tasks additionally duplicates the same pattern independently:
- Local `_drawerState` (`DrawerControllerState<T>`), `_viewMode`, `_filters`, `_filterExpandedOverride`, `_selectedRowKey` held in `setState()`.
- Its own drawer widget (`TimeEntryDrawer`, `TaskDrawer`, `ProjectDrawer`) composed directly in its own `build()`.

There is no shared/unified drawer, and no persistence layer for any UI preference (view mode, filters) today.

A working deep-link mechanism already exists: `AppNavigationController` (`core/services/app_navigation_controller.dart`) exposes `openTask`/`openProject`/`openHistoryEntry`, which `AppShell` relays to the target page via a `_pendingXId` field and the page's `didUpdateWidget`.

## Goals

1. Pages that are not the active tab should not stay resident in memory — switching away from a page should dispose its widget/state.
2. View mode and applied filters should survive navigating away and back (within the app session); selected row and open drawer should reset to closed on a plain tab switch.
3. View mode/filters persistence is in-memory only for this session — no disk persistence (no shared_preferences/hive dependency added).
4. Replace the three separate per-page drawers with one shared drawer host, mounted once at the `AppShell` level.
5. The existing deep-link capability (navigate to a page with an entity pre-selected and its drawer open) must keep working, and should get simpler, not riskier, as a result of this refactor.
6. This redesign applies uniformly to all 5 tabs (Dashboard and Settings included, for architectural consistency), even though they currently have no drawer/filter/view-mode state of their own.

## Non-goals

- No URL-based routing / `go_router` migration. The app has no URL bar (desktop app); the existing `AppRoute` enum + `AppShell` + `AppNavigationController` deep-link mechanism is kept and simplified, not replaced.
- No disk persistence of UI preferences across full app restarts.
- No changes to the visual design of the drawers themselves (`TimeEntryDrawer`/`TaskDrawer`/`ProjectDrawer` content stays as-is — only who drives them changes).

## Architecture

### 1. Lazy page switcher (fixes memory residency)

Replace the `IndexedStack` in `AppShell._buildActiveScreen()` with a function that builds only the active page:

```dart
Widget _buildActiveScreen() => _pageBuilders[_currentRoute.index]();
```

Because the previous page's widget subtree is no longer present in the tree after a tab switch, Flutter disposes it (its `State.dispose()` runs) automatically. No custom keep-alive, `Offstage`, or caching widget is needed — the flat 5-tab structure doesn't warrant one.

Consequence: any state a page needs to survive a switch (view mode, filters) must live *above* the page widget, not inside it. That's the next piece.

### 2. `PageUiPreferences` — session-scoped view mode & filter store

A new `ChangeNotifier`, provided at the app root alongside the existing `ProjectTaskState`, `TimeTrackerBloc`, and `EntityResolver` (see `runner.dart`), so it survives page disposal exactly like those do.

Holds, keyed per page (`history`, `tasks`, `projects`):
- view mode (existing `HistoryViewMode`/equivalent enums per page)
- filters (existing `HistoryFilters`/`TasksFilters`/`ProjectsFilters` value objects)
- filter-expanded override bool (currently `_filterExpandedOverride` per page)

API: `T? viewModeFor(String pageKey)`, `void setViewMode(String pageKey, T mode)`, and equivalent get/set for filters and filter-expanded. Defaults are used when a page is visited for the first time in the session.

Each page's `initState()` reads its initial values from `PageUiPreferences`; every `onViewModeChanged`/`onFiltersChanged`/`onFilterExpandedToggle` callback writes back to the store (in addition to whatever local `setState()` is still needed to trigger a rebuild). In-memory only — lost on full app restart, matching current behavior (nothing persists today either).

Selected row (`_selectedRowKey`, used for scroll-into-view) is **not** stored here — it's transient, recomputed from whatever entity the drawer host currently has open (see below).

### 3. Drawer ownership moves to `AppShell` — `DrawerHostController` + `AppDrawerHost`

Today: `HistoryScreen` returns `Scaffold(body: Row[Expanded(TimeEntryList), TimeEntryDrawer])`; `TasksScreen`/`ProjectsScreen` return `Row[Expanded(list), TaskDrawer/ProjectDrawer]` directly. To unify the drawer, each page's `build()` shrinks to just its content widget (`TimeEntryList`/`TaskList`/`ProjectList`) — the outer `Scaffold` + `Row` + drawer slot move up into `AppShell`:

```dart
Scaffold(
  body: Row([
    Expanded(child: _buildActiveScreen()),  // lazy switcher, section 1
    AppDrawerHost(),                         // new, single instance, lives outside the switched page
  ]),
)
```

**`DrawerHostController`** (new, app-level `ChangeNotifier`, provided at the same level as `PageUiPreferences`): one sealed state replacing the three independent `DrawerControllerState<T>` instances:

```dart
sealed class DrawerHostState {
  const factory DrawerHostState.closed() = _Closed;
  const factory DrawerHostState.timeEntry(TimeEntry entry) = _TimeEntry;
  const factory DrawerHostState.task(Task task) = _Task;
  const factory DrawerHostState.project(Project project) = _Project;
}
```

Methods: `openTimeEntry(TimeEntry)`, `openTask(Task)`, `openProject(Project)`, `close()`.

**`AppDrawerHost`** watches `DrawerHostController` and renders whichever of `TimeEntryDrawer`/`TaskDrawer`/`ProjectDrawer` matches the current state (passing `isOpen`/`entity`/`onClose: controller.close`); the drawer widgets' own internals (animation, layout, content) are unchanged. When state is `closed`, it renders the same "closed" representation the existing drawers already support (e.g. zero-width / collapsed), preserving today's open/close transition.

Pages, on row-select, call `context.read<DrawerHostController>().openTask(task)` (etc.) instead of local `setState(_drawerState = ...)`. List widgets read the currently-selected entity back from the controller (filtered to their own entity type) for row highlighting, replacing `selectedEntry: _drawerState.entity`.

### 4. Reset rule

In `AppShell`, whenever `_currentRoute` changes via a plain tab click (no deep-link target), call `drawerHostController.close()`. This is the single place enforcing "drawer/selection resets on tab switch, persists only when explicitly deep-linked." Deep-link navigation (section 5) is the one path that's allowed to leave the drawer open across a route change.

### 5. `AppNavigationController` simplification

Today, `openTask(id)` sets `_pendingTaskId` on `AppShell`, which threads it into `TasksScreen` as a constructor param; the page picks it up in `didUpdateWidget` and opens its own drawer.

New flow: `openTask(id)` resolves the `Task` via `EntityResolver`/`ProjectTaskState` (already app-level, always alive — no pending-id relay needed), calls `drawerHostController.openTask(resolvedTask)` directly, then sets `AppShell._currentRoute = AppRoute.tasks`. Because the drawer is no longer page-owned, the freshly-mounted `TasksScreen` (built fresh per section 1) doesn't need any pending-id constructor param or `didUpdateWidget` handling at all — the controller already holds the right entity by the time the page builds. `openProject`/`openHistoryEntry` follow the same pattern. The desktop IPC route-string handling (`app_shell.dart`, route name → `AppRoute`) is unaffected.

## Scope: Dashboard & Settings

Dashboard and Settings have no filters/view-mode/drawer state today. They participate in the lazy switcher (section 1) for consistency — they're built/disposed the same way as the other three tabs — but no `PageUiPreferences` entries or drawer wiring are needed for them, since there's nothing to preserve.

## Testing

Per `apps/worklog_studio/CLAUDE.md`, `PageUiPreferences` and `DrawerHostController` are state-machine/business logic and require unit tests written first (TDD), under `test/core/` or `test/feature/`:
- `PageUiPreferences`: default values per page key, get/set round-trip per page key, independence between page keys.
- `DrawerHostController`: open/close transitions for each entity type, closing one type's drawer when a different type opens, `close()` from any state.

Widget-level reshuffling (pages losing their `Scaffold`/`Row`/drawer slot, `AppShell` gaining them) is UI-only composition and is exempt per the same guidelines, but should be exercised manually (tab switching, deep-link from another page, filter/view-mode persistence across tab switches) since no existing widget test suite covers this navigation flow.

## Migration risk notes

- This touches all 3 stateful pages (`history_page.dart`, `tasks_page.dart`, `projects_page.dart`) plus `app_shell.dart` and `app_navigation_controller.dart` — mechanical but sizable; no new dependencies are introduced.
- `_filterExpandedOverride` and scroll-to-selected-row (`_selectedRowKey`) logic must be explicitly carried into the new stores (`PageUiPreferences` for the former, derived from `DrawerHostController`'s current entity for the latter) — called out here so it isn't dropped silently during implementation.
- Because pages are now rebuilt from scratch on every tab switch (no more `IndexedStack` keep-alive), any one-time `initState()` work in the three pages should be reviewed to confirm it's cheap/idempotent — per the codebase survey, the actual data (entries/tasks/projects) lives in app-level `ProjectTaskState`/`TimeTrackerBloc`/`EntityResolver` already, so page `initState()` should only be reading from those, not re-fetching.
