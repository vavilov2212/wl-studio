# Reports Charts Block Redesign - Design Spec

Date: 2026-07-15
Status: approved by fiat (user delegated all design decisions, no spec review requested)

## Goal

Make the Reports page a complete self-service report: the charts block mirrors the
Dashboard charts card (card container, project AND task breakdowns, donut/bar view
toggle), while the grouped table below stays the detailed drill-down. The charts block
must stay compact so the table does not get pushed far down.

## Current state

- `ReportsSummaryPanel` renders bare (no card): Total hours column + one project donut
  + legend. No task breakdown, no bar chart, no view toggle.
- Period controls (`_PeriodToolbar`: Today/Week/Month/Custom + steppers) live at page
  level in `reports_page.dart` next to the "Reports" title. They control BOTH the
  charts and the table - this placement is correct and stays.
- `ReportsAggregator` produces `totalDuration`, `byProject` slices, `projectGroups`
  (for the table). No `byTask`, no bar buckets.
- `ReportsState` has `period/anchorDate/customRangeStart/customRangeEnd`. No view field.
- Dashboard reference implementation: `dashboard_charts_section.dart` (BaseCard,
  SegmentedToggle donut/bar, `_DonutPair` with Project + Task donuts, `_BarChart` with
  MouseRegion hover, `_chartScale` axis math), `DashboardChartAggregator` (byTask,
  `_buildBuckets`: today -> hourly, week -> 7 days, month -> weeks, custom -> no bars).

## Design

### 1. Layout (reports_page.dart)

Unchanged page skeleton: title + `_PeriodToolbar` row, then scrollable column with
`ReportsSummaryPanel` and `ReportsTable`, `theme.spacings.lg` between them. The
summary panel becomes a `BaseCard`; the table block is untouched. Page-level empty
state (no entries in range -> centered message, no card/table) stays as is.

### 2. Charts card (reports_summary_panel.dart, rewritten)

- Root: `BaseCard(padding: EdgeInsets.all(theme.spacings.lg))` - same as Dashboard.
- Header row inside the card: nothing on the left (period controls are page-level);
  right-aligned `SegmentedToggle<DashboardChartView>` with donut/bar icon options
  (same icons as Dashboard). The toggle is hidden when `period == custom`
  (custom ranges are donut-only, mirroring Dashboard).
  Since the card has no other header content, the toggle row and the content row are
  merged: the toggle sits top-right of the content via a Row/Stack, keeping the card
  short instead of adding a header band.
- Content, donut view: `Row` (wide) / `Column` (narrow, LayoutBuilder breakpoint 900
  like Dashboard):
  - Column "Total hours" (caption + `displayLarge` duration) - kept from current panel.
  - Donut "Project": 180x180 PieChart (radius 40, centerSpace 45, sectionsSpace 2)
    + legend rows (color dot, label maxWidth 140 ellipsized, "X.Xh (NN%)").
  - Donut "Task": same widget fed by new `data.byTask` slices.
  - Colors: `BadgeUtils.getBadgeColor(id).$2`; `palette.text.muted` for the empty-id
    sentinel slice (No Project / Unassigned).
- Content, bar view: same "Total hours" column on the left + stacked bar chart
  (height 220, same as Dashboard `_BarChart`) filling the remaining width.

### 3. Stacked bar chart (new widget inside reports_summary_panel.dart)

- fl_chart `BarChart` with one rod per bucket; each rod uses `rodStackItems` -
  one `BarChartRodStackItem(from, to, color)` per project segment, colored via
  `BadgeUtils` (muted for No Project). Segment stacking order = `byProject` order
  (largest first, No Project last) so colors read consistently across bars.
- Axis math: reuse Dashboard's clean-step scale. The private `_chartScale` in
  `dashboard_charts_section.dart` is extracted to
  `lib\feature\common\utils\chart_scale.dart` as public `chartScale(double maxHours)`
  and both call sites use it (targeted dedup, gets a unit test per TDD).
