# Reports Page - Design Spec

**Date:** 2026-07-12
**Status:** Approved
**Author:** Roman Vavilov

---

## 1. Overview

A new Reports page for the Worklog Studio Flutter desktop app (Windows/macOS). The page aggregates time entries by project and task for a selected period, showing a summary panel (total hours + donut chart + breakdown bar) and a hierarchical grouped table. No billing, no billable amounts, no tabs.

---

## 2. Requirements

### 2.1 What the page contains

- **Top summary panel** (fixed, does not compact on scroll):
  - Total hours for the selected period (large `displayLarge` text)
  - Donut chart showing time distribution by project
  - Horizontal breakdown bar (one colored segment per project, proportional to time)
- **Period toolbar**: Today / Week / Month / Custom presets with stepper buttons (same UX as Dashboard)
- **Grouped table**: hierarchical, project groups collapsible, task rows indented
  - Columns: Name (project name / task name), Hours, Progress bar
  - Total row at the bottom
- No billing columns, no teammate columns, no tabs

### 2.2 What the page does NOT contain

- Billable hours, rates, invoiced amounts
- Per-teammate breakdown
- View mode toggle (cards/table)
- Compact header on scroll (unlike History page)
- Any bar chart (the donut is the only chart)

---

## 3. Architecture

### 3.1 File tree

```
packages/worklog_studio_style_system/
  lib/ui_kit/src/table/
    ws_grouped_table.dart          <- NEW reusable widget
  lib/worklog_studio_style_system.dart  <- barrel: export WsGroupedTable
  UI_KIT.md                        <- document WsGroupedTable

apps/worklog_studio/lib/
  feature/reports/
    bloc/
      reports_bloc.dart
      reports_event.dart
      reports_state.dart
      reports_bloc.freezed.dart    <- hand-written (build_runner broken)
    reports_aggregator.dart        <- pure static aggregate() function + data models
    presentation/
      reports_page.dart            <- thin coordinator (StatelessWidget)
      components/
        reports_summary_panel.dart <- total hours + donut + breakdown bar
        reports_table.dart         <- WsGroupedTable wired to ReportsData
  feature/app/layout/
    app_route.dart                 <- add AppRoute.reports
    app_shell.dart                 <- add case AppRoute.reports
    sidebar_navigation.dart        <- add Reports nav item
  feature/app/app.dart             <- add BlocProvider<ReportsBloc> at MainApp level

test/
  core/
    reports_aggregator_test.dart   <- TDD: written before implementation
  feature/
    reports/
      reports_bloc_test.dart       <- TDD: written before implementation
```

### 3.2 State management layer

| Class | Layer | Reason |
|---|---|---|
| `ReportsBloc` | BLoC (flutter_bloc) | Async, event-driven period state |
| `ReportsState` | Freezed state class | period, anchorDate, customRange |
| Expand/collapse per group | `setState` in `_WsGroupedTableState` | Purely cosmetic, local to widget |

`ReportsBloc` is provided at `MainApp` level in `app.dart` (same as `HistoryBloc`, `ProjectsBloc`, etc.) so period selection survives tab switches.

### 3.3 Data flow

```
EntityResolver (watch) + ReportsBloc state (BlocBuilder)
  -> ReportsAggregator.aggregate()  [pure, called in build()]
  -> ReportsData
  -> ReportsSummaryPanel (donut + bar)
  -> ReportsTable (WsGroupedTable)
```

No caching in BLoC. Same pattern as `DashboardChartsSection`.

---

## 4. Data models

All models live in `feature/reports/reports_aggregator.dart` (feature-internal, not in `lib/domain/`).

```dart
class ReportsTaskRow {
  final String? taskId;
  final String taskName;      // task.title ?? 'Unassigned'  // TODO: l10n
  final Duration duration;
  final double percentOfTotal; // fraction of page-level total
}

class ReportsProjectGroup {
  final String projectId;     // empty string for "No Project" group
  final String projectName;   // project.name ?? 'No Project'  // TODO: l10n
  final Duration totalDuration;
  final double percentOfTotal;
  final List<ReportsTaskRow> tasks;
}

class ReportsData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final Duration totalDuration;
  final List<DashboardSlice> byProject; // reused for donut + breakdown bar
  final List<ReportsProjectGroup> projectGroups; // for table
}
```

`DashboardSlice` is reused from `feature/home/dashboard_chart_aggregator.dart` (already has id, label, duration, percentOfTotal).

