# POST MORTEM: Worklog Studio - Book of Law

> **Status: authoritative, living document.** This is the accumulated architectural memory
> of the codebase, distilled after every non-trivial development session. It was seeded by
> the full structural refactoring cycle (plan:
> `docs/superpowers/plans/2026-07-07-structural-refactoring.md`, ~55 items executed across
> Tiers 1-10, originally filed as `POST_MORTEM_REFACTOR.md`, renamed here to drop the
> refactor-only framing) and is extended with a new session block every time a feature,
> refactor, redesign, deploy, or debugging run produces a reusable lesson. Every rule below
> was paid for with a real bug, a failed test run, or a dead end - treat them as laws of
> this codebase, not suggestions. Session-specific detail lives in the numbered subsections
> and pitfall entries (tagged with the session date); the four top-level sections
> (Architecture, Guardrails, Pitfalls, Backlog) are the standing, cross-session index.
>
> State at last update (2026-08-10, [redesign] Column layout standardization):
> **341/341 tests green** (no new tests; UI-only change), `flutter analyze` clean on all
> changed files (5 files changed; see 1.14).
> Previous state: 341/341 tests, 2026-08-07 history entry stacking (1.13).

---

## 1. FINAL ARCHITECTURE

### 1.1 Vertical-slice feature layout

Every feature under `apps\worklog_studio\lib\feature\<name>\` follows one canonical scaffold.
Folders that would be empty are omitted - never create placeholder directories.

```
feature/<name>/
  bloc/               BLoC or Cubit + events + states
  data/               feature-specific data sources / usecases (if any)
  presentation/
    <name>_page.dart  entry-point screen widget (thin coordinator)
    components/       sub-widgets used only by this feature
