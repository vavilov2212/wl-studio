# Structural Refactoring Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve long-term maintainability, testability, and developer velocity by eliminating structural debt accumulated since the initial build.

**Architecture:** The app is a Flutter Windows desktop app following a vertical-slice feature layout with BLoC for async state and Provider/ChangeNotifier for shared application state. The refactoring preserves this architecture and deepens its consistency rather than replacing it.

**Tech Stack:** Flutter (FVM), Dart, flutter_bloc, provider, get_it/injectable, sqflite, freezed, melos monorepo.

---

## How to Read This Plan

Items are ordered **from broadest to most surgical**. Items at the top affect the entire codebase; items at the bottom affect a single file or pattern. Each item lists:
- **Problem** - what is wrong and where
- **Fix** - what the change is
- **Impact** - what gets better

This is a refactoring menu, not a linear sequence. Some items are prerequisites for others (marked with `Depends on`). Independent items can be tackled in any order.

---

## Tier 1 - Architecture-Wide (Touches Every Feature)

---

### Item 1: Commit to a single vertical-slice feature structure

**Problem:** Features are structurally inconsistent. `home` and `work_log` have full vertical slices (`bloc/`, `data/`, `presentation/`, `presentation/components/`). `history`, `projects`, `tasks` have only `presentation/` and no own state layer. `settings` is entirely flat with no subfolders. `desktop` uses `ipc/` instead of `data/`. The inconsistency means a developer cannot infer where to look for logic in an unfamiliar feature.

**Fix:** Define and document a canonical feature scaffold:
```
feature/<name>/
  bloc/               (BLoC or Cubit + events + states)
  data/
    data_source/      (raw DB/network access)
    repository/       (implements domain interface)
    usecases/         (if needed)
  domain/             (abstract interfaces, entity-specific to the feature)
  presentation/
    <name>_page.dart  (entry-point screen widget)
    components/       (sub-widgets used only by this feature)
```
Apply this scaffold to every feature folder. Features that currently have no `bloc/` get one added when Item 5/6/7 is executed. Features that have no `data/` keep them absent rather than creating empty folders. The canonical structure must be documented in `CLAUDE.md`.

**Impact:** Any engineer can find the BLoC for a feature without reading the code. Onboarding time drops.

---

### Item 2: Remove all `setState` calls that manage non-local state

**Problem:** `setState` is used in 19 files with 77 total calls. Most are appropriate (hover, focus, animation toggles). However several manage state that crosses widget boundaries or that drives business logic:
- `GlobalTimeTrackerPanel` (in `app_shell.dart`) uses `setState` to track draft project/task/comment. This state is referenced by BLoC event dispatch logic, making it cross-cutting.
- `MiniPanel._MiniPanelState` uses `setState` for `_searchQuery` and `_searchResults` which are derived from repository data, not purely visual.
- All three drawer widgets (`TimeEntryDrawer`, `TasksDrawer`, `ProjectDrawer`) use `setState` to track `_draft` - a complex domain object.

**Fix:** Extract draft/search state into a dedicated Cubit per widget (see Items 12, 14, 17). After extraction, the remaining `setState` calls in those widgets will be purely cosmetic (hover, animation, focus) and are appropriate.

**Impact:** BLoC/Cubit becomes the single place to look for any stateful logic. Widget `build()` methods become pure rendering functions.

---

### Item 3: Decide between get_it and manual instantiation - eliminate the hybrid

**Problem:** The codebase uses two competing dependency injection approaches simultaneously:
1. `get_it` + `injectable` is configured in `core/services/service_locator/service_locator.dart`. The `IdleMonitor` is registered there and retrieved via `getIt<IdleMonitorService>()` inside a `try/catch` that **silently swallows errors** if the service is not found.
2. Core repositories (`SqliteTimeEntryRepository`, `SqliteProjectRepository`, `SqliteTaskRepository`) are manually instantiated in `app.dart`'s `MultiProvider` — bypassing get_it entirely.
3. `SqliteSettingsRepository` is instantiated inline (`final _settingsRepository = SqliteSettingsRepository()`) inside `WindowsDesktopService` — bypassing both.

The result: there is no single authoritative answer to "how do I get a repository?" A developer adding a new feature cannot know which pattern to follow.

**Fix (Option A - commit to get_it):** Register all repositories and services with `@injectable` annotations. Remove manual `MultiProvider` instantiation of repos. Replace the silent try/catch in IdleMonitor retrieval with an explicit fail-fast assertion. This is the larger change but produces a fully DI-managed app.

**Fix (Option B - remove get_it):** Remove `get_it` and `injectable` deps. They are only used for `IdleMonitor` and `UserRepository`. Move those two registrations into the existing `MultiProvider` setup. Simpler codebase surface area.

**Recommendation:** Option B unless the team plans to add many more services. The current usage does not justify the `injectable` code generation overhead.

**Impact:** One consistent pattern. Silent failure on missing service registration is eliminated.

---

### Item 4: Add l10n infrastructure and migrate all hardcoded UI strings

**Problem:** There are approximately 40 `// TODO: l10n` comments across all feature screens. Every single user-visible string is hardcoded. Zero localization infrastructure exists. This is a large but purely mechanical debt.

**Files affected:** Every screen and drawer file (history_page, tasks_page, projects_page, home_page, settings screens, all drawers, mini_panel, app_shell, welcome_layout).

**Fix:**
1. Add `flutter_localizations` SDK dep and `intl` to `apps/worklog_studio/pubspec.yaml`.
2. Create `lib/l10n/app_en.arb` with all string keys.
3. Run `fvm flutter gen-l10n` to generate `AppLocalizations`.
4. Replace each hardcoded string with `context.l10n.keyName`. Remove all `// TODO: l10n` comments.
5. Add a lint rule or CI check that rejects new hardcoded string literals in `lib/feature/` files.

**Note:** The placeholder footer stat `'Today 06h 15m   |   Total 24h 30m'` in `mini_panel.dart` line 874 is not a localization issue but dead placeholder data that must be replaced with real computed values (see Item 38).

**Impact:** Every user-visible string has a single source of truth. The app is ready to add languages later with no structural changes.

---

### Item 5: Replace enum-based routing with go_router

