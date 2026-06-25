# Dashboard Chart Section

## Problem

The Dashboard's top row (`HomePage` in `apps/worklog_studio/lib/feature/home/presentation/home_page.dart`) currently shows three cards — `_DailyFocusCard`, `_WeeklyTotalsCard`, `_TopTasksPreviewCard` — each computing its own ad-hoc aggregation inline inside `build()` via `context.select`/`Selector`. None of them give the user a real picture of where their time goes (no breakdown by project/task, no day-by-day view), and the computation pattern is inline-in-widget rather than going through a proper bloc, which makes it hard to test and inconsistent with how `TimeTrackerBloc` itself is structured.

## Goals

1. Replace the three cards with a chart section offering two views: a donut breakdown (by Project and by Task, side by side) and a bar chart (hours per time bucket).
2. Let the user pick a time period (Today / Week / Month, default Week) and step backward/forward through periods.
3. Keep the UI usable at narrow viewports (stack instead of side-by-side) — no overflow, no broken layout.
4. Introduce a `DashboardChartsBloc` for the section's UI selection state, and a pure, unit-tested aggregation function for turning raw entries into chart-ready data — keeping business logic out of `build()`.
5. Reuse existing conventions: `BadgeUtils.getBadgeColor` for segment coloring, the `_wideBreakpoint`-style `LayoutBuilder` pattern already used in `home_page.dart`, the `EntityResolver`/`Selector` pattern already used by `_RecentActivitySection`.

## Non-goals