- Hover: fl_chart tooltips stay disabled; a `MouseRegion` computes the hovered bar
  index from pointer x (same technique as Dashboard `_BarChart`). Hover effects:
  - hovered bar gets `backDrawRodData` highlight (accent alpha 0.08) and a bold
    accent bottom label, like Dashboard;
  - an overlay legend card appears inside a `Stack` above the chart, positioned next
    to the hovered bar (right side, flipping to the left near the right edge, clamped
    to chart bounds). Contents: bucket label caption, bold total ("X.Xh"), then one
    row per segment: color dot + project name (ellipsized) + hours. Styling:
    `background.surface`, `border.primary` border, `theme.shadows.md`, `radiuses.md`.
- Buckets with zero total render no rod (fl_chart handles toY 0); hovering them shows
  no overlay.

### 4. Aggregator (reports_aggregator.dart)

New models:

```dart
class ReportsBarSegment { final String projectId; final String projectName; final Duration duration; }
class ReportsBar { final String label; final Duration total; final List<ReportsBarSegment> segments; }
```

`ReportsData` gains `final List<ReportSlice> byTask` and `final List<ReportsBar> bars`.

- `byTask`: flat task totals across all projects ('' sentinel -> "Unassigned"),
  percent of grand total, sorted by duration desc with the sentinel last (same rule
  as `byProject`).
- `bars`: bucketing mirrors `DashboardChartAggregator._buildBuckets` exactly:
  today -> hourly buckets clipped to [minHour, maxHour] with entries ("9 AM" labels);
  week -> 7 day buckets ("Mon 6"); month -> calendar-week buckets ("Week N");
  custom -> empty list (bar view unavailable, toggle hidden).
  Each bucket's `segments` lists only projects with nonzero time in that bucket,
  ordered by the global `byProject` order.
- Entries attribute to the bucket containing `startAt` (existing convention).

### 5. Bloc (reports_bloc.dart + parts)

- `DashboardChartView { donut, bar }` enum MOVES from `dashboard_charts_bloc.dart`
  to `dashboard_chart_aggregator.dart` (next to `DashboardPeriod`, which Reports
  already imports). Home imports need no changes: `dashboard_charts_section.dart`
  already imports the aggregator, and `dashboard_charts_state.dart` is a part of the
  bloc which imports the aggregator. This follows the "shared enum moves to a shared
  file" extraction rule instead of importing another feature's bloc.
- `ReportsState` gains `@Default(DashboardChartView.donut) DashboardChartView view`.
  `reports_bloc.freezed.dart` is hand-edited (build_runner is broken): add the field
  to the mixin getters, ==, hashCode, toString, both copyWith impls, the patterns
  extension signatures, and `_ReportsState`.
- New event `ReportsViewChanged(DashboardChartView view)` + handler
  (`emit(state.copyWith(view: event.view))`). View survives period changes and
  steps (copyWith preserves it); switching to custom simply hides the toggle and
  forces donut rendering in the UI without mutating `view`.

### 6. Out of scope

- Table changes, WsGroupedTable changes: none.
- Persisting the selected view across app restarts: not done (Dashboard does not
  persist it either).
- New style-system components: none needed (BaseCard, SegmentedToggle exist).

## Testing (TDD, red -> green per unit)

- `test/core/reports_aggregator_test.dart`: byTask grouping/sentinel/sort; bars for
  week (7 buckets, stacked segments per project, correct totals), today (hourly
  clipping), month (week count), custom (empty); segment ordering matches byProject.
- `test/core/chart_scale_test.dart`: extracted `chartScale` (zero, small, large,
  fallback branch).
- `test/feature/reports/reports_bloc_test.dart`: default view donut;
  `ReportsViewChanged(bar)` flips view; view preserved across
  `ReportsPeriodChanged`/`ReportsPeriodStepped`.
- UI verification: `fvm flutter analyze` on touched paths + full
  `fvm flutter test test/core/ test/feature/` (widget tests for reports remain a
  known gap, per POST_MORTEM 4.2 - not expanded in this task).