**Problem:** Navigation is implemented as a `_currentRoute` state variable in `AppShell` that drives a `switch` statement in `_buildActiveScreen()`. This works for a small number of screens but has several limitations:
- Pages are always recreated on tab switch (no `IndexedStack`, no page state preservation). The current team appears to accept this trade-off, but it is implicit.
- Deep linking from the tray IPC uses a string-based route dispatch (`'history'`, `'tasks'`) that must be manually kept in sync with the `AppRoute` enum.
- Drawers use `AppNavigationController` (a plain object with registered callbacks) to trigger route changes. This is a non-obvious indirection with no type safety.
- Adding a new screen requires changes in 4+ places: the enum, the switch, the sidebar, the IPC handler, and the navigation controller.

**Fix:** Introduce `go_router`. Map each current `AppRoute` value to a path. Replace `AppNavigationController` callback registration with `GoRouter.go()`. The IPC handler maps string commands to paths. `ShellRoute` or `StatefulShellRoute` can preserve page state if desired.

**Note:** This is the highest-complexity item in the plan. It touches every screen widget, the IPC bridge, and the navigation controller. It should be its own isolated branch and PR.

**Impact:** Single place to define all routes. IPC navigation becomes type-safe. New screens have a clear registration point.

---

### Item 6: Introduce a consistent repository interface pattern

**Problem:** Abstract repository interfaces are scattered inconsistently across the codebase:
- `TimeEntryRepository` and `Clock` are defined in `domain/time_tracker.dart` alongside domain entities.
- `ProjectRepository` and `TaskRepository` interfaces are referenced from `ProjectTaskState` but their definition location is not the same file.
- `BackupRepository` is in `domain/backup.dart`.
- `SettingsRepository` is used by `WindowsDesktopService` but its interface location is unclear.
- No consistent naming convention (`IRepository` vs `Repository` suffix vs bare noun).

**Fix:** Move all repository interfaces to their owning feature's `domain/` folder. Adopt a single naming convention: `abstract interface class ProjectRepository` (no `I` prefix, no suffix). Document the pattern in `CLAUDE.md`.

**Impact:** `grep -r "abstract interface class"` lists all contracts. Finding the interface for any entity is predictable.

---

## Tier 2 - Massive File Splits

---

### Item 7: Split `app_shell.dart` (1013 lines) into 4 files

**Problem:** `app_shell.dart` contains four independent classes with different responsibilities:
1. `AppShell` - route switcher, drawer integration, IPC navigation subscriptions (~200 lines)
2. `TopAppBar` - top app bar rendering with breadcrumbs (~100 lines)
3. `GlobalTimeTrackerPanel` - the main time tracking bar, project/task/comment selectors, BLoC event dispatch (~420 lines, see also Item 12)
4. `SidebarNavigation` - collapsible left sidebar with settings section (~270 lines)

**Fix:** Extract into individual files:
- `feature/app/layout/app_shell.dart` - keep only `AppShell` (route switcher + wiring)
- `feature/app/layout/app_bar/top_app_bar.dart` - move `TopAppBar`
- `feature/time_tracker/presentation/global_time_tracker_panel.dart` - move `GlobalTimeTrackerPanel`
- `feature/app/layout/sidebar_navigation.dart` - move `SidebarNavigation`

`app_shell.dart` will shrink to ~200 lines after extraction.

**Impact:** Each class can be reviewed, tested, and modified in isolation. `GlobalTimeTrackerPanel` ends up in the `time_tracker` feature where it logically belongs.

---

### Item 8: Split `mini_panel.dart` (1051 lines) into 4 files

**Problem:** `mini_panel.dart` is a single 1051-line file containing:
1. `MiniPanel` + `_MiniPanelState` (the top-level stateful widget, ~700 lines of state)
2. `_MiniActiveTimerTextWrapper` (private widget at bottom of file, ~60 lines)
3. `_HoverableListItem` (reusable hoverable row widget, ~80 lines)
4. Date/duration formatting helpers (`_formatDateHeader`, `_formatDuration`) duplicated from other files

The `_MiniPanelState.build()` method is ~200 lines with 7 private builder sub-methods each 40-120 lines long.

**Fix:**
- `feature/desktop/presentation/mini_panel.dart` - keep `MiniPanel` shell, reduce state class to orchestration only
- `feature/desktop/presentation/components/mini_active_timer_text_wrapper.dart` - extract `_MiniActiveTimerTextWrapper`
- `feature/desktop/presentation/components/mini_hoverable_list_item.dart` - extract `_HoverableListItem`
- Move date/duration formatting to the shared utility (see Item 29)
- Extract each builder method (`_buildActiveSession`, `_buildSearchResults`, `_buildRecentActivity`, `_buildTaskItem`) into named private widgets or their own files

**Impact:** The state class shrinks from ~900 to ~250 lines. Each extracted component is independently reviewable and testable.

---

### Item 9: Split `history_page.dart` (846 lines) into 3 files