```

Cross-cutting layers outside `feature/`:

| Location | Responsibility |
|---|---|
| `lib\domain\` | Domain entities + **repository interfaces** (`Project`/`ProjectRepository` in `project.dart`, etc.) |
| `lib\data\` | Concrete repository implementations (`sqlite\`), `SystemClock`, `SettingsRepository` interface |
| `lib\state\` | Shared app state consumed by multiple features (`ProjectTaskState`, `EntityResolver`, `DrawerHostController`) |
| `lib\entity\` | Cross-cutting auth/session concerns (session, user) that do not fit a single feature slice |
| `lib\core\` | Services (`TimeTrackerService`, desktop platform services, idle monitor, DI), utils (`DateFormatter`) |
| `lib\feature\common\` | Widgets and cubits shared across features (`DrawerFormCubit`, `DeleteConfirmationRow`, `ProjectSelector`, `TaskSelector`, `InlineField`, drawer scaffolding) |

**Page split pattern** (applied to history, tasks, projects): the page file is a thin
coordinator; `components/<entity>_list.dart` holds the `XxxViewMode` enum + the card/table
switcher widget; `components/<entity>_table.dart` holds a top-level
`getXxxTableColumns(AppThemeExtension theme)` function. The ViewMode enum lives in the
*list component* file (putting it in the page file creates a circular import) and is
re-exported from the page file via `export ... show XxxViewMode` for backward compatibility.

**Extraction rule for enums:** when extracting a class that references an enum from its
containing file, move the enum to a third shared file (e.g. `app_route.dart`) instead of
importing the old file - otherwise you build a circular dependency.

### 1.2 Dependency Injection - final decision

**Option A was chosen: get_it + injectable everywhere.** There is exactly one way to obtain
a repository or service:

- Interfaces live in `lib\domain\` (or `lib\data\settings_repository.dart` for settings).
- Implementations are annotated `@LazySingleton(as: <Interface>)`
  (`SqliteTimeEntryRepository`, `SqliteProjectRepository`, `SqliteTaskRepository`,
  `SqliteSettingsRepository`, `PlatformIdleMonitor`).
- Everything is resolved via `getIt<Interface>()` from
  `core\services\service_locator\service_locator.dart`.
- `app.dart` builds `TimeTrackerService`/`ProjectTaskState` from `getIt`-resolved repos.
  **Never instantiate a `Sqlite*Repository` directly in widget/provider code.**
- `IdleMonitor` is registered conditionally in `runner.dart`
  (`PlatformIdleMonitor` on macOS channel platforms, `NoOpIdleMonitor` otherwise) and
  retrieved WITHOUT try/catch - a missing registration must fail fast, not silently
  disable idle detection.
- `WindowsDesktopService` additionally uses `GetIt.I.registerSingleton` /
  `unregister` for `HotkeyService`/`ReminderService` re-registration on re-init; both the
  raw `get_it` import and the `service_locator.dart` import are needed there.

**Codegen caveat:** `service_locator.config.dart` is nominally generated, but build_runner
is broken in this repo (see 3.1), so registrations are **edited manually**, preserving the
generated file's `_iNNN` import-prefix style.

### 1.3 State-management layering

| Layer | Used for | Examples |
|---|---|---|
| BLoC | Async, event-driven domain flows | `TimeTrackerBloc` (single source of truth for entries), `HistoryBloc`, `TasksBloc`, `ProjectsBloc`, `WorkLogRawDataBloc` |
| Cubit | Focused, imperative state containers | `TrackerPanelCubit` (comment draft + delegation to TimeTrackerBloc), `DrawerFormCubit<T>` (generic drawer draft + confirmingDelete), `MiniTrackerCubit` |
| ChangeNotifier / Provider | Shared caches and app-shell state | `ProjectTaskState` (project/task cache + CRUD + timer draft selection), `EntityResolver`, `DrawerHostController`, `AppNavigationController`, `AppBarService` |
| Plain object + Provider | Side-channel command streams | `MiniPanelCommandBus` (broadcast `StreamController<MiniPanelCommand>`; a Cubit is a state container, NOT a command bus - keep them separate) |

Key structural decisions:

- **Feature BLoCs are provided at `MainApp` level, not screen level.** Pages are
  intentionally recreated on tab change (no IndexedStack - explicit product decision).
  A screen-level BlocProvider would lose filter/sort/view-mode state on every tab switch.
- **`DrawerFormCubit<T>`** replaced per-drawer `setState` for `_draft` and
  `_isConfirmingDelete` in all three drawers. Contract:
  - `updateDraft(newDraft)` preserves `confirmingDelete`;
  - `reset(newDraft)` replaces the whole state (used in `didUpdateWidget` when widget
    identity changes - clears confirmingDelete AND swaps the draft atomically);
  - `cancelDelete()` only dismisses the confirmation (used when the drawer closes:
    `!widget.isOpen && oldWidget.isOpen`).
- **`TrackerPanelCubit`** owns only `draftComment`; the draft project/task stays in
  `ProjectTaskState` because many other widgets consume it. Do not duplicate it.
- **Flutter framework objects stay in widgets.** `TextEditingController`,
  `InlineFieldController`, `FocusNode` cannot live in a Cubit - they are widget-tree
  integrated. Pass them into extracted stateless children as constructor parameters;
  side effects in `build` (e.g. `commentController.text = persisted`) are safe when the
  child receives the same controller instance.
- **`MiniPanelCommand` enum** lives in `mini_tracker_cubit.dart` (it is part of the state
  domain); `MiniPanelCommandBus` is registered as a plain `Provider` with
  `dispose: (_, bus) => bus.dispose()`.
- **`app_bar/` six-file split is intentional**: `AppBarService` (state) +
  `AppBarProvider` (push/write) + `AppBarScope` (read/InheritedWidget propagation) is a
  deliberate push-pull pattern - do not "simplify" it into one file.

### 1.4 Design system boundary

- All visual tokens live in `packages\worklog_studio_style_system\`. The app consumes them
  via `context.theme` (`AppThemeExtension`) - `theme.colorsPalette`, `theme.spacings`,
  `theme.radiuses`, `theme.shadows`, `theme.commonTextStyles`.
- `ColorsPalette` groups: `base`, `background`, `border`, `text`, `accent`, and
  `sidebar` (`SidebarColors` - 8 white-alpha overlay tokens added during refactor; both
  light and dark palettes hold identical values because the sidebar background is always
  the dark `accent.nav`).
- The badge tint palette is `kBadgePalette` in
  `theme\colors_palette\badge_palette.dart`, exported from the package barrel.
  `BadgeUtils` (app side) keeps only the initials + hash lookup logic.
- **UI discovery goes through `packages\worklog_studio_style_system\UI_KIT.md`** - never
  crawl the package source to find out what components/props exist.
- Established token mappings from the refactor (use these instead of resurrecting hex):
  `0xFFeaeffd` / `0xFFebf0fd` -> `accent.primaryMuted`; `0xFFf8fafc` ->
  `background.canvas`; header white -> `background.surface`.

### 1.5 Shared UI components created during the refactor

| Component | Location | Contract |
|---|---|---|
| `DeleteConfirmationRow` | `feature/common/presentation/components/` | `isShowing`, `entityLabel`, `onConfirm`, `onCancel`; wraps the AnimatedSwitcher + danger InfoBar two-step delete. Call sites wrap it in `if (!_isNew)`. |
| `ProjectSelector` | same | `selectedProjectId`, `fieldController`, `onProjectSelected(String?)`, optional `fallbackLeading`/`trailing`. Handles Select + inline create + `handleEditorCommit/Close` internally. |
| `TaskSelector` | same | Same shape + `projectId` filter; inline task creation no-ops when `projectId == null`. |
| `DateFormatter` | `core/utils/date_formatter.dart` | The ONLY place for date/duration formatting: `formatDurationHms` (HH:mm:ss), `formatDurationHm` (Xh Ym), `formatDateHeader`, `formatTime12h`, `formatTimeHhMm`, `formatTimeRange`. Never write a private `_formatDuration` again. |

Deliberate non-migration: `GlobalTimeTrackerPanel`'s project/task selectors were NOT moved
to the shared `ProjectSelector`/`TaskSelector` - they delegate to `TrackerPanelCubit` with
`isRunning` semantics and `exitEditMode` behavior that differ from the drawer draft flow.

### 1.6 History page scroll compaction (session 2026-07-08)

The history page header compacts when the entry list is scrolled past 50px. Architecture
decisions worth reusing on other pages:

- **Cosmetic scroll state stays in the widget.** `_isScrolled` is a `ValueNotifier<bool>`
  in `_HistoryScreenState`, fed by the existing `NotificationListener<ScrollNotification>`
  and consumed via one `ValueListenableBuilder` wrapping the page body. It never touches
  `HistoryBloc` - it is pure presentation state per guardrail 2.2. The KPI strip's
  hide-on-scroll shares the same bool (one threshold, one source of truth).
- **Compaction is two discrete states animated with implicit widgets** (`AnimatedPadding`,
  `AnimatedSize`, `AnimatedDefaultTextStyle`, `AnimatedOpacity`, `AnimatedContainer`),
  all sharing `_compactDuration` (200ms, same as the KPI strip's `AnimatedSwitcher`) and
  `_compactCurve` (easeOutCubic). No explicit AnimationControllers.
- **Only vertical paddings compact.** Horizontal page padding stays constant so the
  table does not reflow horizontally during the transition.
- **`ScrollController` is owned by the page** and passed into `TimeEntryList`; the
  go-to-top button and the stats-toggle's scroll-to-top both drive it.
- **`inline` mode pattern for composable bars:** `HistorySortBar` and `HistoryFilterBar`
  expose `inline: true` which returns the bare controls `Row` (no Align, no padding, no
  scrollbar). The caller (`_CompactToolbarRow` in `time_entry_list.dart`) composes them
  into one right-aligned, horizontally scrollable row with a vertical divider. The
  stacked (non-inline) layout is untouched. Reuse this pattern instead of duplicating
  bar internals when a layout wants to recompose existing toolbars.
- **Page-wide mouse-wheel scrolling:** a `Listener(behavior: HitTestBehavior.translucent)`
  over the page routes `PointerScrollEvent`s into the list through
  `GestureBinding.instance.pointerSignalResolver.register(...)` (see pitfall 3.14).

### 1.7 Style-system component changes (session 2026-07-08)

- `SegmentedToggle` gained `compact: bool` and explicit heights (36px normal / 28px
  compact) that mirror `PrimaryButton`'s hardcoded height constants; segments stretch
  vertically inside a fixed-height track. Styling inverted to muted track
  (`surfaceMuted` + full `border.primary`) with a white selected thumb so the whole box
  reads as the control (see pitfall 3.15).
- `ClearableFilterPill.overlap` (10.0) is now a public static const - the space the pill
  always reserves above/right of its child for the clear badge. Sibling rows without a
  pill pad themselves by this constant to stay aligned (see pitfall 3.13).
- Both are documented in `UI_KIT.md`.

### 1.8 Native activity window + hotkeys (session 2026-07-08)

- `NativeActivityWindow.hide()` uses `ShowWindow(SW_HIDE)`, NOT `DWMWA_CLOAK`. The cloak
  trick exists only to protect Flutter-engine-backed windows from `WM_SHOWWINDOW`
  suspend crashes; this window is pure Win32 (no engine), and cloaking left a ghost
  taskbar entry (see pitfall 3.12). `show()` first recovers from a shell-minimized
  state via `IsIconic` -> `SW_SHOWNOACTIVATE`, then applies the frame, then shows if
  Win32-hidden.
- Default global hotkeys are Ctrl+Alt+M / Ctrl+Alt+A / Ctrl+Alt+X (`HotkeyService`).
  Both Ctrl+Shift and Alt+Shift are Windows' built-in input-language switch gestures
  and can silently swallow the chord - never default to either pair.

### 1.9 Reports page (session 2026-07-12, [feature])

Built via `docs/superpowers/plans/2026-07-12-reports-page.md`, executed with
subagent-driven-development (5 tasks + a post-completion fix pass), journal at
`docs/worklog/2026-07-12-reports-page.md`, commits `c7b1b11..1d59469`.

- **New feature slice `feature/reports/`** follows the canonical scaffold (1.1) with one
  deliberate deviation: `reports_aggregator.dart` (pure static aggregation logic, zero
  Flutter/BLoC imports) sits directly under `feature/reports/`, not inside a `data/`
  subfolder - it is domain-shaped but feature-local, not a repository, so it does not earn
  its own `data/` layer. Full layout:
  `reports_aggregator.dart` (models + `ReportsAggregator.aggregate()`),
  `bloc/reports_{bloc,event,state,bloc.freezed}.dart`,
  `presentation/reports_page.dart`, `presentation/components/{reports_summary_panel,
  reports_table}.dart`.
- **`ReportsBloc` is provided at `MainApp` level** in `app.dart`, after
  `BlocProvider<HistoryBloc>` - consistent with 1.3 (pages are recreated on tab change; a
  screen-level provider would lose period/range selection on every navigation).
- **New style-system widget `WsGroupedTable<G, I>`**
  (`packages\worklog_studio_style_system\lib\ui_kit\src\table\ws_grouped_table.dart`) - a
  generic two-level expandable table (groups containing items), exported from the ui_kit
  barrel and documented in `UI_KIT.md`. Expand/collapse is local `setState` (correct per
  2.2 - purely cosmetic). Defaults to **collapsed** (`initiallyExpanded: false`); the
  constructor parameter exists so a future call site can opt into expanded-by-default.
- **Content-hugging table inside a scrolling page - the pattern to reuse:** when a table
  (or any list-shaped widget) must size itself to its content instead of filling the
  remaining screen height, the table's internal list uses
  `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` with the
  containing `Column` set to `mainAxisSize: MainAxisSize.min`, and the PAGE wraps its
  scrollable content region in exactly one `Expanded(SingleChildScrollView(...))`. Do not
  nest a second `Expanded(ListView(...))` inside the table AND wrap the table itself in
  `Expanded` at the page level - that produces two competing "fill available space"
  constraints with no finite bound and the table stretches to the bottom of the window
  regardless of row count (see pitfall 3.21). This contrasts with `WsTable`'s
  full-height-filling layout used elsewhere - the two widgets solve different layout
  problems, do not merge them.
- **Row-divider visual weight is a distinct token usage from container borders:** the
  outer card border uses `palette.border.primary.withValues(alpha: 0.4)` (subtle
  container edge); the in-list row dividers between every group/item row use
  `palette.border.primary` at full opacity (deliberately more visible, per explicit
  product request) - see guardrail 2.4.
- **`DashboardPeriod` enum is reused, not redefined** - imported from
  `feature/home/dashboard_chart_aggregator.dart`. Range logic itself (week/month/custom
  boundaries) is duplicated in `ReportsAggregator` rather than calling
  `DashboardChartAggregator`, because the two features' output shapes diverge enough that
  sharing the aggregation function would need a shared intermediate type not worth
  introducing for two call sites - acceptable duplication, not an oversight.

### 1.10 Reports charts block (session 2026-07-15, [feature])

Built via `docs/superpowers/plans/2026-07-15-reports-charts-block.md` (spec:
`docs/superpowers/specs/2026-07-15-reports-charts-block-design.md`), executed inline
task-by-task with the journal at `docs/worklog/2026-07-15-reports-charts-block.md`,
commits `deff358..500459c`.

- **`DashboardChartView` lives in `dashboard_chart_aggregator.dart`** (moved from the
  home bloc file, next to `DashboardPeriod`) so Reports can import it without touching
  another feature's bloc - the "shared enum moves to a shared file" rule (1.1). The
  move needed zero import changes because every consumer already imported the
  aggregator file.
- **`chartScale` is a shared util** at `lib\feature\common\utils\chart_scale.dart`
  (extracted from the Dashboard's private `_chartScale`, now unit-tested in
  `test\core\chart_scale_test.dart`). Both bar charts use it; keep any future chart
  axis math there.
- **`ReportsAggregator` gained `byTask` slices and stacked `bars`**
  (`ReportsBar`/`ReportsBarSegment`). Bucketing (today -> hourly clipped to entry
  hours, week -> 7 days, month -> calendar weeks, custom -> no bars) intentionally
  duplicates `DashboardChartAggregator._buildBuckets` - same deliberate-duplication
  decision as the range logic (1.9). Segment order inside every bar equals the
  `byProject` order (duration desc, No Project last); zero-duration segments are
  omitted, so `segments.isEmpty` means "nothing logged in this bucket".
- **`ReportsSummaryPanel` is a dumb BaseCard widget** (props `data`/`view`/`period` +
  `onViewChanged` callback; the page dispatches `ReportsViewChanged`). Custom period
  forces the donut view and hides the SegmentedToggle (custom ranges have no bar
  buckets, mirroring the Dashboard). Period controls stay at PAGE level because they
  drive the table too.
- **Stacked-bar hover overlay pattern:** fl_chart tooltips stay disabled; a
  `MouseRegion` maps pointer x to a bar index (zone width = (width - reserved Y-axis
  36px) / barCount), and the legend is a `Positioned` card inside a `Stack`, wrapped
  in `IgnorePointer` (otherwise it steals the hover and flickers), preferring the
  right side of the bar, flipping left near the edge, clamped to chart bounds.
  `_kLeftReservedSize` must equal `SideTitles.reservedSize` or hover zones drift.
- **Hand-editing a freezed file to add a field:** most of the boilerplate
  (==/hashCode/toString/copyWith signatures/param lists/bodies/patterns-extension) is
  textually identical between the mixin and the concrete class, so `replace_all`
  string edits hit both at once; only the getters line, the concrete constructor
  (`this.view = DashboardChartView.donut`), and the field declaration
  (`@override@JsonKey() final DashboardChartView view;`) need unique edits. Copied
  from `dashboard_charts_bloc.freezed.dart`, confirmed in `reports_bloc.freezed.dart`.

### 1.12 Idle detection bug fixes (session 2026-08-05, [debug])

Three bugs fixed in the idle time detection feature introduced in the prior session.
All 341 tests pass; `flutter analyze` clean. Files changed:
`feature\settings\presentation\general_settings_screen.dart`,
`feature\time_tracker\cubit\idle_flow_cubit.dart`,
`core\services\desktop\idle_resolution_window.dart` (simplified),
`feature\time_tracker\presentation\idle_task_selection_dialog.dart` (new),
`core\services\desktop\windows_desktop_service.dart`.

#### Bug 1: Settings TextField save-on-blur

The "Mark as idle after X minutes" field only saved on Enter (`onSubmitted`). Navigating
away with the mouse discarded the change silently.

**Fix:** add a `FocusNode` in `_GeneralSettingsScreenState`, register a listener that
calls `_saveIdleThreshold(_idleThresholdController.text)` whenever `hasFocus` becomes
false, and dispose it. This is the canonical Flutter pattern for any numeric/text field
that must persist on navigation-away.

#### Bug 2: Native popup showed threshold minutes instead of actual elapsed idle time

`IdleFlowAwaitingResolution` stored `idleStartTime` (timestamp - thresholdDuration)
but `_showResolutionWindow(idleMinutes: s.idleSeconds ~/ 60)` passed the static
threshold value, not the real wall-clock elapsed time.

**Fix:** at the moment `UserReturnedFromIdle` fires, compute:
```dart
final actualIdleMinutes = _now().difference(s.idleStartTime).inMinutes;
_showResolutionWindow(
  idleMinutes: actualIdleMinutes < 1 ? 1 : actualIdleMinutes,
  ...
);
```
The user could have been away much longer than the threshold before the popup appeared;
using `_now()` at return-time captures the full span. The `< 1` guard prevents showing
"0 minutes" when the event fires in the same minute. `_now` is an injected
`DateTime Function()` (see guardrail 2.9).

#### Bug 3: "Log to another task" - task selector + Enter key

The native Win32 expansion panel (EDIT control) had no task/project selector and its
Enter key binding was a polling hack. **Both problems were solved by replacing the Win32
expansion panel entirely with a Flutter dialog.**

- `IdleResolutionWindow` was simplified from an expandable 5-control layout to a flat
  3-button layout (`_kH = 160`). Removed: `_editHwnd`, `_confirmBtnHwnd`, `_expanded`,
  `_setExpanded`, `_showExpansionControls`. Callback changed from
  `onLogToTask: void Function(String comment)` to `onRequestLogToTask: void Function()`.
- `IdleTaskSelectionDialog` (new `StatefulWidget`) shows via `showDialog` from
  `WindowsDesktopService._showIdleTaskSelectionDialog()`, which uses
  `rootNavigatorKey.currentContext` to obtain the widget tree context (and therefore all
  providers above `MaterialApp`). Returns `IdleTaskSelection?` on pop.
- `IdleTaskSelection` data class (in `idle_flow_cubit.dart`) carries `taskId`,
  `projectId`, and `comment` from the dialog back to the cubit.
- The dialog uses `ProjectSelector` + `TaskSelector` (shared components from
  `feature\common`), each backed by its own `InlineFieldController`. Task resets when
  project changes (`_taskController.resetValue()`). Comment field is a `PrimaryInput`
  with `onSubmitted: (_) => _confirm()` - Enter key works naturally.
- `IdleFlowCubit._onRequestLogToTask()` is async: shows the dialog, and if selection
  is null (dismissed) falls back to `_onKeep()`. If confirmed, calls
  `_logIdleTimeToSelection()` which writes three repository operations in sequence:
  stops original entry at idle start, inserts idle entry linked to selected task,
  inserts new running entry for original task.

#### Critical fix: `_onBlocState` must NOT reset on `IdleFlowResolved`

See pitfall 3.25 for the full failure mode. Short version: the old `_onBlocState` reset
to `IdleFlowIdle` whenever the bloc emitted non-running state AND cubit state was
`IdleFlowResolved`. The `_logIdleTimeToSelection` path calls
`bloc.add(TimeTrackerEvent.loaded())` AFTER emitting `IdleFlowResolved`, and the bloc's
reload transiently emits `TimeTrackerLoading` (non-running) - which matched the old
condition and reset the cubit. Fix: check `this.state is IdleFlowAwaitingResolution`
only - never `IdleFlowResolved`.

### 1.11 Chart sync follow-up (session 2026-07-15, [feature], commits `f78b9b5..a366250`)

Same-session follow-up: dashboard/reports bar-chart unification, thicker report
progress bars, dashboard-to-reports jump. Journal Tasks 9-12 in
`docs/worklog/2026-07-15-reports-charts-block.md`.

- **Stacked-bar data lives in `feature\common\utils\chart_bars.dart`**
  (`ChartBar`/`ChartBarSegment` with generic `id`/`label` fields, plus
  `hourlyStackedBars`/`dailyStackedBars`/`monthlyStackedBars`). Both aggregators
  keep only a `switch (period)` and delegate; `ReportsBar`/`DashboardBucket` and
  all per-aggregator bucket helpers are gone. The module deliberately does NOT
  import `DashboardPeriod` (three period-specific functions instead of one
  switch-taking function) - that is what avoids a
  dashboard_chart_aggregator <-> chart_bars import cycle. Project order is
  computed inside the builder (duration desc, '' sentinel last).
- **The one bar-chart widget is `StackedBarChart`**
  (`feature\common\presentation\components\stacked_bar_chart.dart`) - stateful
  hover, per-project `rodStackItems` colors, overlay legend. Dashboard and
  Reports both consume it; do not fork chart internals per feature. This created
  `feature\common\presentation\components\` as the home for shared
  presentational widgets.
- **Dashboard -> Reports jump:** `ReportsSyncedFromDashboard` event mirrors
  period/anchorDate/view/customRange into `ReportsBloc`;
  `AppNavigationController.openReports()` is a plain `void Function()` handler
  (keeps the core service free of the `AppRoute` import), registered by
  `AppShell` as `_onRouteSelected(AppRoute.reports)`. The trigger is
  `_OpenInReportsButton` in the dashboard charts header; its dynamic Tooltip
  ("Open in Reports: <range>, <view>") is the user-facing demonstration that the
  configured setup carries over (donut spelled out for custom periods because
  Reports forces donut there).
- **Cross-feature imports are now a documented PAIR:** reports imports home's
  aggregator (enums), home's charts section imports `reports_bloc.dart`
  (presentation-level dispatch). Acceptable as-is; any third edge means extract
  a shared file instead.

### 1.13 History entry stacking (session 2026-08-07, [feature])

Consecutive time entries sharing the same `taskId` + `projectId` are now
collapsed into expandable "stacks" in both the card and table views of the
history page. `flutter analyze` clean; no automated tests were written for
this purely presentational feature (see 4.2 debt). Files added/changed:
`feature\history\presentation\components\time_entry_stack_grouper.dart` (new),
`feature\history\presentation\components\time_entry_stack_card.dart` (new),
`feature\history\presentation\components\time_entry_stack_table.dart` (new),
`feature\history\presentation\components\time_entry_list.dart` (modified).

#### Why WsGroupedTable was rejected

`WsGroupedTable<G, I>` was the first candidate - it already exists and handles
expandable two-level tables (used in Reports). It was rejected because its
`_ItemRow` widget hard-codes `onTap: null`: individual expanded rows are
display-only. In the history view, tapping an expanded row must open the
time-entry drawer. A feature-local `HistoryStackTable` was built instead.

**Rule derived (see 2.10):** `WsGroupedTable` is only appropriate when item
rows are purely informational. Any grouped table requiring tappable item rows
needs a feature-local implementation.

#### Three-file split and responsibilities

| File | Responsibility |
|---|---|
| `time_entry_stack_grouper.dart` | Pure domain model `TimeEntryStack` + `groupConsecutiveEntries()`. Zero Flutter/widget imports. Tested independently. |
| `time_entry_stack_card.dart` | `TimeEntryStackCard` (StatefulWidget). Collapsed: summary `InteractiveCard` + 1-2 shadow strips beneath to imply depth. Expanded: summary header card + individual `TimeEntryCard` items joined by a left accent line via `IntrinsicHeight`. |
| `time_entry_stack_table.dart` | `HistoryStackTable` (StatefulWidget). Replicates `WsTable`'s outer container + header, then renders single-entry stacks as normal rows (`_HistoryNormalRow`) and multi-entry stacks as a summary row (`_HistoryStackSummaryRow`) that expands inline to `_HistoryItemRow` children. |

The column flex values in `_HistoryStackSummaryRow` are hardcoded to match
`getHistoryTableColumns` exactly (flex 4-3-8-2-2, fixedWidth 48). If that
function changes its column structure, `_HistoryStackSummaryRow` must be
updated in tandem.

#### time_entry_list.dart changes

All four render paths (date-grouped card, date-grouped table, flat card, flat
table) now call `groupConsecutiveEntries(entries)` before building the widget
tree. `WsTable<ResolvedTimeEntry>` and `getHistoryTableColumns` are no longer
called from `time_entry_list.dart`. As a consequence, both the `collection`
package import (`firstWhereOrNull` was its only usage) and the
`time_entry_table.dart` import were removed. Failing to remove them produces
`[undefined_method]` / `[unused_import]` analyzer errors (see pitfall 3.28).

#### IntrinsicHeight connector-line pattern

In the card view's expanded state, each sub-entry card is paired with a 2px
accent-colored vertical line using:

```dart
IntrinsicHeight(
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(width: 2, ...), // accent line - stretches to card height
      Expanded(child: TimeEntryCard(...)),
    ],
  ),
),
```

`IntrinsicHeight` forces the `Row` to measure its children's intrinsic height
and then stretches all children to that height. Safe here because
`TimeEntryCard` -> `InteractiveCard` -> `Padding` has a finite intrinsic
height. **Never use `IntrinsicHeight` with `ListView` or any unbounded-height
child** - it will throw at runtime (see pitfall 3.29).

#### selectedRowKey placement

The `GlobalKey? selectedRowKey` used for `Scrollable.ensureVisible` is
attached to the outermost container of the stack group - the `TimeEntryStackCard`
widget key (card view) or the `_HistoryNormalRow`/`_HistoryStackSummaryRow`
widget key (table view). It is NOT passed down to individual `TimeEntryCard`
children inside an expanded stack. Consequence: when a collapsed stack contains
the selected entry, scrolling brings the stack into view (acceptable). Auto-
expanding the stack to reveal the specific entry is deferred (see 4.2).

### 1.14 Column layout standardization (session 2026-08-10, [redesign])

Ad-hoc UI polish: column order standardized and the Efficiency placeholder column
removed across the history and dashboard tables. Commit `41d896a`. Files changed:
`feature\history\presentation\components\time_entry_table.dart`,
`feature\history\presentation\components\time_entry_stack_table.dart`,
`feature\history\presentation\components\time_entry_card.dart`,
`feature\history\presentation\components\time_entry_stack_card.dart`,
`feature\home\presentation\home_page.dart`.

#### Column order: Comment before Duration

Previous order: Task & Project | Duration | Comment | Efficiency | Status | Actions
Current order:  Task & Project | Comment | Duration | Status | Actions

Rationale: reading left-to-right, users scan for WHAT first (task name, then comment)
before HOW LONG (duration). Duration as the last data column before the action button
also creates a natural terminal anchor. Applied symmetrically to all five surfaces so
the horizontal rhythm is identical in every view mode.

#### Efficiency column removed entirely

The Efficiency column was a hardcoded `94%` + `LinearProgressIndicator` placeholder with
no real data behind it. It lived in three independent locations:

1. `getHistoryTableColumns()` - a full `WsTableColumn` builder (history table)
2. `_HistoryStackSummaryRow` - a `SizedBox.shrink()` flex-slot placeholder
3. `home_page._fullColumns()` - a separate `_efficiencyColumn()` private method

All three were deleted in one commit. The `_efficiencyColumn` method in
`home_page.dart` was the only call site for its own definition, so removing the
`_efficiencyColumn(theme)` call from `_fullColumns` was immediately followed by
deleting the method body (the analyzer flagged "unused declaration" on the next save).

Updated hardcoded flex comment in `_HistoryStackSummaryRow` from:
  `//   flex 4 | flex 3 | flex 8 | flex 2 | flex 2 | fixedWidth 48`