---

## 5. ReportsAggregator

Static pure function. No external side effects.

```dart
class ReportsAggregator {
  static ReportsData aggregate({
    required List<ResolvedTimeEntry> entries,
    required DashboardPeriod period,
    required DateTime anchorDate,
    required DateTime now,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  });
}
```

**Algorithm:**
1. Resolve date range from period/anchorDate (same logic as `DashboardChartAggregator._resolveRange`, duplicated - not shared - for independence)
2. Filter entries: `startAt` date falls within [rangeStart, rangeEnd)
3. Group by `projectId` (null -> empty-string sentinel "No Project")
4. Within each project group: group by `taskId` (null -> "Unassigned" task row)
5. Compute `totalDuration` = sum of all in-range entry durations
6. Compute `percentOfTotal` for every group and row = `duration.inMinutes / totalDuration.inMinutes` (0.0 when total is zero)
7. Build `byProject` slices from project groups (reuses the same data, different shape)
8. Sort: project groups by `totalDuration` descending; tasks within each group by `duration` descending
9. "No Project" group always sorts to the bottom regardless of duration

**Range label format:** reuse `DashboardChartAggregator`'s month/weekday constants pattern (private in aggregator).

---

## 6. ReportsBloc

Events (plain classes, no Freezed union - same style as `HistoryBloc`):

```dart
class ReportsPeriodChanged extends ReportsEvent { final DashboardPeriod period; }
class ReportsPeriodStepped extends ReportsEvent { final int direction; } // -1 or +1
class ReportsCustomRangeSelected extends ReportsEvent {
  final DateTime start;
  final DateTime end;
}
```

State (Freezed, hand-written `.freezed.dart`):

```dart
@freezed
abstract class ReportsState with _$ReportsState {
  const factory ReportsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) = _ReportsState;
}
```

Default: `period: DashboardPeriod.week`, `anchorDate: truncate(now, week)`.

Forward-step guard: `DashboardChartsBloc.canStepForward()` is a public static method - reuse it directly.

---

## 7. WsGroupedTable widget (style system)

### 7.1 API

```dart
class WsGroupedTableColumn<G, I> {
  final String title;
  final Widget Function(BuildContext, G) groupCellBuilder;
  final Widget Function(BuildContext, G, I) itemCellBuilder;
  final int flex;
  final double? fixedWidth;
  final Alignment alignment;
}

class WsGroupedTable<G, I> extends StatefulWidget {
  final List<WsGroupedTableColumn<G, I>> columns;
  final List<G> groups;
  final List<I> Function(G) itemsOf;
  final Key Function(G) groupKeyBuilder;
  final Key Function(G, I) itemKeyBuilder;
  final Widget Function(BuildContext)? totalRowBuilder;
  final bool initiallyExpanded;
  final bool showHeader;
}
```

### 7.2 Internal mechanics

- State: `Set<Key> _expandedGroups` in `_WsGroupedTableState`; toggled on group row tap (`setState` - cosmetic only per guardrail 2.2)
- `initiallyExpanded: true` seeds `_expandedGroups` with all group keys in `initState`
- When `groups` list changes identity (new period), `didUpdateWidget` reseeds expanded state
- Render: `Column` with a fixed header row + `Expanded(ListView.builder)` over a flat virtual list of group rows and (when expanded) item rows + optional total row
- Each row: `InkWell` wrapping a `Row` of cells; hover tracked via `MouseRegion` + local `bool _isHovered` per row item (same as `WsTable`)
- Group row first cell: chevron icon (`expand_more` / `chevron_right`) + group content side by side; clicking anywhere on the row toggles expansion
- Item rows: `indent` of `theme.spacings.x2l` on the leading edge of the first cell
- Total row: plain `Row` with bold text, same column widths, top border `border.primary`
- Empty state: if `groups.isEmpty`, render a centered muted text label

### 7.3 Visual spec

- Header row: same as `WsTable` (overline text style, muted color, bottom border)
- Group row background: `background.surface` with `surfaceMuted` on hover
- Item row background: `background.canvas` (slightly recessed) with `surfaceMuted` on hover
- Group row font: `body2Bold`
- Item row font: `body2`
- Row height: 40px for group rows, 36px for item rows (matches `WsTable` density)
- No selection state (Reports table is read-only, no drawer opens on tap)

---

## 8. Reports page layout