**Problem:** `history_page.dart` contains:
1. `HistoryScreen` - the page widget with KPI calculation embedded in `build()` (~200 lines)
2. `TimeEntryList` - a separate widget class responsible for view-mode switching (card vs table) and grouping entries by date (~350 lines)
3. `_KpiChip` - a small display-only widget (~50 lines)
4. `WsTable` column definitions with inline date/duration formatters (~170 lines)
5. Inline KPI computation logic (today's hours, week hours, unassigned count) embedded inside `HistoryScreen.build()`

**Fix:**
- `feature/history/presentation/history_page.dart` - keep `HistoryScreen` as coordinator
- `feature/history/presentation/components/time_entry_list.dart` - extract `TimeEntryList`
- `feature/history/presentation/components/history_kpi_strip.dart` - extract KPI strip (chip row + calculation)
- `feature/history/presentation/components/time_entry_table.dart` - extract `WsTable` column definitions
- Move date/duration formatting to shared utility (see Item 29)

**Impact:** KPI calculation becomes testable in isolation. The history page becomes a thin composition layer.

---

### Item 10: Split `tasks_page.dart` (423 lines)

**Problem:** `tasks_page.dart` contains `TasksScreen` (the page), two distinct view modes (card view + table view with column definitions), and an embedded KPI row. This mirrors the same structural problem as `history_page.dart`.

**Fix:** Same split pattern as Item 9:
- `feature/tasks/presentation/tasks_page.dart` - page coordinator only
- `feature/tasks/presentation/components/task_list.dart` - card/table switcher
- `feature/tasks/presentation/components/task_table.dart` - `WsTable` column definitions

**Impact:** Consistent structure with history page.

---

### Item 11: Split `projects_page.dart` (400 lines)

**Problem:** Same pattern as tasks_page.dart - mixed page/list/table concerns in one file.

**Fix:** Same split pattern:
- `feature/projects/presentation/projects_page.dart` - coordinator
- `feature/projects/presentation/components/project_list.dart` - card/table switcher
- `feature/projects/presentation/components/project_table.dart` - column definitions

**Impact:** Consistent structure across the three main list screens.

---

## Tier 3 - BLoC Layer Additions

---

### Item 12: Extract `GlobalTimeTrackerPanel` state into a Cubit

**Problem:** `GlobalTimeTrackerPanel` (currently embedded in `app_shell.dart`) manages:
- Three `InlineFieldController`s for project, task, comment selectors
- A `TextEditingController` for the comment field
- Draft state (selected project, task, comment text)
- Firing `TimeTrackerBloc` events (start, stop, update comment, update project, update task)
- Inline create-project and create-task flows via `ProjectTaskState.createProject()`

All of this is in `_GlobalTimeTrackerPanelState`. It is untestable because there is no state class to unit-test.

**Fix:** Create `feature/time_tracker/bloc/tracker_panel_cubit.dart` with:
```dart
class TrackerPanelCubit extends Cubit<TrackerPanelState> {
  // handles: draft project/task/comment selection
  // delegates: start/stop/update to TimeTrackerBloc via injection
  // exposes: draftProject, draftTask, draftComment as state fields
}
```
The widget becomes a pure rendering function consuming the Cubit state.

**Depends on:** Item 7 (extract GlobalTimeTrackerPanel to its own file first).

**Impact:** The tracker panel's logic is unit-testable. The widget `build()` method becomes ~80 lines.

---

### Item 13: Create `HistoryBloc` for the history screen

**Problem:** `HistoryScreen` has no own BLoC. It reads state directly from `TimeTrackerBloc` and `EntityResolver` via `context.watch`. Filter/sort state lives in `PageUiPreferences` (a shared ChangeNotifier). KPI calculations are inlined in `build()`. The screen cannot be unit-tested.

**Fix:** Create `feature/history/bloc/history_bloc.dart`:
```dart
// Events: FilterChanged, SortChanged, ViewModeChanged, Refresh
// State: entries (List<ResolvedTimeEntry>), filters, sort, viewMode, kpis (todayHours, weekHours, unassignedCount)
// Sources data from: TimeTrackerBloc stream (listen to state changes)
```
The screen widget consumes `HistoryBloc` state. Filter/sort state moves from `PageUiPreferences` to `HistoryBloc`.

**Impact:** History screen logic is testable. `PageUiPreferences` shrinks (it currently holds filter/sort state for all three list screens).

---

### Item 14: Create `TasksBloc` for the tasks screen

**Problem:** Same pattern as history screen. `TasksScreen` reads from `EntityResolver` and `PageUiPreferences` directly with no own BLoC.

**Fix:** Create `feature/tasks/bloc/tasks_bloc.dart`:
```dart
// Events: FilterChanged, SortChanged, ViewModeChanged
// State: tasks (List<ResolvedTask>), filters, sort, viewMode
```

**Impact:** Tasks screen logic is testable.

---

### Item 15: Create `ProjectsBloc` for the projects screen

**Problem:** Same pattern. `ProjectsScreen` reads from `EntityResolver` and `PageUiPreferences` directly.

**Fix:** Create `feature/projects/bloc/projects_bloc.dart`:
```dart
// Events: FilterChanged, SortChanged, ViewModeChanged
// State: projects (List<ResolvedProject>), filters, sort, viewMode
```

**Impact:** Projects screen logic is testable.

---

### Item 16: Reduce `PageUiPreferences` to display-only preferences

**Problem:** `PageUiPreferences` (a ChangeNotifier) currently holds filter and sort state for all three list screens combined. After Items 13-15 extract those into feature BLoCs, `PageUiPreferences` should only hold view-mode preferences (card vs table) that need to persist across navigation.

**Fix:** After Items 13-15 are complete, remove filter/sort fields from `PageUiPreferences`. Evaluate whether view-mode state belongs in each feature's BLoC or should remain in `PageUiPreferences` for persistence. If the view-mode choice should survive tab switches, keep it in `PageUiPreferences` with a narrowed interface.

**Depends on:** Items 13, 14, 15.

**Impact:** `PageUiPreferences` has a clear, minimal responsibility. No ChangeNotifier holds business-domain filter state.

---

## Tier 4 - Drawer Code Deduplication

---

### Item 17: Extract shared drawer scaffold and draft lifecycle into a reusable base

**Problem:** The three main edit/create drawers (`TimeEntryDrawer`, `TasksDrawer`, `ProjectDrawer`) are structurally near-identical copies. Each has:
- A `_draft` field of a different domain type
- Five `InlineFieldController` instances managed in `initState`/`dispose`
- A `_saving` boolean flag driving a loading state
- A delete confirmation flow (same UI pattern - warning text, `Delete`/`Cancel` buttons)
- An `_updateDraft()` method that calls `addPostFrameCallback` to schedule state mutations
- Inline create-project or create-task sub-flows that call `ProjectTaskState.createProject()`

Lines: 782 + 690 + 544 = **2016 lines** of near-duplicate code.

**Fix:** Create a `DrawerFormCubit<T>` base or `DrawerDraftMixin` that handles:
```dart
// draft: T  (generic domain object)
// saving: bool
// confirmingDelete: bool
// updateDraft(T newDraft)
// save() -> Future<void>
// delete() -> Future<void>
// confirmDelete() / cancelDelete()
```
Each drawer becomes a thin UI layer over `DrawerFormCubit<ResolvedTimeEntry>` (or Task, or Project). The three `initState`/`dispose` patterns become one.

**Impact:** 2016 lines of duplicated code shrinks to roughly 300 lines of base + 3 x 200-line thin wrappers. Adding a new drawer type costs ~200 lines, not 700.

---

### Item 18: Extract inline create-project flow from all drawers

**Problem:** All three drawers contain identical code for inline project creation:
```dart
actions: [
  SelectCreateAction(
    label: 'Create new project',  // TODO: l10n
    onTap: () async {
      final result = await context.read<ProjectTaskState>().createProject(...);
      setState(() { _draft = _draft.copyWith(project: result); });
    },
  ),
]
```
This is copy-pasted verbatim in `time_entry_drawer.dart`, `tasks_drawer.dart`, and `project_drawer.dart`.

**Fix:** Create `feature/common/presentation/components/project_selector.dart` - a reusable `ProjectSelector` widget that encapsulates the `Select` + `SelectCreateAction` + inline create flow. Accept `onProjectSelected` callback. The three drawers replace their inline implementations with `ProjectSelector(onSelected: ...)`.

**Impact:** The inline create pattern is defined once. A bug fix in the flow applies to all three drawers.

---

### Item 19: Extract inline create-task flow from all drawers

**Problem:** Identical to Item 18 but for task creation. `time_entry_drawer.dart` and `tasks_drawer.dart` both contain copy-pasted inline task creation code.

**Fix:** Create `feature/common/presentation/components/task_selector.dart` - analogous to `ProjectSelector` from Item 18. Accept `projectId` as input (tasks are filtered by project) and `onTaskSelected` callback.

**Impact:** Task selector logic defined once.

---

### Item 20: Extract delete confirmation flow from all drawers

**Problem:** The delete confirmation UI (warning text + `Delete`/`Cancel` buttons that appear on a two-step delete) is copy-pasted in all three drawers and uses the same `_confirmingDelete` boolean state pattern.

**Fix:** Create `feature/common/presentation/components/delete_confirmation_row.dart`:
```dart
class DeleteConfirmationRow extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String entityLabel; // 'time entry', 'task', 'project'
}
```

**Impact:** Delete confirmation UI and copy are defined once.

---

## Tier 5 - Service / Repository Layer Cleanup

---

### Item 21: Split `ProjectTaskState` into `ProjectRepository` cache and `SelectionDraftState`

**Problem:** `ProjectTaskState` (ChangeNotifier) mixes four concerns:
1. Holds a cached list of all projects and tasks (repository cache)
2. Provides CRUD operations (createProject, createTask, updateProject, etc.)
3. Tracks the "draft" selected project and task for the active timer panel
4. Triggers `loadData()` reloads after every CRUD operation

The result: a widget that only needs to display the list of projects for a dropdown must receive the full `ProjectTaskState` including the timer draft selection.

**Fix:** Split into two classes:
- `ProjectTaskRepository` (ChangeNotifier or simple service): holds the cached list, exposes CRUD, fires `notifyListeners()` on changes. Has no knowledge of "selected" state.
- `TrackerSelectionState` (or fold into `TrackerPanelCubit` from Item 12): holds the currently-selected project/task for the active timer. Depends on `ProjectTaskRepository` for validation.

**Impact:** Drawers that only need the project list do not receive timer selection state. `ProjectTaskState` logic becomes testable (currently untested).

---

### Item 22: Fix `SqliteSettingsRepository` instantiation in `WindowsDesktopService`

**Problem:** `WindowsDesktopService` instantiates `SqliteSettingsRepository` directly:
```dart
final _settingsRepository = SqliteSettingsRepository();
```
This bypasses all dependency injection and makes `WindowsDesktopService` impossible to unit-test with a fake settings store.

**Fix:** Inject `SettingsRepository` (abstract interface) via constructor:
```dart
WindowsDesktopService(SettingsRepository settingsRepository, ...)
```
Update `runner.dart` or the DI setup to supply the concrete `SqliteSettingsRepository`.

**Impact:** `WindowsDesktopService` becomes unit-testable with a fake settings repository.

---

### Item 23: Register all repositories with get_it (if Option A chosen in Item 3)

**Problem:** If the team chooses to commit to get_it (Item 3, Option A), the repositories currently instantiated manually in `app.dart` must be registered with `@injectable`.

**Depends on:** Item 3 decision.

**Fix:** Add `@injectable` / `@singleton` annotations to each repository implementation. Remove manual instantiation from `app.dart`. Update `service_locator.dart` to initialize all repositories. Replace `MultiProvider` entries for repos with `BlocProvider`/`RepositoryProvider` that retrieve from `getIt`.

---

### Item 24: Fix silent failure in `IdleMonitor` retrieval

**Problem:** In `app.dart` (or wherever IdleMonitor is retrieved):
```dart
try {
  getIt<IdleMonitorService>()...
} catch (e) {
  // silently swallowed
}
```
If `IdleMonitorService` is not registered, the idle detection feature silently stops working with no log, no crash, no indication.

**Fix:** Remove the try/catch. If `IdleMonitor` is only available on certain platforms, use a conditional registration:
```dart
if (Platform.isWindows) {
  getIt.registerSingleton<IdleMonitorService>(WindowsIdleMonitor());
}
```
Then retrieve without try/catch. On other platforms, do not retrieve it at all.

**Impact:** Failures are visible during development. Platform-conditional logic is explicit.

---

## Tier 6 - Design System / Theme Cleanup

---

### Item 25: Move all hardcoded `Color(0xFF...)` values in `mini_panel.dart` to theme tokens

**Problem:** `mini_panel.dart` contains 9 hardcoded color values:
- `Color(0xFFeaeffd)` - border color, repeated 5 times (lines 156, 469, 573, 610, 634)
- `Color(0xFFf8fafc)` - background color, repeated 2 times (lines 724, 823)
- `Color(0xFFebf0fd)` - alternate border color (line 743)
- `Colors.white` used for sidebar contrast

The same `Color(0xFFf8fafc)` also appears in `feature/app/app.dart` (line 54) as `MiniApp` scaffold background, meaning it is used in two places without a shared token.

**Fix:** Add named tokens to `AppThemeExtension` or `ColorsPalette`:
```dart
// In packages/worklog_studio_style_system/lib/theme/colors_palette/
Color miniPanelBorder;           // was Color(0xFFeaeffd)
Color miniPanelBackground;       // was Color(0xFFf8fafc)
Color miniPanelAltBorder;        // was Color(0xFFebf0fd)
```
Reference via `theme.extension<AppThemeExtension>()!.miniPanelBorder` everywhere.

**Impact:** Changing the mini panel color scheme requires editing one file. Dark mode support for mini panel becomes possible.

---

### Item 26: Move `SidebarNavigation` hardcoded `Colors.white` to theme tokens

**Problem:** `SidebarNavigation` (in `app_shell.dart`) uses `Colors.white.withValues(alpha: ...)` in 10+ places for hover/active/inactive states. These are not referenced from the theme.

**Fix:** Add sidebar-specific tokens to `AppThemeExtension`:
```dart
Color sidebarItemHover;
Color sidebarItemActive;
Color sidebarItemInactive;
```

**Depends on:** Item 7 (extract SidebarNavigation first, then update it).

**Impact:** The sidebar color scheme is in one place. Dark mode sidebar is possible.

---

### Item 27: Move `badge_utils.dart` color palette to theme tokens

**Problem:** `feature/common/utils/badge_utils.dart` contains 14 hardcoded `Color(0xFF...)` pairs as a badge color palette. These are used throughout the app for project/task badge tinting. They live in the app's `feature/common/utils/` directory, not in the style system package.

**Fix:** Move the palette definition to `packages/worklog_studio_style_system/lib/theme/colors_palette/badge_palette.dart`. Keep `badge_utils.dart` as a lookup utility but source the colors from the theme package.

**Depends on:** Coordination with `design-system-guard` skill boundaries (style tokens belong in the package, not the app).

**Impact:** Badge colors can be updated in the theme package. Colors are part of the documented design system.

---

### Item 28: Replace hardcoded `SizedBox(height: 4)` and `SizedBox(height: 2)` with spacing tokens

**Problem:** `history_page.dart` lines 834-835 use `const SizedBox(height: 4)` and `const SizedBox(height: 2)`. The app has a `theme.spacings` system with `xs`, `sm`, `md`, etc. These two values bypass it. A grep for `SizedBox(height: [0-9])` and `SizedBox(width: [0-9])` across the codebase may reveal additional occurrences.

**Fix:** Replace with `SizedBox(height: theme.spacings.xs)` or create a `xxs` token if 2px is a deliberate sub-token value. Audit all `SizedBox` with literal numeric args.

**Impact:** All spacing values flow through the design system.

---

## Tier 7 - Dead Code Removal

---

### Item 29: Delete `data/in_memory_time_entry_repository.dart`

**Problem:** `apps/worklog_studio/lib/data/in_memory_time_entry_repository.dart` is 48 lines where every line is commented out. The class was the original in-memory test repository, superseded by `SqliteTimeEntryRepository` and test fakes in `test/helpers/test_fakes.dart`. It serves no purpose.

**Fix:** `git rm apps/worklog_studio/lib/data/in_memory_time_entry_repository.dart`

**Impact:** Zero production code refers to this file. Removal is safe.

---

### Item 30: Remove or isolate the `work_log` feature

**Problem:** The `feature/work_log/` subtree (7 files including `welcome_layout.dart` at 470 lines, `data_layout.dart`, `raw_data_view.dart`, `plan_json.dart`, `raw_txt.dart`, `WorkLogRawDataBloc`, `WorkLogPage`) is:
- Not referenced from `app_shell.dart`'s routing switch
- Contains `Colors.green`/`Colors.red` debug decorations
- Has commented-out code blocks
- Has a `BoxDecoration(color: Colors.red)` debug marker
- Its `raw_data_view.dart` shows raw JSON import/export UI (prototype-level quality)

`app_shell.dart`'s `AppRoute` enum has no `workLog` entry. This feature appears to be a prototype or earlier design iteration that was never removed.

**Fix (Option A - delete):** Confirm with the team whether this feature is planned for reactivation. If not, delete the subtree: `git rm -r apps/worklog_studio/lib/feature/work_log/`. Also remove `WorkLogRawDataBloc` registration if any.

**Fix (Option B - isolate):** Move to a `feature/work_log/_archive/` subdirectory or a separate branch for reference. Clearly mark with a `// PROTOTYPE: not active` comment at the top of each file.

**Recommendation:** Option A if the team has confirmed this direction is abandoned. The raw-data import/export concept may be valuable but should be rebuilt properly rather than uncommented.

**Impact:** Removes ~1500 lines of dead prototype code from the production tree.

---

### Item 31: Remove `feature/home/data/mock_data.dart`

**Problem:** `feature/home/data/mock_data.dart` (176 lines) contains hardcoded `Project` and `Task` objects with hardcoded `accentColor` values. Its consumer is `feature/home/presentation/navigation/navigation.dart`. If `navigation.dart` is only rendering mock data in a dev/design-time scenario, this file should be behind a build flag or removed entirely.

**Fix:** Trace `mock_data.dart` imports. If it feeds a dead code path (e.g., only used from the `work_log` feature being removed in Item 30), delete it. If it is used in a real screen, replace mock data with real repository data.

**Impact:** Removes hardcoded test data from production code.

---

### Item 32: Replace hardcoded placeholder stats in `mini_panel.dart`

**Problem:** `mini_panel.dart` line 874 contains:
```dart
'Today 06h 15m   |   Total 24h 30m'
```
This is a hardcoded placeholder string displayed as real stats in the mini panel footer.

**Fix:** Wire the footer stats to `MiniTrackerCubit` state or a new computed value from the snapshot data that `MiniTrackerCubit` already receives. The `TimeTrackerSnapshot` likely contains enough data to compute today's total and overall total.

**Impact:** Users see real data instead of hardcoded example data.

---

### Item 33: Remove all commented-out code blocks from production files

**Problem:** Production files contain commented-out code blocks that are not dead code candidates from refactoring - they are simply old implementation attempts or debugging artifacts:
- `welcome_layout.dart` lines 322-323, 440-463: ~27 lines commented out
- `welcome_layout.dart` line 12: commented import
- `data_layout.dart` line 39: commented `rootBundle.loadString`
- `plan_json.dart` line 59: commented `getIt<UserRepository>().sessionStorageRepository.save()`
- `firebase_options.dart` line 13: `// await Firebase.initializeApp(...)`

**Fix:** Delete every commented-out code block. If any were preserved for reference, the git history holds them. The Firebase initialization comment should become an explicit task in a new GitHub issue rather than rotting in production code.

**Impact:** Production files contain only production code.

---

## Tier 8 - Dependency Cleanup

---

### Item 34: Audit and remove `firebase_core` / `firebase_ai` if not active

**Problem:** `firebase_core: ^4.3.0` and `firebase_ai: ^3.6.1` are production dependencies in `pubspec.yaml`. However `firebase_options.dart` line 13 contains `// await Firebase.initializeApp(...)` - the initialization call is commented out. Firebase is not actively used.

**Fix:** Determine whether Firebase/AI features are in the roadmap for the near term.
- If yes: create a tracked issue and leave the deps but add an `// PLACEHOLDER: Firebase not yet initialized` comment (better than a commented-out init call).
- If no immediate plans: remove `firebase_core` and `firebase_ai` from `pubspec.yaml`, delete `firebase_options.dart`, and run `fvm exec melos bootstrap`. This reduces app bundle size significantly (Firebase SDKs are large).

**Impact:** If removed: smaller binary, fewer supply chain deps, cleaner pubspec. If kept: at least the intent is documented.

---

### Item 35: Audit `http` and `idb_shim` dependencies

**Problem:** `http: ^1.6.0` and `idb_shim: ^2.7.1+2` are in `apps/worklog_studio/pubspec.yaml`. No obvious use in the main app code path was found during the survey. `idb_shim` is a browser IndexedDB shim - unusual for a desktop-only Windows app.

**Fix:** Run `grep -r "package:http" apps/worklog_studio/lib/` and `grep -r "package:idb_shim" apps/worklog_studio/lib/`. If no hits in `lib/` (only in `test/` or nowhere), remove from `pubspec.yaml`.

**Impact:** Cleaner dependency graph. Reduced risk of transitive version conflicts.

---

### Item 36: Remove `cached_network_image` from style system package

**Problem:** `packages/worklog_studio_style_system/pubspec.yaml` declares `cached_network_image` as a dependency. A survey of the style system's UI kit components found no usage of `CachedNetworkImage` or network images in any widget. This dep is dead weight in a design-system package.

**Fix:** `grep -r "cached_network_image" packages/worklog_studio_style_system/lib/`. If no hits, remove from `pubspec.yaml` and run `fvm exec melos bootstrap`.

**Impact:** The style system package does not force consumers to pull in a network-image caching library.

---

### Item 37: Remove commented-out `country_flags` dependency

**Problem:** `packages/worklog_studio_style_system/pubspec.yaml` contains:
```yaml
# country_flags: ^1.2.1
```
A commented-out dependency is noise. If it was never used, delete the line. If it was used and removed, the intent to re-add it should be a GitHub issue, not a comment in pubspec.

**Fix:** Delete the commented line.

**Impact:** Clean pubspec.

---

### Item 38: Resolve `dependency_overrides: uuid: ^4.5.2`

**Problem:** `apps/worklog_studio/pubspec.yaml` has:
```yaml
dependency_overrides:
  uuid: ^4.5.2
```
This indicates a transitive dependency conflict that was patched with an override. The root cause (which dep pulls in an older uuid) should be identified. If the offending dep has since released a compatible version, the override can be removed.

**Fix:** Run `fvm dart pub deps --json | grep uuid` to find the conflict source. Check if the dep has been updated. If resolved, remove the override. If not, add a comment explaining which dep forces the override.

**Impact:** Removes a silent version pin that could mask future conflicts.

---

## Tier 9 - Code Quality Patterns

---

### Item 39: Centralize date/duration formatting utilities

**Problem:** Date and duration formatting helpers are duplicated across at least three files:
- `mini_panel.dart`: `_formatDateHeader()`, `_formatDuration()` (private methods)
- `history_page.dart`: inline `DateFormat` and `Duration` formatting in `WsTable` column definitions
- `time_entry_drawer.dart`: `_formatDuration()` and date display logic

`core/utils/date_formatter.dart` exists but is not used for all cases.

**Fix:** Move all formatting logic to `core/utils/date_formatter.dart` (or split into `duration_formatter.dart` for duration-specific logic). Make all formatting functions top-level or static methods. Replace all inline/private duplicates with calls to the shared utility.

**Impact:** Formatting logic has one canonical implementation. A display format change requires one edit.

---

### Item 40: Replace `addPostFrameCallback` draft mutation pattern in drawers

**Problem:** The three drawer widgets use a pattern like:
```dart
void _updateDraft(ResolvedTimeEntry newDraft) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() { _draft = newDraft; });
  });
}
```
This defers state mutation to the next frame to avoid "setState during build" errors. It is a workaround for calling `_updateDraft` from within a builder callback. The root cause is that the draft mutation is triggered by `Select.onChanged` callbacks, which fire during build in some configurations.

**Fix:** After Item 17 (DrawerFormCubit), this pattern is eliminated entirely because draft state lives in the Cubit and Cubit state updates never happen "during build" - they are dispatched as async events. Document why this was necessary in the git commit message for traceability.

**Depends on:** Item 17.

**Impact:** Removes a non-obvious frame-scheduling workaround. Drawer state updates are synchronous and traceable.

---

### Item 41: Convert `MiniTrackerCubit` state class to use Freezed

**Problem:** `MiniTrackerCubit` uses a hand-rolled `MiniTrackerState` class with a manual `copyWith`. All other state classes in the codebase (`TimeTrackerState`, `DashboardChartsState`) use `@freezed`. The inconsistency means `MiniTrackerState` lacks Freezed's equality, `toString`, and pattern matching.

**Fix:** Annotate `MiniTrackerState` with `@freezed`, add the Freezed factory constructor, run build_runner. Remove the hand-written `copyWith`.

**Impact:** Consistent state class pattern across all BLoCs/Cubits.

---

### Item 42: Separate `MiniTrackerCubit` command bus from state management

**Problem:** `MiniTrackerCubit` owns a `StreamController<MiniPanelCommand>` that acts as a side-channel command bus for sending `MiniPanelCommand` events (e.g., `scrollToActive`) to the panel. This is unrelated to the Cubit's state. A Cubit is a state container, not a command bus.

**Fix:** Extract `StreamController<MiniPanelCommand>` into a standalone `MiniPanelCommandBus` class (a simple stream wrapper) provided separately via `Provider`. The Cubit state contains only data. The command bus is a separate object.

**Impact:** The Cubit has a single responsibility. Testing the command bus and state evolution are independent.

---

### Item 43: Remove Russian-language comments from `TimeTrackerBloc`

**Problem:** `feature/time_tracker/bloc/time_tracker_bloc.dart` contains comments in Russian. This is inconsistent with the rest of the codebase (all other comments are in English) and inaccessible to non-Russian-reading contributors.

**Fix:** Translate to English or remove if the comment is self-explanatory from the code. Translating is preferred if the comment explains a non-obvious constraint.

**Impact:** Codebase is fully readable in English.

---

### Item 44: Standardize import style within the app

**Problem:** Some widget files use relative imports for nearby components:
```dart
import 'components/time_entry_card.dart'; // relative
```
Others use absolute package imports:
```dart
import 'package:worklog_studio/feature/history/presentation/components/time_entry_card.dart'; // absolute
```
Both styles work, but mixing them makes refactoring (file moves) harder because relative imports break silently if the consumer is moved.

**Fix:** Adopt a single convention. The Flutter team recommends absolute `package:` imports within a single package. Add a lint rule (`always_use_package_imports` or `prefer_relative_imports` - pick one) to `analysis_options.yaml`. Run a migration pass.

**Impact:** Import style is consistent. File moves do not silently break unrelated imports.

---

### Item 45: Remove `feature/app/app_drawer_host.dart` if superseded

**Problem:** `app_drawer_host.dart` exists at `feature/app/app_drawer_host.dart`. During the survey it was identified as part of the drawer infrastructure. Verify whether it is used or superseded by the `DrawerHostController` in `state/drawer_host_controller.dart`. If both exist and serve the same purpose, consolidate.

**Fix:** Trace all imports of `app_drawer_host.dart`. If it has consumers, document its role. If it is dead, delete it.

---

### Item 46: Consolidate entity resolver logic

**Problem:** `state/entity_resolver.dart` resolves raw IDs (projectId, taskId) to full domain objects (`ResolvedProject`, `ResolvedTask`, `ResolvedTimeEntry`). It is consumed directly in `history_page.dart`, `tasks_page.dart`, and `projects_page.dart` build methods. This resolution logic will move into the feature BLoCs created in Items 13-15, leaving `EntityResolver` as a shared utility service.

**Fix:** After Items 13-15 are complete, refactor `EntityResolver` to be a pure service injected into the new BLoCs. Remove direct `context.watch<EntityResolver>()` calls from widget build methods.

**Depends on:** Items 13, 14, 15.

**Impact:** Widget build methods do not perform O(n) entity resolution on every rebuild.

---

## Tier 10 - Test Coverage Gaps

---

### Item 47: Add unit tests for `ProjectTaskState`

**Problem:** `ProjectTaskState` is a ChangeNotifier that orchestrates all project/task CRUD and holds the draft selection state for the active timer. It is currently untested. It is also one of the most heavily consumed objects in the app (referenced from all three drawer widgets and `GlobalTimeTrackerPanel`).

**Fix:** Create `test/feature/project_task_state_test.dart`. Use existing fake pattern from `test/helpers/test_fakes.dart`. Test:
- `loadData()` populates `projects` and `tasks`
- `createProject()` persists and triggers reload
- `updateProject()` persists and triggers reload
- `deleteProject()` removes and triggers reload (same for tasks)
- Draft selection state changes correctly when project changes

**Impact:** The most-used ChangeNotifier gains a safety net.

---

### Item 48: Add unit tests for `EntityResolver`

**Problem:** `EntityResolver` performs entity resolution (ID -> domain object) using lists from `ProjectTaskState`. It is untested.

**Fix:** Create `test/feature/entity_resolver_test.dart`. Test:
- Resolution of a valid projectId returns the correct `ResolvedProject`
- Resolution of an unknown ID returns a default/null
- Resolution of a time entry with nested project/task references is correct

**Impact:** Entity resolution bugs will be caught before they silently produce empty drawer fields.

---

### Item 49: Add widget tests for the three main drawer widgets

**Problem:** `TimeEntryDrawer`, `TasksDrawer`, and `ProjectDrawer` have zero widget tests. These are the primary data-entry surfaces of the app.

**Fix:** Create:
- `test/widget/time_entry_drawer_test.dart`
- `test/widget/tasks_drawer_test.dart`
- `test/widget/project_drawer_test.dart`

Test each for:
- Opens in create mode (empty fields) vs edit mode (pre-filled fields)
- Save button fires the correct BLoC/Cubit event
- Delete flow shows confirmation then fires delete event
- Project/task selector changes update the draft

Use `MockProjectTaskState` (a fake ChangeNotifier) to supply project/task lists.

**Depends on:** Item 17 (DrawerFormCubit) makes these tests straightforward to write.

**Impact:** Changes to drawer save/delete flows are caught by tests.

---

### Item 50: Add unit tests for `WorkLogRawDataBloc`

**Problem:** `WorkLogRawDataBloc` has no test. It is a simple 2-event / 4-state BLoC that loads raw work log data. Even if the `work_log` feature is being reconsidered (Item 30), the BLoC should be tested before any further work is done on it.

**Fix:** Create `test/feature/work_log_raw_data_bloc_test.dart`. Test the `LoadEvent` -> success/error state transitions using a fake `WorkLogRawDataUseCase`.

**Note:** Skip this item if Item 30 removes the `work_log` feature entirely.

---

### Item 51: Add tests for `GlobalTimeTrackerPanel` Cubit (after Item 12)

**Problem:** The `GlobalTimeTrackerPanel` currently has no tests because its logic is embedded in a StatefulWidget. After Item 12 creates `TrackerPanelCubit`, the draft state management and BLoC event dispatch logic become testable.

**Fix:** Create `test/feature/tracker_panel_cubit_test.dart`. Test:
- Selecting a project updates draft
- Selecting a task filters by selected project
- Starting timer fires correct `TimeTrackerBloc` event
- Stopping timer fires correct event
- Comment update flow

**Depends on:** Item 12.

---

### Item 52: Add tests for `HistoryBloc`, `TasksBloc`, `ProjectsBloc` (after Items 13-15)

**Problem:** Once the three feature BLoCs exist (Items 13-15), they must be tested before being relied upon in production screens.

**Fix:** Create:
- `test/feature/history/history_bloc_test.dart`
- `test/feature/tasks/tasks_bloc_test.dart`
- `test/feature/projects/projects_bloc_test.dart`

Each test file follows the pattern in `test/feature/time_tracker_bloc_test.dart` (the most thorough existing BLoC test, 588 lines - use it as the reference).

**Depends on:** Items 13, 14, 15.

---

## Tier 11 - Subtle / Single-File Improvements

---

### Item 53: Extract `_BarChart` fl_chart configuration to a named builder

**Problem:** `dashboard_charts_section.dart` `_BarChartState.build()` inlines ~150 lines of `fl_chart` `BarChartData` configuration. This configuration is not a layout - it is pure data construction that belongs in a factory method or a `_buildBarChartData()` helper in a companion class.

**Fix:** Extract to `_buildBarChartData(List<BarChartGroupData> groups, double maxY) -> BarChartData` in a private static method or a companion `_DashboardChartBuilder` class.

**Impact:** The `build()` method of `_BarChartState` reads as layout only. The chart data construction is separately readable.

---

### Item 54: Rename `ipc/` folder to `data/` in `feature/desktop`

**Problem:** `feature/desktop/ipc/` contains `ipc_models.dart`. All other features use `data/` for data models and access objects. `ipc` is an implementation detail of the transport, not a layer name.

**Fix:** `git mv apps/worklog_studio/lib/feature/desktop/ipc apps/worklog_studio/lib/feature/desktop/data`. Update one import in whatever file references `ipc_models.dart`.

**Impact:** Consistent folder naming across all features.

---

### Item 55: Move `MiniTrackerCubit` out of `presentation/`

**Problem:** `feature/desktop/presentation/mini_tracker_cubit.dart` lives inside the `presentation/` folder. BLoCs and Cubits belong in `bloc/` per the feature architecture (Item 1). A Cubit is not a presentation artifact.

**Fix:** `git mv feature/desktop/presentation/mini_tracker_cubit.dart feature/desktop/bloc/mini_tracker_cubit.dart`. Update imports.

**Impact:** Consistent feature structure. BLoCs are discoverable by folder convention.

---

### Item 56: Create `feature/settings/` subfolders

**Problem:** `feature/settings/` contains two flat files: `general_settings_screen.dart` and `hotkey_settings_screen.dart`. No subfolders. `hotkey_settings_screen.dart` is 367 lines with all settings logic, hotkey binding UI, and state management inline.

**Fix:**
- Create `feature/settings/presentation/` and move both screen files there.
- If `hotkey_settings_screen.dart` holds non-trivial state logic, extract a `SettingsCubit` into `feature/settings/bloc/`.

**Impact:** Settings feature follows the same structure as every other feature.

---

### Item 57: Extract `_DetailItem` from `tasks_drawer.dart`

**Problem:** `tasks_drawer.dart` defines a `_DetailItem` helper widget at the bottom of the file. This private widget may be reusable in `project_drawer.dart` and `time_entry_drawer.dart` (which likely use an equivalent pattern).

**Fix:** Move `_DetailItem` to `feature/common/presentation/components/detail_item.dart` if it is reused across drawers. If it is tasks-specific, keep it but move it to `feature/tasks/presentation/components/detail_item.dart`.

---

### Item 58: Remove `feature/common/utils/date_format_utils.dart` if subsumed by Item 39

**Problem:** `feature/common/utils/date_format_utils.dart` exists but the survey found date formatting also duplicated in `mini_panel.dart`, `history_page.dart`, and `time_entry_drawer.dart`. After Item 39 centralizes all formatting to `core/utils/date_formatter.dart`, `date_format_utils.dart` may become redundant.

**Fix:** After Item 39, check whether `date_format_utils.dart` is fully subsumed. If yes, delete it and update imports.

**Depends on:** Item 39.

---

### Item 59: Consolidate `app_bar/` files - verify `app_bar_provider.dart` and `app_bar_scope.dart` are not redundant

**Problem:** `feature/app/layout/app_bar/` contains six files: `app_bar.dart`, `app_bar_config.dart`, `app_bar_navigator_observer.dart`, `app_bar_provider.dart`, `app_bar_scope.dart`, `app_bar_service.dart`. The scope/provider/service split (three files for app bar state management) is unusually granular for a component of this scale.

**Fix:** Read all six files. If `app_bar_provider.dart` is a thin wrapper around `app_bar_service.dart`, merge them. If `app_bar_scope.dart` is a thin InheritedWidget wrapper that simply re-exports service, consider merging with the provider.

**Impact:** Fewer files for a single UI component. Easier to onboard to the app bar's behavior.

---

### Item 60: Audit and clean `entity/session/` and `entity/user/` directories

**Problem:** `lib/entity/session/` and `lib/entity/user/` follow a different organizational pattern (`entity/` at the top level with `data/data_source/`, `data/repository/`, `domain/` subfolders) vs the rest of the app which uses `feature/`. These look like early architectural experiments with a more traditional layered structure.

**Fix:** Audit whether `entity/session/` and `entity/user/` are active code paths or proto-features. If active, either:
- Migrate them to `feature/` (for consistency with Item 1)
- Or keep them in `entity/` but document that `entity/` is for cross-cutting auth concerns (different from feature-specific code)

**Impact:** The top-level directory structure has a clear mental model.

---

### Item 61: Delete `feature/common/utils/badge_utils.dart` color redundancy after Item 27

**Problem:** After Item 27 moves badge colors to the style system package, the computation in `badge_utils.dart` that maps entity IDs to color pairs can remain, but the color literal array must come from the style system. If `badge_utils.dart` only contains the color array and a simple modulo lookup, it can be folded into the theme token lookup directly.

**Fix:** After Item 27, assess whether `badge_utils.dart` is still needed as a separate file or if the lookup logic is trivial enough to inline at call sites.

**Depends on:** Item 27.

---

## Appendix: Dependency Graph of Items

Items that must be done before others:
```
Item 3 (DI decision)
  └── Item 23 (register repos with get_it, if Option A)

Item 7 (split app_shell.dart)
  └── Item 12 (TrackerPanelCubit)
      └── Item 51 (TrackerPanelCubit tests)

Item 13 (HistoryBloc)
  └── Item 52 (HistoryBloc tests)
  └── Item 46 (EntityResolver refactor, after all three BLoCs)

Item 14 (TasksBloc)
  └── Item 52 (TasksBloc tests)
  └── Item 46

Item 15 (ProjectsBloc)
  └── Item 52 (ProjectsBloc tests)
  └── Item 46

Item 13 + 14 + 15
  └── Item 16 (reduce PageUiPreferences)

Item 17 (DrawerFormCubit)
  └── Item 40 (remove addPostFrameCallback pattern)
  └── Item 49 (drawer widget tests)

Item 18 (ProjectSelector)
  └── Item 19 (TaskSelector)

Item 39 (centralize formatting)
  └── Item 58 (remove date_format_utils.dart if redundant)

Item 27 (badge colors to theme)
  └── Item 61 (badge_utils.dart cleanup)

Item 29 (delete in_memory repo) - no deps, do immediately
Item 33 (remove commented code) - no deps, do immediately
Item 37 (remove commented dep) - no deps, do immediately
Item 43 (Russian comments) - no deps, do immediately
Item 54 (rename ipc/ to data/) - no deps, do immediately
Item 55 (move MiniTrackerCubit out of presentation/) - no deps, do immediately
```

---

## Quick Wins (No Dependencies, Low Risk, High Signal)

Do these first - each is isolated, reversible, and high-leverage as a proof of health:

| Item | What | Est. effort |
|------|------|-------------|
| 29 | Delete `in_memory_time_entry_repository.dart` | 2 min |
| 37 | Delete commented `country_flags` dep line | 1 min |
| 43 | Translate Russian comments in TimeTrackerBloc | 10 min |
| 33 | Remove all commented-out code blocks | 30 min |
| 54 | Rename `ipc/` folder to `data/` in desktop feature | 10 min |
| 55 | Move `mini_tracker_cubit.dart` from `presentation/` to `bloc/` | 5 min |
| 32 | Wire real stats in mini panel footer (replace hardcoded string) | 1-2 hours |
| 38 | Investigate and document `dependency_overrides: uuid` | 20 min |
| 35 | Grep and possibly remove `http`/`idb_shim` | 15 min |
| 36 | Grep and possibly remove `cached_network_image` from style pkg | 15 min |