to:
  `//   flex 4 | flex 8 | flex 3 | flex 2 | fixedWidth 48`

#### Card view reorder note

`TimeEntryStackCard` summary has no "Comment" column - it shows the "N sessions" count
as its content area. After the reorder, "N sessions" occupies the same horizontal zone
as "Comment" does in the regular card and table, and "Duration" sits in the matching
position. The spatial rhythm is consistent across card and table views even though the
content differs for stack summaries.

#### Key coupling reminder

Column structure now lives in three places that must change together (see pitfall 3.30
and guardrail 2.10): `getHistoryTableColumns`, `_HistoryStackSummaryRow`,
`home_page._fullColumns`. Single-file column changes will silently misalign the others.

---

## 2. PRODUCTION GUARDRAILS

Each rule has its reason recorded - if the reason ever stops being true, revisit the rule.

### 2.1 Imports

- **Absolute `package:worklog_studio/...` imports only.** Enforced by
  `always_use_package_imports: true` in `analysis_options.yaml`.
  *Why:* relative imports break silently on file moves; the refactor migrated 54 relative
  imports across 29 files to make `git mv` safe.
- **Never import `package:provider/provider.dart` alongside `flutter_bloc` for
  `context.read/watch/select`** - flutter_bloc re-exports provider and the duplicate
  triggers a conflict lint. **Exception:** the `Consumer<T>` widget AND the `Selector<T,
  R>` widget specifically fail to resolve through the transitive export in some files -
  when you use either, add the explicit `package:provider/provider.dart` import (added
  2026-07-12: `Selector<EntityResolver, List<ResolvedTimeEntry>>` in `reports_page.dart`
  needed it, same as `Consumer` already did).