- No billable/rate/cost metrics (the domain model has no such fields yet — `Cost est. $0.00` elsewhere in the app is a placeholder, not real data).
- No multi-user breakdown (this app tracks a single user's time; the screenshot's per-user bar chart does not apply).
- No persistence of the selected period/view across app restarts or even across navigating away from Dashboard and back (resets to default `Week` + donut each time `HomePage` is built fresh — consistent with today's behavior, no `PageUiPreferences`-style wiring requested).
- No relocation of the removed `_TopTasksPreviewCard` data elsewhere — it is deleted, not moved.
- No new charting capability beyond donut + bar (no line charts, no drill-down/click-to-filter).

## Architecture

### 1. `DashboardChartsBloc` — UI selection state only

New bloc under `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.dart` (+ `_event.dart`, `_state.dart`, freezed-generated `_bloc.freezed.dart`), following the same `part`-file structure as `TimeTrackerBloc`.

**State** (freezed, single concrete class — no need for union states like `TimeTrackerBlocState` since there's no loading/error axis here):

```dart
@freezed
class DashboardChartsState with _$DashboardChartsState {
  const factory DashboardChartsState({
    @Default(DashboardPeriod.week) DashboardPeriod period,
    required DateTime anchorDate, // any date within the currently selected range
    @Default(DashboardChartView.donut) DashboardChartView view,
  }) = _DashboardChartsState;
}

enum DashboardPeriod { today, week, month }
enum DashboardChartView { donut, bar }
```

`anchorDate` defaults to `DateTime.now()` at construction (truncated to midnight). The bloc itself doesn't compute date ranges — that's the aggregator's job (see below) — it just tracks "which period type" and "anchored when."

**Events:**

```dart
sealed class DashboardChartsEvent {}
class DashboardPeriodChanged extends DashboardChartsEvent { final DashboardPeriod period; }
class DashboardViewChanged extends DashboardChartsEvent { final DashboardChartView view; }
class DashboardPeriodStepped extends DashboardChartsEvent { final int direction; } // -1 = back, +1 = forward
```

Handlers are synchronous, no async/services involved:
- `DashboardPeriodChanged`: sets `period`, resets `anchorDate` to "now" truncated for the new period type (e.g. switching to Month re-anchors to the start of the current month's containing range — handled by the aggregator's range resolution, the bloc just needs *a* date inside the new range, so it can simply reset to `DateTime.now()`).
- `DashboardViewChanged`: sets `view`. If `period == today`, `view` is forced to stay whatever the user picks — bar view for Today renders hourly buckets (see Goals/§3), so there is no forced fallback to donut.
- `DashboardPeriodStepped`: moves `anchorDate` back/forward by one unit of the current period (1 day / 7 days / 1 calendar month).

### 2. `DashboardChartAggregator` — pure aggregation, no Flutter imports

New file `apps/worklog_studio/lib/feature/home/dashboard_chart_aggregator.dart`. Pure Dart, depends only on `domain/resolved_time_entry.dart` — fully unit-testable in `test/feature/home/dashboard_chart_aggregator_test.dart` per the project's TDD rules.

```dart
class DashboardChartAggregator {
  static DashboardChartData aggregate({
    required List<ResolvedTimeEntry> entries,
    required DashboardPeriod period,
    required DateTime anchorDate,
    required DateTime now,
  }) { ... }
}

class DashboardChartData {
  final DateTime rangeStart;
  final DateTime rangeEnd; // exclusive
  final String rangeLabel; // e.g. "Sep 2 → Sep 29"
  final List<DashboardSlice> byProject; // sorted desc by hours
  final List<DashboardSlice> byTask;
  final List<DashboardBucket> bars; // bar-chart buckets, see below
}

class DashboardSlice {
  final String id; // projectId/taskId, "" for unassigned
  final String label;
  final Duration duration;
  final double percentOfTotal;
}

class DashboardBucket {
  final String label; // "Mon", "9am", "Week 1"
  final Duration duration;
}
```

Range + bucket resolution by period:
- **Today**: range = `[midnight today, midnight tomorrow)`. Bars = one bucket per hour that falls within the span of the day's entries (first entry's start hour through last entry's end hour, inclusive), so a day with activity from 9am-5pm produces ~9 buckets, not 24. If there are zero entries, `bars` is empty (empty state handles this in the widget).
- **Week**: range = the Mon-Sun week containing `anchorDate`. Bars = exactly 7 buckets, Mon..Sun, labeled `"Mon"`..`"Sun"`.
- **Month**: range = the calendar month containing `anchorDate`. Bars = one bucket per calendar week that overlaps the month, labeled `"Week 1"`, `"Week 2"`, etc. (week boundaries follow the same Mon-Sun convention as the Week period, so a month can produce 4-6 buckets depending on where it starts/ends).

`byProject`/`byTask` group every entry whose `[startAt, endAt)` overlaps `[rangeStart, rangeEnd)` by `projectId`/`taskId` (falling back to an "No project"/"No task" slice using the same convention as `time_entry_drawer.dart`'s `-no task-` label seen in the reference screenshot). Running entries use `entry.duration(now)` exactly like the existing cards do.

### 3. `_DashboardChartsSection` widget

Replaces the `statsSection` block in `home_page.dart`. Structure:

```
_DashboardChartsSection
├── BlocProvider<DashboardChartsBloc>(create: (_) => DashboardChartsBloc())  // scoped to this section
└── BlocBuilder<DashboardChartsBloc, DashboardChartsState>
    └── Selector<EntityResolver, List<ResolvedTimeEntry>>(selector: (_, r) => r.getResolvedTimeEntries())
        └── builds DashboardChartData via DashboardChartAggregator.aggregate(...)
        └── BaseCard
            ├── _ChartsHeader (period dropdown, ◂ ▸ steppers, range label, donut/bar toggle)
            └── LayoutBuilder → _DonutPair or _BarChart, switched on state.view
```

`DashboardChartsBloc` is provided locally (via `BlocProvider` right above the section, not at the app root) since its state is pure UI selection scoped to this one section — no other widget needs it. This mirrors `EntityResolver` being app-root-scoped (shared, derived data) vs. this bloc being section-scoped (local UI state), keeping the dependency graph honest about who actually needs what.

**`_ChartsHeader`:**
- `Select<DashboardPeriod>`-style dropdown (reusing the existing `Select` widget already used in `time_entry_drawer.dart`) with options Today/Week/Month → dispatches `DashboardPeriodChanged`.
- Two icon buttons (◂ ▸) → dispatch `DashboardPeriodStepped(-1)` / `DashboardPeriodStepped(1)`.
- `Text(rangeLabel)` from the aggregated data.
- A 2-option segmented toggle (donut icon / bar icon) → dispatches `DashboardViewChanged`.

**`_DonutPair`** (shown when `view == donut`):
- Two `PieChart` widgets (fl_chart), "by Project" and "by Task", each with a legend built from `DashboardSlice` (color via `BadgeUtils.getBadgeColor(slice.id)`, falling back to `palette.text.muted` for the unassigned slice exactly as `_taskColumn` in `home_page.dart` already does for stripe coloring).
- `LayoutBuilder`: width >= 900 → `Row` of the two donuts (`Expanded` each); below that → `Column`, full width, donut-then-legend-then-donut-then-legend. This reuses the existing `_wideBreakpoint` constant/pattern already in `home_page.dart` (a second named breakpoint constant, e.g. `_chartsWideBreakpoint`, since the ideal threshold for two donuts-with-legends may differ from the existing card-row breakpoint — confirmed empirically during implementation, default to reusing `_wideBreakpoint` unless it visibly clips).

**`_BarChart`** (shown when `view == bar`):
- Single fl_chart `BarChart`, one bar group per `DashboardBucket`, x-axis label = `bucket.label`, y-axis = hours (decimal, e.g. `4.5`).
- Horizontally responsive: `BarChart` fills available width via its own internal layout (no manual breakpoint needed — fl_chart handles bar spacing).

**Empty state**: if `entries` overlapping the range is empty (`byProject`/`byTask`/`bars` all empty), `_DashboardChartsSection` renders a centered `Text('No time logged for this period.', style: ... color: palette.text.muted)` in place of either chart, matching the existing empty-state text style used in `_TopTasksPreviewCard`/`_RecentActivitySection`.

### 4. Dependency

Add `fl_chart: ^0.69.0` (or latest stable at implementation time) to `apps/worklog_studio/pubspec.yaml`, resolved via `fvm exec melos bootstrap` from the repo root — not a bare `pub get`.

## Testing

- `test/feature/home/dashboard_chart_aggregator_test.dart`: pure unit tests covering range resolution for all 3 periods (including month boundary edge cases — a month starting mid-week, a month with a trailing partial week), bucket count/labels, project/task grouping including the unassigned fallback, running-entry duration via `now`, and the empty-entries case.
- `test/feature/home/dashboard_charts_bloc_test.dart` (bloc_test-style or manual): period/view/step transitions, including that stepping respects the period's unit (day/week/month) and that changing period type re-anchors correctly.
- UI-only changes (chart rendering, layout breakpoints, widget composition) are exempt per the app's TDD rules, but the empty-state branch and the donut/bar/header wiring should still get a smoke `testWidgets` if practical.

## Open questions for implementation time

None outstanding — all scope decisions were resolved during brainstorming (placement, grouping, period set, month bucketing, library choice, bloc shape, Today+bar behavior, narrow-layout behavior).