```
ReportsScreen (StatelessWidget)
  Padding(x2l horizontal, x2l top)
    Column
      Row (page header)
        Text('Reports', h3)          // TODO: l10n
        _PeriodToolbar               <- Select + steppers + range label
      SizedBox(lg)
      ReportsSummaryPanel
        Row
          _TotalHoursCard            <- MetricCard(label: 'Total hours', value: displayLarge)
          SizedBox(xl)
          _DonutSection              <- PieChart (180x180) + legend (reuse _Donut pattern from dashboard)
        SizedBox(lg)
        _BreakdownBar                <- Row of Flexible containers, height 12px, radius pill
      SizedBox(lg)
      Expanded
        ReportsTable                 <- WsGroupedTable
```

**Period toolbar** is inline in the page header row (right side), not in a separate card. Same Select + stepper pattern as `_ChartsHeader` in `dashboard_charts_section.dart`.

**Donut color** = `BadgeUtils.getBadgeColor(projectId).$2` - same function used in `_Donut` on Dashboard, so colors are consistent across app.

**Breakdown bar segments**: `Flexible(flex: (percentOfTotal * 1000).round())` with `Container` colored per project. Minimum segment width: skip projects with 0 minutes. Rounded ends: `radiuses.pill` on the first and last segment only; internal borders flush.

**Empty state**: when `data.totalDuration == Duration.zero`, replace summary panel and table with a centered `Text('No time logged for this period.')` in `body` style, muted color.

---

## 9. Navigation integration

- `AppRoute.reports` added to enum (between `history` and the Manage section)
- Sidebar: `_navItem(AppRoute.reports, 'Reports', Icons.bar_chart_rounded)` placed between History and the "Manage" section label
- `isSettingsRoute()` unchanged
- `app_shell.dart` switch: `case AppRoute.reports: return const ReportsScreen()`
- No IPC navigation (`DesktopServiceRegistry.navigationStream` does not need to handle "reports" - the mini panel has no Reports shortcut)

---

## 10. Testing strategy (TDD - red first)

### 10.1 `test/core/reports_aggregator_test.dart`

Tests written BEFORE `ReportsAggregator` implementation:

| Test | Assertion |
|---|---|
| empty entries | `totalDuration == Duration.zero`, `projectGroups.isEmpty` |
| single entry no project/task | one "No Project" group, one "Unassigned" task row |
| two projects same period | two groups, sorted by duration desc |
| entry outside range | excluded from results |
| percentOfTotal sum | `byProject.map((s) => s.percentOfTotal).sum ~= 1.0` |
| "No Project" sort position | always last regardless of duration |
| custom range | only entries within [start, end) included |

### 10.2 `test/feature/reports/reports_bloc_test.dart`

| Test | Assertion |
|---|---|
| initial state | `period == week`, `anchorDate == truncated now` |
| `ReportsPeriodChanged(today)` | period changes, anchorDate resets to today |
| `ReportsPeriodStepped(-1)` on week | anchorDate moves back 7 days |
| `ReportsPeriodStepped(+1)` at current week | no change (canStepForward guard) |
| `ReportsCustomRangeSelected` | period = custom, custom dates set |

### 10.3 Out of scope for this spec

- Widget tests for `ReportsScreen` and `WsGroupedTable` (post-ship, same situation as History compaction tests)
- `WsGroupedTable` unit tests (visual component, no testable business logic)

---

## 11. Design system guardrails

All rules from `POST_MORTEM_REFACTOR.md` apply:

- No hardcoded `Color(0xFF...)` - use `context.theme.colorsPalette.*`
- No hardcoded pixel paddings - use `context.theme.spacings.*`
- No italic text anywhere
- No `Icon(icon, size: N)` inside `PrimaryButton` (not applicable here but noted)
- `AnimatedDefaultTextStyle` must have explicit color (not used on this page)
- `setState` only for cosmetic state (expand/collapse in `WsGroupedTable` qualifies)
- All user-visible hardcoded strings: `// TODO: l10n`
- New assets: none (use standard Material `Icons`)
- `build_runner` is broken: hand-write `reports_bloc.freezed.dart` copying `dashboard_charts_bloc.freezed.dart` pattern

---

## 12. Out of scope / future backlog

- Export to CSV/PDF
- Project filter (show only selected projects)
- Sort direction toggle on table columns
- Dark theme (tokens ready, palette values TBD)
- l10n strings (tracked by `// TODO: l10n` markers per guardrail 2.5)