- **Never import a sub-path from another package** (e.g.
  `package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart`).
  Only import a package's barrel file. *Why:* sub-path imports couple you to internal
  file layout that can move freely; if a type you need is not exported from the barrel,
  either add it to the barrel or avoid naming the type explicitly (inline the value, use
  a ternary, or let Dart infer the local variable's type) rather than reaching around the
  barrel (pitfall 3.18).
- After any `git mv` of a Dart file, grep BOTH `lib/` and `test/` for the old import path.
- **`showDialog` (and `showGeneralDialog`, etc.) are top-level functions in
  `package:flutter/material.dart`. They are NOT automatically in scope in non-widget
  service/cubit classes even when other Flutter types are imported.** When calling
  `showDialog` from a service class, add:
  `import 'package:flutter/material.dart' show showDialog;`
  See pitfall 3.26.

### 2.2 State management

- **`setState` is allowed only for purely cosmetic local state**: hover, focus, animation
  toggles, visibility flips. *Why:* anything that crosses a widget boundary or feeds
  business logic (drafts, search queries, filters) belongs in a Bloc/Cubit where it is
  testable; the drawers and panels were rebuilt around this rule.
- Do not call `setState`/`addPostFrameCallback` to defer draft mutations. The old
  `addPostFrameCallback((_) => setState(...))` pattern in drawers existed only to dodge
  "setState during build" from `Select.onChanged`; with `DrawerFormCubit` the cubit
  `emit()` is safe to call directly from user-action callbacks.
- New feature screens with filter/sort/view-mode state get their own BLoC provided at
  `MainApp` level (see 1.3 - pages are recreated on tab change).
- **Any cubit that reads wall-clock time (elapsed durations, timestamps) must accept
  `DateTime Function()? now` (defaulting to `DateTime.now`) and store it as `_now`.
  Tests provide a controllable `fakeNow` variable, giving frozen-time assertions
  without sleeping or timing hacks.** Confirmed necessary for `IdleFlowCubit`'s
  elapsed idle duration calculation (2026-08-05).
- **A `_onBlocState` listener that resets cubit state when the bloc becomes non-running
  must guard on the cubit's OWN state being `AwaitingXxx`, never on it being `Resolved`.
  Resolved state means the cubit already finished its work; transient non-running bloc
  states during post-resolution reloads (`bloc.add(Event.loaded())`) MUST NOT undo that.**
  See pitfall 3.25.
- The `_sentinel = Object()` copyWith pattern is the house style for state classes that
  need "explicitly set this nullable field to null" semantics
  (e.g. `filterExpandedOverride: null`).
- **Any `StatefulWidget` with local hover/selection state that is emitted as an item in a
  `ListView`/`Column`'s `children` MUST receive `super.key` in its constructor, and the
  call site MUST pass an explicit `key:` (a stable identity, e.g. `ValueKey`).** *Why:*
  without a key Flutter reconciles list children by position; after any list mutation
  (sort, filter, expand/collapse) hover/selection state silently bleeds onto the row that
  now occupies the old position instead of following its original row. Confirmed with
  `WsGroupedTable`'s `_GroupRow`/`_ItemRow` (2026-07-12, pitfall 3.19) - the same fix
  already applied to `WsTable`'s row widgets during the 2026-07 refactor.

### 2.3 Code generation (Freezed / injectable)

- **build_runner is broken** in this repo (Dart 3.10.4 + `native_toolchain_c 0.19.1`
  build-hook incompatibility). Consequences:
  - Write `.freezed.dart` files **by hand**, copying the Freezed v3 pattern from an
    existing generated file (`time_tracker_bloc.freezed.dart`,
    `dashboard_charts_bloc.freezed.dart`). List fields need the private `_field` backing,
    `EqualUnmodifiableListView` getter, and `DeepCollectionEquality` in ==/hashCode.
  - Edit `service_locator.config.dart` manually, keeping the `_iNNN` prefix style.
- All Cubit/Bloc state classes use `@freezed`; hand-rolled `copyWith` state classes were
  eliminated (`MiniTrackerState` was the last one).

### 2.4 Design system usage

- **No hardcoded `Color(0xFF...)`, `Colors.white/black`, or literal pixel paddings in
  `apps\`.** Use `theme.colorsPalette.*` / `theme.spacings.*`. If a token does not exist,
  add it to the style system package first (as was done with `SidebarColors` and
  `kBadgePalette`). *Why:* single-point theme changes and future dark-mode support.
- **Spacing token trap:** `theme.spacings.xs == 2` and `theme.spacings.xxs == 4` -
  `xs` is SMALLER than `xxs` in this codebase. Check before substituting literals.
- No italic text anywhere in UI - hierarchy is expressed via size/color only.
- Asset freeze for new UI: use `Placeholder()` and standard Material `Icons`, no new
  binary assets without an explicit decision.
- **Never pass an explicit `size:` to an `Icon` used as `leftIconWidget`/`rightIconWidget`
  of `PrimaryButton`.** The button wraps icons in a `SizedBox(iconDimension)` (xs: 12,
  sm: 14, md: 18, lg: 22) and sizes them via `IconTheme`; a larger explicit size paints
  past that box and the icon looks shifted toward the bottom-right (pitfall 3.11).
- **`AnimatedDefaultTextStyle` must receive a style with an explicit `color`.** It
  REPLACES the ambient `DefaultTextStyle` instead of merging like `Text(style:)` does;
  a token style without color renders white (pitfall 3.16).
- **Control-height source of truth:** `PrimaryButton` heights are hardcoded (xs 28,
  sm 36, md 40, lg 44) and do NOT match the `ControlSize` token table (32/40/48/52).
  Any new inline control that must align with buttons (toggles, pills) aligns to the
  BUTTON constants. `SegmentedToggle` does this explicitly.
- **Anything placed on the same row as `ClearableFilterPill`-wrapped controls must
  compensate for `ClearableFilterPill.overlap`** (10px always reserved on top/right,
  even when inactive - by design, to keep the widget tree shape stable). Either
  bottom-align the row (`CrossAxisAlignment.end`) or pad by the constant.
- Purely visual scroll-reaction state (compact headers, hide-on-scroll strips) lives in
  a `ValueNotifier` inside the screen State, consumed via `ValueListenableBuilder` -
  never in the feature BLoC.
- **Row-divider color vs. container-border color are different tokens by alpha, not by
  hue.** In-list separators between table/list rows use `palette.border.primary` at full
  opacity (visible on purpose); the outer card/container border around the same widget
  uses `palette.border.primary.withValues(alpha: 0.4)` (subtle). Do not use the subtle
  alpha for row dividers - they read as invisible (added 2026-07-12, `WsGroupedTable`).
- **Never nest a `shrinkWrap: true` list inside an `Expanded`.** The two are
  contradictory: `Expanded` says "fill all available space", `shrinkWrap: true` says
  "size to content" - combining them produces a widget that stretches to fill the parent
  regardless of content (pitfall 3.21). When a list must hug its content width the list
  belongs in, use `ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`
  with `mainAxisSize: MainAxisSize.min` on the containing `Column`, and put the single
  `Expanded` at the PAGE level around a `SingleChildScrollView`, not around the list
  itself (see 1.9 for the full pattern).
- **When aligning a footer/total row against a header row built by another widget, copy
  its exact spacer technique, not just its flex values.** `Padding(right: token)` placed
  INSIDE each `Expanded` child produces different pixel math than a standalone
  `SizedBox(token)` placed BETWEEN `Expanded` siblings, even with identical flex ratios
  (pitfall 3.22).

### 2.5 Localization

- l10n infrastructure is deliberately NOT set up (backlog, section 4). Until it is:
  every new hardcoded user-visible string MUST carry `// TODO: l10n`.
  *Why:* the comments are the migration inventory for the future `app_en.arb` pass.

### 2.6 Testing

- TDD is mandatory (see `apps\worklog_studio\CLAUDE.md`): red -> green -> refactor; no
  production logic without a test. Domain/service tests in `test\core\`, bloc/state tests
  in `test\feature\`, shared fakes in `test\helpers\test_fakes.dart`.
- **`bloc_test` is NOT in the pubspec.** Assert via `bloc.add(event)` +
  `await Future<void>.delayed(Duration.zero)` (one microtask is enough for handlers and
  async ChangeNotifier `_init()` to settle), or `bloc.stream.listen`.
- Blocs with an async `_init()` (e.g. `HistoryBloc` restoring SharedPreferences) race
  with test events - always `await Future<void>.delayed(Duration.zero)` after
  construction before dispatching test events, and make "initial state" tests async with
  `await bloc.close()`.
- Prefer hand-rolled fakes over mocks for stateful collaborators; `mocktail` only for
  pure event sources.
- For `EntityResolver`-style tests, drive a REAL `TimeTrackerBloc` with fake repos and
  dispatch `TimeTrackerLoaded()` - simpler and more faithful than faking the bloc.
- Widget-test harness for drawer-class widgets: `MultiProvider` with
  `AppNavigationController` (Provider), `TimeTrackerBloc` (BlocProvider.value),
  `ProjectTaskState` (ChangeNotifierProvider.value), `EntityResolver`
  (ChangeNotifierProvider create), wrapped in
  `MaterialApp(theme: AppTheme.lightThemeData)`; set
  `tester.view.physicalSize = Size(1400, 1600+)` + `addTearDown(tester.view.reset)` to
  avoid overflow failures.
- Widget tests live under `test\feature\` (e.g. `test\feature\drawers\`), NOT a separate
  `test\widget\` root. *Why:* CI and build scripts run
  `fvm flutter test test/core/ test/feature/` - anything outside those roots silently
  never runs.

### 2.7 Tooling and process

- Always `fvm` - never bare `flutter`/`dart`. Dependency resolution ONLY via
  `fvm exec melos bootstrap` from the monorepo root; a bare `pub get` in a subdirectory
  desyncs the workspace.
- Run tests from `apps\worklog_studio\`, not the repo root.
- Never launch the app (`flutter run`) to verify - use `flutter test` and `dart analyze`.
- `dart analyze <files>` is REQUIRED after DI/import changes to `lib\` files that tests
  do not compile (e.g. `app.dart`) - a green test suite does not prove they build.
- Git hygiene: grep for imports before deleting any Dart file (even obviously dead ones);
  use `git rm`/`git mv` so changes stage cleanly; commit per completed item.
- Commit messages: no AI-attribution trailers; and never use em/en dashes in any generated
  text, code, comments, or scripts - a plain hyphen only (dash characters have corrupted
  PowerShell scripts via encoding before).
- **If the Bash tool reports a "temporarily unavailable" safety-classifier error, retry
  once or twice, then fall back to manual code inspection and say so explicitly** - do
  not report a task as fully verified when `fvm flutter analyze`/`fvm flutter test`
  could not actually be run (pitfall 3.23). Read-only tools (Read/Grep/Glob) are
  unaffected and remain reliable evidence for a manual review.

### 2.9 Service-to-Flutter dialog bridge pattern

When a non-widget service (e.g. `WindowsDesktopService`) needs to show a Flutter
`Dialog`, use `rootNavigatorKey.currentContext` as the context:

```dart
Future<T?> _showMyDialog<T>() async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return null;
  return showDialog<T>(
    context: context,
    builder: (_) => const MyDialog(),
  );
}
```

Rules:
1. **`rootNavigatorKey` must be provided at `MaterialApp(navigatorKey:)` level.**
   This key is already wired in `app.dart`; do not move it to a sub-navigator.
2. **`MultiProvider` wrapping `MaterialApp` makes all providers available in the
   dialog's subtree** - `ProjectTaskState`, `EntityResolver`, BLoCs etc. are all
   accessible from `Context.read/watch` inside the dialog.
3. **Return `null` on context miss.** A null context means the engine is not ready
   or the window is closed; callers must handle null and fall back gracefully (e.g.
   `IdleFlowCubit._onRequestLogToTask` falls back to `_onKeep()`).
4. **Native windows fire a plain `void` callback to signal intent; the cubit
   orchestrates the async dialog flow that follows.** Never pass async dialog
   futures into Win32 callback slots.
5. **`InlineFieldController` for `ProjectSelector`/`TaskSelector` must be instantiated
   and disposed in the `StatefulWidget` that shows the dialog, not in the service.**

### 2.8 Windows native windows and global hotkeys

- **Pure Win32 windows (no Flutter engine) hide with `ShowWindow(SW_HIDE)`.**
  `DWMWA_CLOAK` is reserved exclusively for Flutter-engine-backed HWNDs (it exists to
  avoid `WM_SHOWWINDOW` suspend crashes). Cloaking a plain window leaves `WS_VISIBLE`
  set: the taskbar button, Alt-Tab entry, and thumbnail survive as an unclickable ghost,
  and the shell can activate/minimize the invisible window (pitfall 3.12).
- **Every native `show()` path must handle the minimized state first:**
  `IsWindowVisible` returns TRUE for minimized windows, so a plain
  "if not visible then ShowWindow" check silently leaves an iconic window minimized.
  Check `IsIconic` and restore with `SW_SHOWNOACTIVATE` (or `SW_RESTORE` when focus is
  wanted) before applying frames.
- **Never default global hotkeys to Ctrl+Shift+X or Alt+Shift+X on Windows** - both
  chords are OS input-language switch gestures with 2+ keyboard layouts installed and
  can swallow the combo before the third key lands. Current defaults: Ctrl+Alt+M/A/X.
- Changing hotkey DEFAULTS does not affect users with previously saved bindings -
  `HotkeyService` stored settings override `defaultHotKeyFor`. A default change needs
  either a settings migration or a release-notes instruction to re-save.

### 2.10 Feature-local grouped table vs WsGroupedTable

- **Use `WsGroupedTable<G, I>` only when item rows are display-only (non-tappable).**
  Its `_ItemRow` hard-codes `onTap: null`. Any grouped table that needs tappable
  individual rows (e.g., to open a drawer) requires a feature-local implementation
  that wires its own `InkWell` and `onTap` callback per item row.
  *Why:* modifying `WsGroupedTable` to support `onItemTap` would require changing the
  style system package's public API and is not the right trade-off when only one
  feature needs tappable items. Feature-local tables keep the style system contract
  stable. (Confirmed: `HistoryStackTable` was built this way for the history stacking
  feature, 2026-08-07.)
- **When building a feature-local table that mirrors `WsTable`'s outer container,**
  copy the exact `Container` + `ClipRRect` + `Column` structure from `WsTable.build()`:
  `border.all(alpha: 0.4)`, `boxShadow: [shadows.sm]`, `radiuses.md.circular`.
  Do not invent a different outer container - visual inconsistency will be obvious.
- **History table column structure lives in THREE locations that must all change
  in the same commit.** Any column add / remove / reorder / flex adjustment must be
  applied to all three simultaneously or visual misalignment results:
  1. `getHistoryTableColumns()` in `time_entry_table.dart` - canonical source of truth
  2. `_HistoryStackSummaryRow` in `time_entry_stack_table.dart` - hardcoded
     `Expanded(flex:)` sequence; the comment at the top of the class lists the
     current values and IS the sync checkpoint - update it with every change
  3. `_fullColumns()` in `home_page.dart` - independent column list for the dashboard
     recent-activity table (see pitfall 3.30)
  Current state (2026-08-10): `flex 4 | flex 8 | flex 3 | flex 2 | fixedWidth 48`
  (Task & Project | Comment | Duration | Status | Actions).

---

## 3. PITFALLS & TROUBLESHOOTING

Every entry here caused real lost time. Check this list FIRST when something looks weird.

### 3.1 build_runner is broken
`fvm flutter pub run build_runner build` fails with Dart 3.10.4 +
`native_toolchain_c 0.19.1` (build hooks). **Workaround:** hand-write `.freezed.dart`
and `service_locator.config.dart` edits (patterns in 2.3). If the SDK or
native_toolchain_c is ever upgraded, retry codegen and delete this entry.

### 3.2 Bloc created in `setUp` inside widget tests silently stalls
**Symptom:** `testWidgets` taps a button, the callback runs (flags flip), but the bloc's
event handler side effects (repo writes) are missing when `expect` runs.
**Cause:** `setUp` executes outside the `testWidgets` FakeAsync zone; a Bloc constructed
there binds its event pipeline to the real zone, and events added inside the test body
complete only after the test finishes.
**Fix:** construct the Bloc INSIDE the testWidgets body (an `initBloc()` helper called as
the first line). ChangeNotifiers tolerate setUp construction; Blocs do not.

### 3.3 Stale IDE diagnostics after style-system/package changes
After editing the style system package (new tokens, new exports), the IDE analyzer shows
`undefined_getter`/`undefined_identifier` errors in the app for a long time even after
`fvm exec melos bootstrap`. **Trust `flutter test` and `dart analyze` output, not the IDE
problem panel.** The same applies to diagnostics pinned to pre-edit line numbers and to
spurious `argument_type_not_assignable` caused by Windows drive-letter case mismatch
(`d:` vs `D:`).

### 3.4 Circular imports on class extraction
Extracting a widget that references an enum/type from its original file, then importing
the original file back, creates a cycle. **Fix:** move the shared enum/type into its own
file (`app_route.dart` pattern). For the page/list split, keep the ViewMode enum in the
list component and re-export from the page.

### 3.5 Partial block replacement corrupts widget trees
Replacing an `AnimatedSwitcher` + ternary block with a new widget while leaving any stale
fragment (`: const SizedBox.shrink(...)`, an extra `)`) produces a cascade of parse errors
far from the edit site. **Fix:** always replace the ENTIRE old expression in one edit; if
errors appear at unrelated lines after a big replacement, look for orphaned ternary tails
and closing parens near the edit before believing any other diagnostic. Never use an
`if (false)` placeholder to "preserve structure".

### 3.6 `replace_all` renames hit declarations
Renaming a private class to public via replace-all also rewrites the class declaration
inside the block you intend to delete. Rename during copy, then delete the old class body
manually, then check for a stray trailing `}`.

### 3.7 frame-scheduling draft mutations (historical)
The `WidgetsBinding.instance.addPostFrameCallback` wrapper around drawer draft updates
existed to avoid "setState during build" from Select callbacks. It is REMOVED - do not
reintroduce it. Cubit `emit()` from user callbacks is safe. If you ever see a genuine
"emitted during build" error, fix the caller (move the call to a user-action callback),
do not re-add frame deferral.

### 3.8 Dependency landmines
- `dependency_overrides: uuid: ^4.5.2` in the app pubspec is UNRESOLVED tech debt
  (deliberately skipped - see backlog). Do not remove it blindly: transitive constraints
  currently require the override to converge.
- `idb_shim` looks dead for a Windows-only app but is actively imported by the
  web-specific `session_handle_db_web.dart` - keep it.
- `http` is used by the isolated `work_log` prototype (`data_layout.dart`) - removable
  only if/when work_log is deleted.
- `firebase_core`/`firebase_ai` ARE active (`Firebase.initializeApp` in `runner.dart`,
  `FirebaseAI.googleAI()` in `plan_json.dart`) despite older notes claiming otherwise -
  do not remove.
- `firebase_options.dart` contains `///` example code that looks like commented-out dead
  code - it is legitimate generated API documentation; leave it.

### 3.9 Test-runner friction
- `flutter test <file>` triggers a workspace-level `pub get` on EVERY invocation
  (~10-20s). Batch test runs; do not loop single files needlessly.
- `pumpAndSettle` never settles if a periodic-`Timer` widget is live
  (`LiveDurationText` ticks every second). It only renders for ACTIVE/running entries -
  keep test fixtures in `stopped` status unless you explicitly manage timers.
- `SharedPreferences.setMockInitialValues({})` in `setUp` + one-microtask delay before
  events is the pattern for prefs-backed blocs.

### 3.10 Editing discipline with this toolchain
- The Edit tool fails with "String not found" if the file changed earlier in the session -
  re-read the current lines before further edits to the same file.
- `firstOrNull` needs NO `package:collection` import (Dart 3 `IterableExtensions` in
  `dart:core`) - do not add the import for it.
- Multi-window/desktop context: the mini panel is a native Win32 GDI window
  (`NativeMiniPanel`), not a second Flutter engine - Flutter engine EGL races
  (flutter/flutter#155685) are why. Do not resurrect `desktop_multi_window`.

### 3.11 Icons inside PrimaryButton paint outside their box when given an explicit size
**Symptom:** an icon-only button's glyph looks shifted toward the bottom-right corner,
with excess space on the left/top.
**Cause:** `PrimaryButton._wrapIcon` puts the icon in a `SizedBox(iconDimension)` where
iconDimension is 12 (xs) / 14 (sm). An `Icon(..., size: 16)` overrides the `IconTheme`
and overflows the 12-14px box; the overflow paints down-right.
**Fix:** pass `Icon(iconData)` with NO size and let the button's `IconTheme` size it.

### 3.12 DWMWA_CLOAK on a plain Win32 window creates an unkillable taskbar ghost
**Symptom:** after "hiding" the native activity window it stays in the taskbar/Alt-Tab
with a thumbnail; clicking it does nothing; later programmatic `show()` calls appear
dead; closing via the X button "fixes" everything.
**Cause chain:** cloak only hides the DWM visual - `WS_VISIBLE` stays set, so the
taskbar entry survives; the user clicks it; the shell activates/minimizes the invisible
window; `show()` checked `IsWindowVisible` (TRUE for minimized windows) and skipped
`ShowWindow`, and uncloaking does not un-minimize - the window stays iconic forever.
The X button worked because `DestroyWindow` forces a clean re-create.
**Fix:** `SW_HIDE` on hide; `IsIconic` -> `SW_SHOWNOACTIVATE` at the top of show.
See guardrail 2.8.

### 3.13 ClearableFilterPill silently misaligns sibling rows by 10px
**Symptom:** a select next to pill-wrapped selects sits ~10px higher and its right edge
overhangs the pill-wrapped column.
**Cause:** the pill ALWAYS pads its child `top/right` by `ClearableFilterPill.overlap`
(10px) to reserve clear-badge space - deliberately even when inactive, because toggling
the padding would change layout and recreate the child's State.
**Fix:** bottom-align mixed rows (`CrossAxisAlignment.end`) and/or pad the pill-less
sibling by the now-public `ClearableFilterPill.overlap` constant. Do NOT "fix" the pill
by making the padding conditional - the stable-tree-shape comment in the widget explains
why that breaks open Combobox state.

### 3.14 Page-wide wheel scrolling without double-scroll: PointerSignalResolver
To make the mouse wheel scroll a list even when the cursor is over headers/blank space,
wrap the page in `Listener(behavior: HitTestBehavior.translucent, onPointerSignal: ...)`
and inside the handler call
`GestureBinding.instance.pointerSignalResolver.register(event, callback)` - never apply
the scroll directly. The resolver keeps only the FIRST registered callback, and dispatch
runs leaf-up, so when the cursor is over the real `Scrollable` the Scrollable wins and
the page handler is ignored; over dead space the page handler wins. Direct handling
(without the resolver) double-scrolls whenever the cursor is over the list. Guard with
`_scrollController.hasClients` and clamp to `min/maxScrollExtent` before `jumpTo`.

### 3.15 "Component looks the wrong size" disputes: measure, do not eyeball
When a widget "looks smaller/larger" than a neighbor, write a throwaway `testWidgets`
probe that pumps both widgets and prints `tester.getSize(...)` before changing any code
(run it from `test\probe\`, delete after). This session the SegmentedToggle "height bug"
turned out to be 36px == 36px exactly; the real problem was styling (white track on the
near-white canvas made only the inner 30px thumb read as the control). Geometry fixes
and perception fixes are different fixes - identify which one you need first.

### 3.16 AnimatedDefaultTextStyle renders text white when the style has no color
`Text(style: s)` MERGES `s` with the ambient `DefaultTextStyle`, so token styles without
an explicit color inherit the theme color. `AnimatedDefaultTextStyle(style: s)` REPLACES
the ambient style; a color-less token style then paints with the render default (white).
Always `copyWith(color: palette.text.*)` when moving a text into
`AnimatedDefaultTextStyle`.

### 3.17 Buttons whose visible effect lives off-screen feel broken
The KPI-strip toggle "did nothing" when the page was scrolled because the strip renders
only at the top of the page. When a control's effect is not in the viewport, pair the
state change with navigation to where the effect appears (the toggle now scrolls to top
when turning the strip on). Audit any toggle that shows/hides an anchored region.

### 3.18 Typing a private helper with an unexported type forces a sub-path import
**Symptom:** a private helper (e.g. `Color _colorFor(...)`) needs an explicit return/param
type like `ColorsPalette`, which is not exported from the style-system barrel, so the only
way to name it is `import 'package:worklog_studio_style_system/theme/colors_palette/
colors_palette_entity.dart'` - a forbidden sub-path import (guardrail 2.1).
**Cause:** reaching for an explicit type annotation out of habit, when Dart's inference
already gives the same safety.
**Fix:** inline the expression (ternary/ternary chain) instead of a separately-typed
helper, or let the local variable's type be inferred (`final color = ...`). Confirmed in
`reports_summary_panel.dart` (2026-07-12): `_colorFor` returning `ColorsPalette` was
replaced by an inline `slice.id.isEmpty ? palette.text.muted :
BadgeUtils.getBadgeColor(slice.id).$2` ternary at each call site.

### 3.19 Missing `super.key` on a StatefulWidget rendered as a list item bleeds hover state
**Symptom:** after a list re-renders (e.g. groups reordered/filtered), the hover/highlight
visual appears on the WRONG row - the one that now occupies the position the hovered row
used to have.
**Cause:** without a `Key`, Flutter's element reconciliation matches new widgets to old
elements by TYPE + POSITION in the children list, not by logical identity. A `State`
object (and its `_isHovered` field) gets reused for whatever widget now lands in that
slot.
**Fix:** give the widget constructor `super.key` and pass a stable `key:` (e.g.
`ValueKey(id)`) at every call site that builds it inside a list. Confirmed twice in this
codebase: `WsTable` row widgets during the 2026-07 refactor, and `WsGroupedTable`'s
`_GroupRow`/`_ItemRow` on 2026-07-12 (commit `11a859d`). See guardrail 2.2.

### 3.20 A widget's "did anything meaningful change" comparison must read both widgets with their OWN builder function
**Symptom:** `didUpdateWidget`-style diffing (e.g. `_groupsUnchanged(oldGroups,
oldWidget.groupKeyBuilder, newGroups, widget.groupKeyBuilder)` in `WsGroupedTable`)
silently misbehaves if a caller ever passes a DIFFERENT `groupKeyBuilder` closure across
rebuilds (e.g. one that captures rebuilt local state) - because the comparison used
`widget.groupKeyBuilder` (the NEW widget's builder) to key BOTH the old and the new
groups, instead of `oldWidget.groupKeyBuilder` for the old side.
**Cause:** grabbing the nearest-in-scope variable (`widget.x`) instead of the
semantically correct one (`oldWidget.x`) when writing an old-vs-new comparison.
**Fix:** always pair `oldWidget.<builder>` with the OLD collection and `widget.<builder>`
with the NEW collection. Low blast radius when builders happen to be pure/stateless
functions (as they are today), but fix it anyway - it is a latent bug waiting for a
stateful builder. Fixed in commit `11a859d`.

### 3.21 A table/list stretches to fill the whole screen regardless of row count
**Symptom:** a table with 2 rows visually occupies the entire remaining vertical space
down to the bottom of the window, with a large empty area below the last row.
**Cause:** the table was wrapped in `Expanded` at the page level, AND the table's
internal row list was ALSO wrapped in `Expanded(ListView(...))` internally - two nested
"fill all available space" constraints with nothing bounding the outer one to the
content's actual height.
**Fix:** the list that should hug its content becomes
`ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside a
`Column(mainAxisSize: MainAxisSize.min)`; the SINGLE `Expanded` in the whole chain wraps
a `SingleChildScrollView` at the page level, not the table itself. Fixed in
`reports_page.dart` / `ws_grouped_table.dart`, 2026-07-12 (see 1.9, guardrail 2.4).

### 3.22 Footer row misaligned against header row despite identical flex values
**Symptom:** a `_TotalRow`'s "Hours" column sits ~8-10px off from the header's "Hours"
column even though both use `Expanded(flex: 1)` for that slot.
**Cause:** the header row (`WsGroupedTable._buildHeader`) puts `Padding(right: token)`
INSIDE each `Expanded` child to create inter-column gaps; `_TotalRow` instead placed
standalone `SizedBox(token)` widgets BETWEEN the `Expanded` siblings. Both approaches
produce "gaps between columns" visually, but they consume the parent `Row`'s width
differently, so equal flex ratios no longer map to equal pixel widths.
**Fix:** when a second widget must align to a row built by another widget, copy its exact
spacer placement (inside-vs-between `Expanded`), not just its flex numbers. Fixed in
commit `c590acd`.

### 3.23 Bash tool blocked mid-session by a safety-classifier outage
**Symptom:** every Bash invocation (including harmless read-only-equivalent commands like
`fvm flutter analyze`) fails with `"claude-sonnet-4-6 is temporarily unavailable, so auto
mode cannot determine the safety of Bash right now."`, while `git status`/native
Read/Grep/Glob keep working.
**Cause:** an upstream safety-classifier dependency of the Bash tool became temporarily
unavailable; unrelated to the repository or the command being run.
**Fix:** retry after a short wait; if it keeps failing, proceed with everything that does
not need Bash (file edits, manual code review, journal/doc updates) and explicitly tell
the user that `flutter analyze`/`flutter test` still need to be run manually before the
change is considered verified (guardrail 2.7). Do not claim tests "pass" when they were
only reviewed by eye. Encountered 2026-07-12 while wrapping up the Reports page
post-completion fixes; commit `1d59469` landed before analyze/test could be run, but both
were confirmed clean shortly after in the same session once Bash recovered.

### 3.25 Bloc reload transiently emitting non-running state resets a resolved cubit

**Symptom (2026-08-05):** the "logToTask dialog confirmed" test emitted `IdleFlowIdle`
instead of `IdleFlowResolved` after `resolutionWindow.lastOnRequestLogToTask!()`. All
repository writes were correct (3 entries created), but the cubit was back in `Idle`.

**Cause chain:**
1. `_logIdleTimeToSelection` ends with `emit(IdleFlowResolved())` then
   `bloc.add(TimeTrackerEvent.loaded())`.
2. `TimeTrackerBloc` handles `loaded` by emitting `TimeTrackerLoading` (non-running)
   before it finishes re-fetching data and emitting `TimeTrackerRunning`.
3. `_onBlocState` saw `!state.isRunning && _monitorRunning` - TRUE (just stopped
   monitoring) - and then checked `this.state is IdleFlowResolved` - ALSO TRUE - and
   called `_hideResolutionWindow?.call(); emit(IdleFlowIdle())`. The cubit undid its
   own resolution.

**Fix:** `_onBlocState` must only reset to `IdleFlowIdle` when
`this.state is IdleFlowAwaitingResolution`. `IdleFlowResolved` is terminal from the
cubit's perspective - the bloc is free to reload and emit transient states afterwards.
The corrected guard:
```dart
if (this.state is IdleFlowAwaitingResolution) {
  _hideResolutionWindow?.call();
  emit(const IdleFlowIdle());
}
```

**General rule:** whenever a cubit calls `bloc.add(SomeEvent)` after emitting a
resolved/terminal state, ensure the cubit's bloc-state listener does NOT key off that
terminal state for further transitions. Terminal is terminal.

### 3.26 `showDialog` is undefined in a non-widget service class

**Symptom:** `The function 'showDialog' isn't defined.` in `windows_desktop_service.dart`
even though other Flutter types compiled fine.

**Cause:** `showDialog` is a top-level function in `package:flutter/material.dart`.
Service classes typically import `flutter_bloc`, `get_it`, domain types, etc. - none
of which transitively export `showDialog`. It is NOT part of `dart:ui` or the widget
base; it only becomes available when `material.dart` is in scope.

**Fix:**
```dart
import 'package:flutter/material.dart' show showDialog;
```
Using a `show` clause keeps the import surgical and avoids pulling the entire material
namespace into a non-widget file.

### 3.27 `flutter analyze` "path does not exist" when CWD is already inside the app directory

**Symptom:** `fvm flutter analyze apps/worklog_studio/lib/feature/...` run from a
terminal whose CWD is `apps\worklog_studio\` fails with
`error: The path "apps/worklog_studio/lib/feature/..." doesn't exist.`

**Cause:** the path is resolved relative to CWD - prepending `apps/worklog_studio/`
when CWD is already that directory creates a non-existent double-prefix path.

**Fix:** when CWD is already `apps\worklog_studio\`, omit that prefix:
```
fvm flutter analyze lib/feature/settings/... lib/feature/time_tracker/...
```
Alternatively, run from the monorepo root and use the full `apps/worklog_studio/lib/...`
prefix. The analyze command that succeeded in this session was invoked from the
monorepo root via the Bash tool's default CWD.

### 3.24 `await bloc.close()` inside a testWidgets body hangs the test forever
**Symptom:** a widget test passes every pump/expect, then times out at the
10-minute default; marker prints show the last `await bloc.close()` never
completes.
**Cause:** `testWidgets` runs the body in a FakeAsync zone; a Bloc's `close()`
future involves stream teardown that never completes inside that zone
(related to but distinct from pitfall 3.2, which is about construction in
`setUp`).
**Fix:** register `addTearDown(bloc.close)` immediately after constructing the
bloc in the test body - tearDown callbacks run outside the fake zone. Also
note: `flutter test --timeout 30s` does NOT bound testWidgets bodies; use
`testWidgets(..., timeout: Timeout(...))` for a per-test guard. Found via the
open-in-reports widget test (2026-07-15); debugPrint markers after every await
plus a 60s per-test timeout bisected the hang in one run.

### 3.28 `collection` and `time_entry_table` imports become dangling after WsTable removal

**Symptom:** after replacing `WsTable<ResolvedTimeEntry>` usages in a file with
`HistoryStackTable`, the analyzer emits:
- `[undefined_method] The method 'firstWhereOrNull' isn't defined for the type 'List'.`
- `[undefined_method] The method 'getHistoryTableColumns' isn't defined...`
- `[unused_import]` warnings for `collection/collection.dart` and `time_entry_table.dart`

**Cause:** `firstWhereOrNull` was imported via `package:collection/collection.dart`
and only used in `WsTable`'s `selectedItem:` parameter. `getHistoryTableColumns`
and `WsTable` itself were only imported via `time_entry_table.dart`. Once
`HistoryStackTable` handles both selection and column definitions internally,
both imports become dead.

**Fix:** remove `import 'package:collection/collection.dart'` and
`import '.../time_entry_table.dart'` from any file that switches from `WsTable`
to `HistoryStackTable`. Do NOT add `collection` back for `firstWhereOrNull` -
Dart 3 has `Iterable.firstWhereOrNull` in `dart:core` when using the `collection`
package, but `HistoryStackTable` resolves selection by comparing `entry.id`
directly without it.

### 3.30 History table column changes silently misalign if not applied to all three locations

**Symptom:** the stack summary row's cells no longer line up with the header / normal
rows after a column change - or the dashboard "Recent Activity" table still shows a
column (or is missing one) that was added/removed from the history table.

**Cause:** column structure is maintained independently in three files that have no
compile-time link to each other:
1. `getHistoryTableColumns()` in `time_entry_table.dart` - returns a typed list the
   framework renders dynamically, so changing it only affects widgets that call this
   function.
2. `_HistoryStackSummaryRow` in `time_entry_stack_table.dart` - hardcoded
   `Expanded(flex:)` children. No `getHistoryTableColumns` call. Misaligns silently.
3. `_fullColumns()` in `home_page.dart` - completely separate column list for the
   dashboard. Has its own builder methods (`_durationColumn`, `_commentColumn`, etc.)
   that are manually mirrored from the history table.

Removing the Efficiency column in 2026-08-10 required deleting code from all three
locations in one commit. Missing any one of them would have produced visible misalignment
(flex sum changed) or a dangling `_efficiencyColumn` call (unused-declaration warning).

**Prevention checklist for any future column change:**
- [ ] `getHistoryTableColumns()` updated
- [ ] `_HistoryStackSummaryRow` `Expanded(flex:)` sequence updated + the flex comment
      at the top of the class updated to match
- [ ] `home_page._fullColumns()` updated (add/remove/reorder builder method calls)
- [ ] If a builder method in `home_page.dart` becomes unreferenced, DELETE the method
      body - the analyzer flags it as "unused declaration" immediately on save, so never
      leave dead private methods behind

See guardrail 2.10 for the standing rule.

### 3.29 `IntrinsicHeight` throws when a child has unbounded height

**Symptom:** a `Row` containing an `IntrinsicHeight`-stretched child that internally
uses `ListView` (or any widget with infinite intrinsic height) throws:
`"RenderFlex children have non-zero flex but incoming height constraints are unbounded."`

**Cause:** `IntrinsicHeight` asks each child for its intrinsic height and then
sets the `Row`'s height to the maximum. `ListView` reports an infinite intrinsic
height (it is a scrollable, not a fixed-height widget). Infinite + finite = infinite
Row height, which crashes under `Column` or another `IntrinsicHeight`.

**Safe usage:** `IntrinsicHeight` is only safe when every child reports a finite
intrinsic height. `TimeEntryCard` is safe (it resolves to `InteractiveCard` ->
`Padding` -> `CardRow` -> fixed-height children). Do not use `IntrinsicHeight`
around any `Scrollable`, `ListView`, `GridView`, or `Expanded` child.

**Alternative for lists:** use a `LayoutBuilder` to get the available height and
pass it explicitly, or replace the connector-line approach with a `CustomPaint`
overlay drawn behind the list.

---

## 4. FUTURE BACKLOG

Honest list of what is NOT done, with the reason it was deferred.

### 4.1 Deferred by explicit decision (do not start without a human go-ahead)
- **Item 5 - go_router migration.** Highest-complexity item; touches every screen, the
  tray IPC bridge, and `AppNavigationController`. The plan mandates its own isolated
  branch and PR. Current routing: `AppRoute` enum + switch in `AppShell`, pages recreated
  on tab change by design.
- **Item 21 - split `ProjectTaskState`** into a repository cache
  (`ProjectTaskRepository`-style ChangeNotifier) and a `TrackerSelectionState` (or fold
  selection into `TrackerPanelCubit`). Today it mixes cache + CRUD + timer draft
  selection + reload triggers; every drawer receives all of it.
- **Item 46 - EntityResolver consolidation.** Widget `build()` methods still call
  `context.watch<EntityResolver>()` and do O(n) resolution per rebuild; the target is
  resolution inside the feature BLoCs with the resolver as an injected pure service.
- **Item 4 - l10n infrastructure** (skipped by user decision). ~40+ `// TODO: l10n`
  markers are the migration inventory.
- **Item 32 - mini panel footer stats** are a hardcoded placeholder string
  (`'Today 06h 15m   |   Total 24h 30m'` in `_MiniPanelFooter`). Needs wiring to real
  computed totals from the tracker snapshot.
- **Item 38 - `dependency_overrides: uuid`** (skipped by user decision) - investigate and
  remove the override when transitive deps allow.

### 4.2 Known soft spots
- **`work_log` feature** is an isolated prototype (Option B chosen: kept, marked with
  `// PROTOTYPE: not active` comments). It pins the `http` dependency and the legacy
  `IWorkLogRawDataUsecase` naming. Decide eventually: rebuild properly or delete.
- **Widget-test coverage** exists only for the three drawers (15 tests). Pages
  (history/tasks/projects/home), `GlobalTimeTrackerPanel`, mini panel components, and the
  selector components have no widget tests.
- **`GlobalTimeTrackerPanel` selectors** duplicate ProjectSelector/TaskSelector concepts
  with cubit-specific semantics - a candidate for unification once someone designs the
  callback surface to cover the `isRunning` + `exitEditMode` behavior.
- **Deprecation drift:** `withOpacity` (use `.withValues()`), `RegExp` deprecation info
  hints - harmless today, sweep them opportunistically.
- **Dark theme** is structurally possible now (all sidebar/mini-panel/badge colors are
  tokens) but `darkColorsPalette` still duplicates the light values.
- **`time_entry_drawer.dart.saved`** stray file exists in
  `feature/history/presentation/components/` - dead artifact, delete on next touch.

Added in session 2026-07-08:

- **History compaction has no widget tests.** The compact/normal header states,
  go-to-top visibility, stats-toggle scroll-to-top, and the `_CompactToolbarRow`
  composition were verified only by hand and by the deleted size-probe test. Widget
  tests belong in `test\feature\history\` (see 2.6 for the harness pattern).
- **Magic numbers pending tokenization:** the compact title `fontSize: 15` in
  `history_page.dart` (no NunitoSans small-heading token exists); the 50px scroll
  threshold (duplicated conceptually with the KPI strip logic, now one bool but the
  constant is inline); `SegmentedToggle`'s 36/28 heights mirror `PrimaryButton`'s
  private height constants by copy - a shared button-height token in the style system
  would remove the coupling. Also note the `ControlSize` table (32/40/48/52) does not
  match actual `PrimaryButton` heights (28/36/40/44) - unify someday.
- **`NativeActivityWindow` still has zero automated coverage** (pure Win32 FFI, no test
  seam). The hide/show/IsIconic logic is verified only behaviorally. If it regresses
  again, consider extracting a testable state machine around the Win32 calls.
- **Hotkey default change is silent for existing users:** stored bindings from older
  builds override the new Ctrl+Alt defaults until re-saved in Settings. No migration
  was written (deliberate - low impact); revisit if users report "wrong" defaults.
- **Commit c571665 mixed concerns:** it bundled this session's history/hotkey/window
  work with unrelated working-tree edits (ws_table, time_entry_card/drawer, app icon)
  that were already dirty. Nothing to fix, but bisecting through it later will be
  noisier than usual.

Added in session 2026-07-12 (Reports page, [feature]):

- ~~`flutter analyze`/`flutter test` were never re-run against the final commit
  (`1d59469`)~~ **Resolved same session:** once the Bash tool recovered from the
  safety-classifier outage (pitfall 3.23), `fvm flutter analyze
  apps\worklog_studio\lib\feature\reports\
  packages\worklog_studio_style_system\lib\ui_kit\src\table\` came back clean and
  `fvm flutter test test/core/ test/feature/ --reporter expanded` passed 295/295. Left
  here as a reminder of the pattern (manual read-through is not a substitute for running
  the tools once they are available again), not as an outstanding action.
- **Reports feature has zero widget-test coverage.** `ReportsScreen`,
  `ReportsSummaryPanel`, `ReportsTable`, and `WsGroupedTable` are covered only by the
  domain test (`test\core\reports_aggregator_test.dart`) and the bloc test
  (`test\feature\reports\reports_bloc_test.dart`) - no `testWidgets` exercise the actual
  rendered table/chart/toolbar. Follow the drawer-class harness pattern (2.6) if this
  gets picked up.
- **Magic numbers pending tokenization (Reports UI):** donut chart geometry (180x180,
  `radius: 40`, `centerSpaceRadius: 45`, `sectionsSpace: 2` - fl_chart requires literal
  values), `_ProgressBar` height `6`, `WsGroupedTable` row heights `40`/`36`, legend dot
  size `8`, legend `maxWidth: 140`, icon sizes `14`/`16`/`18`, `Select` width `110`. Same
  category as the 2026-07-08 entry above - no design tokens exist yet for these; sweep
  opportunistically if/when a control-metrics token system is introduced.
- **`ReportsAggregator.aggregate(entries: const [])` is called twice per toolbar
  rebuild** (once in `_PeriodToolbar` for the non-custom range label, once again inside
  `_CustomRangeLabel`) purely to obtain `rangeLabel` from an otherwise-empty aggregation.
  Cheap (empty list) but redundant - extract a dedicated pure `rangeLabel()` function as
  a follow-up if `ReportsAggregator` grows more expensive.
- **`WsGroupedTable.initiallyExpanded`** defaults to `false` (changed from `true` during
  this session's post-completion fixes) with no current call site that opts into
  expanded-by-default - if that need never materializes, consider whether the parameter
  is still pulling its weight, or whether "always collapsed" should become the hardcoded
  behavior instead of a configurable default.

Added in session 2026-08-05 (Idle detection fixes, [debug]):

- **`IdleTaskSelectionDialog` has zero automated tests.** The widget itself
  (`ProjectSelector` + `TaskSelector` + `PrimaryInput` + confirm/cancel buttons)
  is exercised only by the cubit-level tests (which mock the dialog as a callback).
  No `testWidgets` exercise project-resets-task, enter-confirms, cancel-returns-null.
  Harness pattern in 2.6 applies (provide `ProjectTaskState`, `TimeTrackerBloc`, etc.).
- **`IdleResolutionWindow` still has zero automated tests.** Now simplified to 3
  buttons (keep/discard/log) with no state. The native Win32 drawing and
  `_kH`/`_kW` geometry are verified only behaviorally.
- **`PrimaryInput` requires a `label` parameter** - it is not optional. Every new
  call site must pass `label:` or the widget will throw at runtime. This is not a
  compile error (the parameter might be named but required), so it only surfaces
  when the dialog is actually shown.
- **The 3-entry sequence in `_logIdleTimeToSelection` has no rollback.** If the
  first `_repository.update` succeeds but the second or third `_repository.insert`
  throws, the original entry is already stopped with no new running entry. Production
  `SqliteTimeEntryRepository` uses transactions, but the `FakeTimeEntryRepository`
  in tests has no transaction semantics. Consider wrapping in a try/catch that at
  minimum re-emits `IdleFlowIdle` on partial failure.

Added in session 2026-07-15 (Reports charts block, [feature]):

- **Reports charts UI still has zero widget-test coverage** (the 2026-07-12 gap
  carries over): the rewritten `ReportsSummaryPanel`, its donut pair, the stacked bar
  chart, and the hover overlay are verified only by analyze + the domain/bloc tests.
  Note the dashboard DOES have `test\feature\home\dashboard_charts_section_test.dart` -
  use it as the harness template if reports widget tests get picked up.
- **New magic numbers pending tokenization:** overlay width `200`, overlay offset
  `24`, bar width `32`, bar corner radius `4`, chart height `220`, breakpoint `900`,
  `_kLeftReservedSize` `36` - same fl_chart-literal category as the existing 4.2
  entries.
- **Selected chart view (donut/bar) is not persisted** across app restarts on either
  the Dashboard or Reports - deliberate parity, revisit only if users ask.

Added in session 2026-08-07 (History entry stacking, [feature]):

- **`groupConsecutiveEntries()` has zero unit tests.** The pure grouping function
  in `time_entry_stack_grouper.dart` has straightforward but non-trivial behaviour
  (three distinct cases: empty list, all-same group, alternating groups). A test
  belongs in `test\core\time_entry_stack_grouper_test.dart`; the fake builder in
  `test\helpers\test_fakes.dart` can generate `ResolvedTimeEntry` instances cheaply.
- **`TimeEntryStackCard` and `HistoryStackTable` have zero widget tests.** Expand/
  collapse toggle, shadow-strip count (1 vs 2 depending on `stack.count`), and
  item-row `onTap` propagation are all verified only by `flutter analyze` + manual
  run. Use the drawer harness pattern (2.6) - both widgets need `TimeTrackerBloc`
  provided.
- **No auto-expand when `selectedEntry` changes to an entry inside a collapsed stack.**
  If external code changes the selected entry (e.g., the drawer closes and history
  re-selects), a collapsed stack that contains the newly selected entry gets
  highlighted but NOT expanded; the user cannot see which specific sub-entry is
  selected without manually expanding. Fix: add `didUpdateWidget` logic to
  `TimeEntryStackCard` / `_HistoryStackTableState` that calls `setState` to expand
  a stack when its `selectedEntry` changes to one of its members.
- ~~**Efficiency column is empty in the stack summary row.**~~ **Resolved 2026-08-10:**
  the entire Efficiency column was removed from all three table locations. When real
  efficiency data exists, re-add it as a proper data column simultaneously in
  `getHistoryTableColumns`, `_HistoryStackSummaryRow`, and `home_page._fullColumns`
  (guardrail 2.10 / pitfall 3.30).
- **`time_entry_table.dart` comment column still uses `FontStyle.italic`** for the
  "No comment" placeholder - violates guardrail 2.4 (no italic text). This is a
  pre-existing issue, not introduced by this session; fix opportunistically.
- **`_HistoryStackSummaryRow` row height is hardcoded to `SizedBox(height: 52)`.**
  Normal rows in `WsTable` use `vertical: theme.spacings.lg` padding (16 + content
  + 16 = typically ~52px). If the content font sizes change, the summary row will
  silently clip or gap. Replace with `IntrinsicHeight` or padding-based sizing to
  match the normal row pattern.

Added in session 2026-08-10 (Column layout standardization, [redesign]):

- **`time_entry_table.dart` comment column still uses `FontStyle.italic`** for the
  "No comment" placeholder text - violates guardrail 2.4 (no italic in UI). Pre-existing
  debt carried forward from 2026-08-07; no other table surface uses italic. Fix: remove
  `fontStyle: hasComment ? null : FontStyle.italic` from the Comment column builder in
  `getHistoryTableColumns()` and replace with a color-only distinction (muted vs. secondary).
- **No Efficiency data means no Efficiency column** - when real per-entry efficiency
  metrics are added to the domain model (`ResolvedTimeEntry`), the column must be
  re-introduced in all three locations simultaneously (see pitfall 3.30). The flex
  position after Duration (before Status) was its historical slot; revisit the order
  when re-adding.
- **`home_page._fullColumns` and `getHistoryTableColumns` are manually mirrored with
  no shared abstraction.** If the history and dashboard tables should always show the
  same columns, extract a shared `getRecentActivityColumns(AppThemeExtension theme)`
  utility (in `feature/common/utils/` or `feature/history/`) and call it from both.
  Today the duplication is two call sites and is manageable; if a third table appears,
  extract immediately.

### 4.3 Standing environment constraints
- Windows-only development; never crawl `macos/`, `ios/`, `android/`, `linux/`, `web/`
  target directories (but remember 3.8: web-specific *source* files exist and keep deps
  alive).
- Tests must pass before build: `build.sh`, `bump.ps1`, and CI all run
  `fvm flutter test test/core/ test/feature/`.
