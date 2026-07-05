# Dashboard Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Dashboard's three stat cards (Daily Focus / This Week / Top Tasks) with a chart section offering a donut breakdown (by Project and by Task) and a bar chart (hours per time bucket), with a Today/Week/Month period selector (default Week) and prev/next navigation.

**Architecture:** A thin `DashboardChartsBloc` (flutter_bloc + freezed) owns only UI selection state (period, anchor date, donut/bar view). A pure, dependency-free `DashboardChartAggregator` turns raw `ResolvedTimeEntry` lists into chart-ready data (range, per-project/per-task breakdowns, bar buckets). The widget layer combines the bloc's state with `EntityResolver`'s resolved entries (the same `Selector` pattern `_RecentActivitySection` already uses) and calls the aggregator — no business logic inside `build()`.

**Tech Stack:** Flutter, `flutter_bloc` + `freezed` (existing), `provider` (existing), new dependency: `fl_chart` for the donut/bar rendering.

## Global Constraints

- All commands run via `fvm` (never bare `flutter`/`dart`). Dependency resolution goes through `fvm exec melos bootstrap` from the repo root, never a bare `pub get`.
- Never touch `*.freezed.dart`/`*.g.dart` directly — regenerate via `fvm flutter pub run build_runner build --delete-conflicting-outputs` from `apps/worklog_studio`.
- New business logic (the aggregator, the bloc) must be written test-first (Red → Green → Refactor) per `apps/worklog_studio/CLAUDE.md`. UI-only composition is exempt but gets a smoke test where practical.
- No hardcoded colors/paddings in `apps/worklog_studio` — use `context.theme`/`palette` tokens from `worklog_studio_style_system`.
- No billable/rate/cost metrics, no multi-user breakdown, no persistence of the selected period/view across navigation (resets to default Week + donut each time, matching today's behavior).
- Never add a `Co-Authored-By: Claude` trailer to commit messages.

---

### Task 1: Add the `fl_chart` dependency

**Files:**
- Modify: `apps/worklog_studio/pubspec.yaml`

**Interfaces:**
- Produces: the `fl_chart` package available for import as `package:fl_chart/fl_chart.dart` in later tasks.

- [ ] **Step 1: Add the dependency**

In `apps/worklog_studio/pubspec.yaml`, find the `# Helpers` section:

```yaml
  # Helpers
  intl: ^0.20.2
  vector_svg: 
    path: ../../packages/vector_svg
  path_provider: ^2.1.5
  collection: ^1.19.1
  window_manager: ^0.4.3
  tray_manager: ^0.2.3
```

Add a new section right after it:

```yaml
  # Helpers
  intl: ^0.20.2
  vector_svg: 
    path: ../../packages/vector_svg
  path_provider: ^2.1.5
  collection: ^1.19.1
  window_manager: ^0.4.3
  tray_manager: ^0.2.3

  # Charts
  fl_chart: ^0.69.2
```

- [ ] **Step 2: Resolve dependencies via melos**

Run from the repo root (`d:\work\wl_studio`):

```bash
fvm exec melos bootstrap
```

Expected: completes without errors. If `fl_chart: ^0.69.2` fails to resolve (e.g. a newer major is the only one left on pub.dev), bump the version constraint in `pubspec.yaml` to the latest stable `fl_chart` release and re-run `fvm exec melos bootstrap` until it succeeds.

- [ ] **Step 3: Verify the import resolves**

Run from `apps/worklog_studio`:

```bash
fvm flutter analyze lib/feature/home/presentation/home_page.dart
```

Expected: `No issues found!` (this just confirms bootstrap didn't break the existing build; `fl_chart` isn't imported anywhere yet).

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/pubspec.yaml apps/worklog_studio/pubspec.lock
git commit -m "deps: add fl_chart for dashboard charts"
```

---

### Task 2: `DashboardChartAggregator` — pure aggregation logic

**Files:**
- Create: `apps/worklog_studio/lib/feature/home/dashboard_chart_aggregator.dart`
- Test: `apps/worklog_studio/test/feature/home/dashboard_chart_aggregator_test.dart`

**Interfaces:**
- Consumes: `ResolvedTimeEntry` (`apps/worklog_studio/lib/domain/resolved_time_entry.dart`) — fields used: `startAt` (`DateTime`), `duration(DateTime now)` (`Duration`), `projectId`/`taskId` (`String?`), `projectName`/`taskTitle` (`String`, already default to `'No Project'`/`'Unassigned Task'`).
- Produces (consumed by Task 3's bloc default state and Task 7's widget):
  - `enum DashboardPeriod { today, week, month }`
  - `class DashboardSlice { String id; String label; Duration duration; double percentOfTotal; }`
  - `class DashboardBucket { String label; Duration duration; }`
  - `class DashboardChartData { DateTime rangeStart; DateTime rangeEnd; String rangeLabel; List<DashboardSlice> byProject; List<DashboardSlice> byTask; List<DashboardBucket> bars; }`
  - `DashboardChartAggregator.aggregate({required List<ResolvedTimeEntry> entries, required DashboardPeriod period, required DateTime anchorDate, required DateTime now}) -> DashboardChartData`

- [ ] **Step 1: Write the failing test file**

Create `apps/worklog_studio/test/feature/home/dashboard_chart_aggregator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

ResolvedTimeEntry _entry({
  required String id,
  required DateTime startAt,
  DateTime? endAt,
  String? projectId,
  String? taskId,
}) {
  final project = projectId == null
      ? null
      : Project(
          id: projectId,
          name: 'Project $projectId',
          description: '',
          createdAt: DateTime(2024, 1, 1),
        );
  final task = taskId == null
      ? null
      : Task(
          id: taskId,
          projectId: projectId ?? '',
          title: 'Task $taskId',
          description: '',
          status: TaskStatus.open,
          createdAt: DateTime(2024, 1, 1),
        );
  return ResolvedTimeEntry(
    entry: TimeEntry(
      id: id,
      projectId: projectId,
      taskId: taskId,
      startAt: startAt,
      endAt: endAt,
      status: endAt == null ? TimeEntryStatus.running : TimeEntryStatus.stopped,
    ),
    project: project,
    task: task,
  );
}

void main() {
  group('DashboardChartAggregator.aggregate', () {
    test('today: buckets hours by hour-of-day, range covers only that day', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 17, 9),
          endAt: DateTime(2024, 1, 17, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        _entry(
          id: 'e2',
          startAt: DateTime(2024, 1, 17, 11),
          endAt: DateTime(2024, 1, 17, 12),
          projectId: 'p1',
          taskId: 't2',
        ),
        // Outside the range entirely — must not be counted.
        _entry(
          id: 'e3',
          startAt: DateTime(2024, 1, 16, 9),
          endAt: DateTime(2024, 1, 16, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.today,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 17, 15),
      );

      expect(data.rangeStart, DateTime(2024, 1, 17));
      expect(data.rangeEnd, DateTime(2024, 1, 18));
      expect(data.rangeLabel, 'Jan 17');
      expect(data.bars.map((b) => b.label).toList(), ['9 AM', '10 AM', '11 AM']);
      expect(data.bars.map((b) => b.duration).toList(), [
        const Duration(hours: 1),
        Duration.zero,
        const Duration(hours: 1),
      ]);
      expect(data.byProject.single.id, 'p1');
      expect(data.byProject.single.duration, const Duration(hours: 2));
      expect(data.byProject.single.percentOfTotal, 1.0);
      expect(data.byTask.map((s) => s.id).toSet(), {'t1', 't2'});
    });

    test('today with no entries that day produces empty bars', () {
      final data = DashboardChartAggregator.aggregate(
        entries: const [],
        period: DashboardPeriod.today,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 17, 15),
      );

      expect(data.bars, isEmpty);
      expect(data.byProject, isEmpty);
      expect(data.byTask, isEmpty);
    });

    test('week: range is the Mon-Sun week containing anchorDate, 7 day buckets', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 15, 9), // Monday
          endAt: DateTime(2024, 1, 15, 10),
          projectId: 'pA',
          taskId: 'tA1',
        ),
        _entry(
          id: 'e2',
          startAt: DateTime(2024, 1, 17, 9), // Wednesday
          endAt: DateTime(2024, 1, 17, 11),
          projectId: 'pA',
          taskId: 'tA2',
        ),
        _entry(
          id: 'e3',
          startAt: DateTime(2024, 1, 21, 9), // Sunday
          endAt: DateTime(2024, 1, 21, 9, 30),
          projectId: 'pB',
          taskId: 'tB1',
        ),
        // Next Monday — outside the range.
        _entry(
          id: 'e4',
          startAt: DateTime(2024, 1, 22, 9),
          endAt: DateTime(2024, 1, 22, 10),
          projectId: 'pA',
          taskId: 'tA1',
        ),
        // Previous Sunday — outside the range.
        _entry(
          id: 'e5',
          startAt: DateTime(2024, 1, 14, 9),
          endAt: DateTime(2024, 1, 14, 10),
          projectId: 'pA',
          taskId: 'tA1',
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.week,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 22),
      );

      expect(data.rangeStart, DateTime(2024, 1, 15));
      expect(data.rangeEnd, DateTime(2024, 1, 22));
      expect(data.rangeLabel, 'Jan 15 → Jan 21');
      expect(data.bars.map((b) => b.label).toList(),
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
      expect(data.bars.map((b) => b.duration).toList(), [
        const Duration(hours: 1),
        Duration.zero,
        const Duration(hours: 2),
        Duration.zero,
        Duration.zero,
        Duration.zero,
        const Duration(minutes: 30),
      ]);

      expect(data.byProject.map((s) => s.id).toList(), ['pA', 'pB']);
      expect(data.byProject[0].duration, const Duration(hours: 3));
      expect(data.byProject[1].duration, const Duration(minutes: 30));
      expect(data.byProject[0].percentOfTotal, closeTo(0.857, 0.001));
      expect(data.byProject[1].percentOfTotal, closeTo(0.143, 0.001));
    });

    test('month: range is the calendar month, buckets are Mon-Sun weeks', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 1, 9), // Monday, week 1
          endAt: DateTime(2024, 1, 1, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        _entry(
          id: 'e2',
          startAt: DateTime(2024, 1, 8, 9), // Monday, week 2
          endAt: DateTime(2024, 1, 8, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        _entry(
          id: 'e3',
          startAt: DateTime(2024, 1, 29, 9), // Monday, week 5
          endAt: DateTime(2024, 1, 29, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        // February — outside the range.
        _entry(
          id: 'e4',
          startAt: DateTime(2024, 2, 1, 9),
          endAt: DateTime(2024, 2, 1, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.month,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 30),
      );

      expect(data.rangeStart, DateTime(2024, 1, 1));
      expect(data.rangeEnd, DateTime(2024, 2, 1));
      expect(data.rangeLabel, 'Jan 2024');
      expect(data.bars.map((b) => b.label).toList(),
          ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5']);
      expect(data.bars.map((b) => b.duration).toList(), [
        const Duration(hours: 1),
        const Duration(hours: 1),
        Duration.zero,
        Duration.zero,
        const Duration(hours: 1),
      ]);
      expect(data.byProject.single.duration, const Duration(hours: 3));
    });

    test('unassigned entries fall back to ResolvedTimeEntry default labels with empty id', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 17, 9),
          endAt: DateTime(2024, 1, 17, 10),
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.today,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 17, 12),
      );

      expect(data.byProject.single.id, '');
      expect(data.byProject.single.label, 'No Project');
      expect(data.byTask.single.id, '');
      expect(data.byTask.single.label, 'Unassigned Task');
    });

    test('running entry duration is computed against the supplied now', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 17, 9),
          projectId: 'p1',
          taskId: 't1',
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.today,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 17, 11),
      );

      expect(data.byProject.single.duration, const Duration(hours: 2));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

From `apps/worklog_studio`:

```bash
fvm flutter test test/feature/home/dashboard_chart_aggregator_test.dart
```

Expected: FAIL — `Error: Error when reading 'lib/feature/home/dashboard_chart_aggregator.dart': No such file or directory` (or an unresolved-import compile error).

- [ ] **Step 3: Implement `DashboardChartAggregator`**

Create `apps/worklog_studio/lib/feature/home/dashboard_chart_aggregator.dart`:

```dart
import 'package:worklog_studio/domain/resolved_time_entry.dart';

enum DashboardPeriod { today, week, month }

class DashboardSlice {
  final String id;
  final String label;
  final Duration duration;
  final double percentOfTotal;

  const DashboardSlice({
    required this.id,
    required this.label,
    required this.duration,
    required this.percentOfTotal,
  });
}

class DashboardBucket {
  final String label;
  final Duration duration;

  const DashboardBucket({required this.label, required this.duration});
}

class DashboardChartData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final List<DashboardSlice> byProject;
  final List<DashboardSlice> byTask;
  final List<DashboardBucket> bars;

  const DashboardChartData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.byProject,
    required this.byTask,
    required this.bars,
  });
}

class _Range {
  final DateTime start;
  final DateTime end;
  const _Range(this.start, this.end);
}

class DashboardChartAggregator {
  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static DashboardChartData aggregate({
    required List<ResolvedTimeEntry> entries,
    required DashboardPeriod period,
    required DateTime anchorDate,
    required DateTime now,
  }) {
    final range = _resolveRange(period, anchorDate);
    final inRange = entries.where((e) {
      final day = _dateOnly(e.startAt);
      return !day.isBefore(range.start) && day.isBefore(range.end);
    }).toList();

    final byProject = _groupBy(
      inRange,
      now,
      idOf: (e) => e.projectId ?? '',
      labelOf: (e) => e.projectName,
    );
    final byTask = _groupBy(
      inRange,
      now,
      idOf: (e) => e.taskId ?? '',
      labelOf: (e) => e.taskTitle,
    );
    final bars = _buildBuckets(period, range, inRange, now);

    return DashboardChartData(
      rangeStart: range.start,
      rangeEnd: range.end,
      rangeLabel: _label(period, range),
      byProject: byProject,
      byTask: byTask,
      bars: bars,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static _Range _resolveRange(DashboardPeriod period, DateTime anchorDate) {
    final anchor = _dateOnly(anchorDate);
    switch (period) {
      case DashboardPeriod.today:
        return _Range(anchor, anchor.add(const Duration(days: 1)));
      case DashboardPeriod.week:
        final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
        return _Range(weekStart, weekStart.add(const Duration(days: 7)));
      case DashboardPeriod.month:
        final monthStart = DateTime(anchor.year, anchor.month, 1);
        final monthEnd = DateTime(anchor.year, anchor.month + 1, 1);
        return _Range(monthStart, monthEnd);
    }
  }

  static String _label(DashboardPeriod period, _Range range) {
    switch (period) {
      case DashboardPeriod.today:
        return '${_monthNames[range.start.month - 1]} ${range.start.day}';
      case DashboardPeriod.week:
        final lastDay = range.end.subtract(const Duration(days: 1));
        return '${_monthNames[range.start.month - 1]} ${range.start.day} → '
            '${_monthNames[lastDay.month - 1]} ${lastDay.day}';
      case DashboardPeriod.month:
        return '${_monthNames[range.start.month - 1]} ${range.start.year}';
    }
  }

  static List<DashboardSlice> _groupBy(
    List<ResolvedTimeEntry> entries,
    DateTime now, {
    required String Function(ResolvedTimeEntry) idOf,
    required String Function(ResolvedTimeEntry) labelOf,
  }) {
    final totals = <String, Duration>{};
    final labels = <String, String>{};
    for (final entry in entries) {
      final id = idOf(entry);
      totals[id] = (totals[id] ?? Duration.zero) + entry.duration(now);
      labels[id] = labelOf(entry);
    }
    final totalMinutes = totals.values.fold<int>(0, (sum, d) => sum + d.inMinutes);
    final slices = totals.entries
        .map((e) => DashboardSlice(
              id: e.key,
              label: labels[e.key]!,
              duration: e.value,
              percentOfTotal: totalMinutes == 0 ? 0 : e.value.inMinutes / totalMinutes,
            ))
        .toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    return slices;
  }

  static List<DashboardBucket> _buildBuckets(
    DashboardPeriod period,
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
  ) {
    switch (period) {
      case DashboardPeriod.today:
        return _hourlyBuckets(inRange, now);
      case DashboardPeriod.week:
        return _weeklyBuckets(range, inRange, now);
      case DashboardPeriod.month:
        return _monthlyBuckets(range, inRange, now);
    }
  }

  static List<DashboardBucket> _hourlyBuckets(
    List<ResolvedTimeEntry> inRange,
    DateTime now,
  ) {
    if (inRange.isEmpty) return [];
    final hours = inRange.map((e) => e.startAt.hour).toList();
    final minHour = hours.reduce((a, b) => a < b ? a : b);
    final maxHour = hours.reduce((a, b) => a > b ? a : b);

    final totals = List<Duration>.filled(maxHour - minHour + 1, Duration.zero);
    for (final entry in inRange) {
      totals[entry.startAt.hour - minHour] += entry.duration(now);
    }

    return List.generate(totals.length, (i) {
      return DashboardBucket(label: _hourLabel(minHour + i), duration: totals[i]);
    });
  }

  static String _hourLabel(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }

  static List<DashboardBucket> _weeklyBuckets(
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
  ) {
    final totals = List<Duration>.filled(7, Duration.zero);
    for (final entry in inRange) {
      final dayIndex = _dateOnly(entry.startAt).difference(range.start).inDays;
      if (dayIndex < 0 || dayIndex > 6) continue;
      totals[dayIndex] += entry.duration(now);
    }
    return List.generate(
      7,
      (i) => DashboardBucket(label: _weekdayLabels[i], duration: totals[i]),
    );
  }

  static List<DashboardBucket> _monthlyBuckets(
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
  ) {
    final monthStart = range.start;
    final firstWeekdayOffset = monthStart.weekday - 1;
    final daysInMonth = range.end.difference(monthStart).inDays;
    final weekCount = ((daysInMonth + firstWeekdayOffset - 1) ~/ 7) + 1;

    final totals = List<Duration>.filled(weekCount, Duration.zero);
    for (final entry in inRange) {
      final dayOfMonth = _dateOnly(entry.startAt).difference(monthStart).inDays;
      final weekIndex = (dayOfMonth + firstWeekdayOffset) ~/ 7;
      totals[weekIndex] += entry.duration(now);
    }
    return List.generate(
      weekCount,
      (i) => DashboardBucket(label: 'Week ${i + 1}', duration: totals[i]),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
fvm flutter test test/feature/home/dashboard_chart_aggregator_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/home/dashboard_chart_aggregator.dart apps/worklog_studio/test/feature/home/dashboard_chart_aggregator_test.dart
git commit -m "feat: add DashboardChartAggregator for dashboard chart data"
```

---

### Task 3: `DashboardChartsBloc` — period/view UI selection state

**Files:**
- Create: `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.dart`
- Create: `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_event.dart`
- Create: `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_state.dart`
- Test: `apps/worklog_studio/test/feature/home/dashboard_charts_bloc_test.dart`
- (generated) `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.freezed.dart`

**Interfaces:**
- Consumes: `DashboardPeriod` from Task 2's `dashboard_chart_aggregator.dart`; `Clock` abstract class from `apps/worklog_studio/lib/domain/time_tracker.dart` (`DateTime now()`); `SystemClock` from `apps/worklog_studio/lib/data/system_clock.dart`.
- Produces (consumed by Task 7's widget):
  - `enum DashboardChartView { donut, bar }`
  - `class DashboardChartsState { DashboardPeriod period; DateTime anchorDate; DashboardChartView view; }` with generated `copyWith`.
  - `sealed class DashboardChartsEvent` with factories: `DashboardChartsEvent.periodChanged(DashboardPeriod period)`, `DashboardChartsEvent.viewChanged(DashboardChartView view)`, `DashboardChartsEvent.periodStepped(int direction)`.
  - `class DashboardChartsBloc extends Bloc<DashboardChartsEvent, DashboardChartsState>` with constructor `DashboardChartsBloc({Clock? clock})`.

- [ ] **Step 1: Write the failing test file**

Create `apps/worklog_studio/test/feature/home/dashboard_charts_bloc_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/bloc/dashboard_charts_bloc.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

class _FixedClock implements Clock {
  final DateTime _now;
  const _FixedClock(this._now);

  @override
  DateTime now() => _now;
}

Future<DashboardChartsState> pump(
  DashboardChartsBloc bloc,
  DashboardChartsEvent event,
) async {
  bloc.add(event);
  await Future<void>.delayed(Duration.zero);
  return bloc.state;
}

void main() {
  group('DashboardChartsBloc', () {
    test('initial state defaults to week period, donut view, anchored at clock "now"', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      expect(bloc.state.period, DashboardPeriod.week);
      expect(bloc.state.view, DashboardChartView.donut);
      expect(bloc.state.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('periodChanged switches period and re-anchors to "now", snapped per period', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      final monthState = await pump(
        bloc,
        const DashboardChartsEvent.periodChanged(DashboardPeriod.month),
      );
      expect(monthState.period, DashboardPeriod.month);
      expect(monthState.anchorDate, DateTime(2024, 1, 1));

      final todayState = await pump(
        bloc,
        const DashboardChartsEvent.periodChanged(DashboardPeriod.today),
      );
      expect(todayState.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('viewChanged switches between donut and bar', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      final state = await pump(bloc, const DashboardChartsEvent.viewChanged(DashboardChartView.bar));
      expect(state.view, DashboardChartView.bar);
      await bloc.close();
    });

    test('periodStepped on week period moves the anchor by 7 days', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      final back = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(back.anchorDate, DateTime(2024, 1, 10));
      final forward = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(forward.anchorDate, DateTime(2024, 1, 17));
      await bloc.close();
    });

    test('periodStepped on today period moves the anchor by 1 day', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.periodChanged(DashboardPeriod.today));
      final state = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(state.anchorDate, DateTime(2024, 1, 16));
      await bloc.close();
    });

    test('periodStepped on month period moves by a calendar month, snapped to day 1', () async {
      final bloc = DashboardChartsBloc(clock: const _FixedClock(DateTime(2024, 1, 17)));
      await pump(bloc, const DashboardChartsEvent.periodChanged(DashboardPeriod.month));
      final next = await pump(bloc, const DashboardChartsEvent.periodStepped(1));
      expect(next.anchorDate, DateTime(2024, 2, 1));
      final prev = await pump(bloc, const DashboardChartsEvent.periodStepped(-1));
      expect(prev.anchorDate, DateTime(2024, 1, 1));
      await bloc.close();
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
fvm flutter test test/feature/home/dashboard_charts_bloc_test.dart
```

Expected: FAIL with an unresolved-import / undefined-class compile error (`dashboard_charts_bloc.dart` doesn't exist yet).

- [ ] **Step 3: Implement the event part file**

Create `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_event.dart`:

```dart
part of 'dashboard_charts_bloc.dart';

@freezed
sealed class DashboardChartsEvent with _$DashboardChartsEvent {
  const factory DashboardChartsEvent.periodChanged(DashboardPeriod period) =
      DashboardPeriodChanged;

  const factory DashboardChartsEvent.viewChanged(DashboardChartView view) =
      DashboardViewChanged;

  const factory DashboardChartsEvent.periodStepped(int direction) =
      DashboardPeriodStepped;
}
```

- [ ] **Step 4: Implement the state part file**

Create `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_state.dart`:

```dart
part of 'dashboard_charts_bloc.dart';

@freezed
class DashboardChartsState with _$DashboardChartsState {
  const factory DashboardChartsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    @Default(DashboardChartView.donut) DashboardChartView view,
  }) = _DashboardChartsState;
}
```

- [ ] **Step 5: Implement the bloc**

Create `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

part 'dashboard_charts_event.dart';
part 'dashboard_charts_state.dart';
part 'dashboard_charts_bloc.freezed.dart';

enum DashboardChartView { donut, bar }

class DashboardChartsBloc extends Bloc<DashboardChartsEvent, DashboardChartsState> {
  final Clock _clock;

  DashboardChartsBloc({Clock? clock})
      : _clock = clock ?? SystemClock(),
        super(
          DashboardChartsState(
            period: DashboardPeriod.week,
            anchorDate: _truncate(
              (clock ?? SystemClock()).now(),
              DashboardPeriod.week,
            ),
          ),
        ) {
    on<DashboardPeriodChanged>(_onPeriodChanged);
    on<DashboardViewChanged>(_onViewChanged);
    on<DashboardPeriodStepped>(_onPeriodStepped);
  }

  void _onPeriodChanged(
    DashboardPeriodChanged event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(
      period: event.period,
      anchorDate: _truncate(_clock.now(), event.period),
    ));
  }

  void _onViewChanged(
    DashboardViewChanged event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(view: event.view));
  }

  void _onPeriodStepped(
    DashboardPeriodStepped event,
    Emitter<DashboardChartsState> emit,
  ) {
    emit(state.copyWith(
      anchorDate: _stepAnchor(state.period, state.anchorDate, event.direction),
    ));
  }

  static DateTime _truncate(DateTime date, DashboardPeriod period) {
    return period == DashboardPeriod.month
        ? DateTime(date.year, date.month, 1)
        : DateTime(date.year, date.month, date.day);
  }

  static DateTime _stepAnchor(DashboardPeriod period, DateTime anchor, int direction) {
    switch (period) {
      case DashboardPeriod.today:
        return anchor.add(Duration(days: direction));
      case DashboardPeriod.week:
        return anchor.add(Duration(days: 7 * direction));
      case DashboardPeriod.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
    }
  }
}
```

- [ ] **Step 6: Generate freezed code**

From `apps/worklog_studio`:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: build succeeds, `lib/feature/home/bloc/dashboard_charts_bloc.freezed.dart` is created.

- [ ] **Step 7: Run the test to verify it passes**

```bash
fvm flutter test test/feature/home/dashboard_charts_bloc_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add apps/worklog_studio/lib/feature/home/bloc/ apps/worklog_studio/test/feature/home/dashboard_charts_bloc_test.dart
git commit -m "feat: add DashboardChartsBloc for chart period/view selection"
```

---

### Task 4: Dashboard charts widget — header, donut pair, bar chart, section

**Files:**
- Create: `apps/worklog_studio/lib/feature/home/presentation/components/dashboard_charts_section.dart`
- Test: `apps/worklog_studio/test/feature/home/dashboard_charts_section_test.dart`

**Interfaces:**
- Consumes:
  - `DashboardChartsBloc`, `DashboardChartsEvent`, `DashboardChartsState`, `DashboardChartView` (Task 3)
  - `DashboardChartAggregator`, `DashboardPeriod`, `DashboardChartData`, `DashboardSlice`, `DashboardBucket` (Task 2)
  - `EntityResolver.getResolvedTimeEntries()` (`apps/worklog_studio/lib/state/entity_resolver.dart`)
  - `BadgeUtils.getBadgeColor(String id)` (`apps/worklog_studio/lib/feature/common/utils/badge_utils.dart`)
  - `Select<T>`, `SelectOption<T>`, `SegmentedToggle<T>`, `SegmentedToggleOption<T>`, `BaseCard`, `ColorsPalette` from `worklog_studio_style_system`
- Produces (consumed by Task 5): a single public widget `DashboardChartsSection` (no constructor params) to be placed in `home_page.dart`.

- [ ] **Step 1: Write the widget smoke test**

Create `apps/worklog_studio/test/feature/home/dashboard_charts_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/core/services/idle_monitor/idle_monitor.dart';
import 'package:worklog_studio/core/services/time_tracker_service.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/feature/home/presentation/components/dashboard_charts_section.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio/state/project_task_state.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../../helpers/test_fakes.dart';

class _FakeProjectRepository implements ProjectRepository {
  final List<Project> _store;
  _FakeProjectRepository(this._store);
  @override
  Future<List<Project>> getAll() async => _store;
  @override
  Future<Project?> getById(String id) async =>
      _store.where((p) => p.id == id).firstOrNull;
  @override
  Future<void> insert(Project project) async => _store.add(project);
  @override
  Future<void> update(Project project) async {}
  @override
  Future<void> delete(String id) async {}
}

class _FakeTaskRepository implements TaskRepository {
  final List<Task> _store;
  _FakeTaskRepository(this._store);
  @override
  Future<List<Task>> getAll() async => _store;
  @override
  Future<List<Task>> getByProjectId(String projectId) async =>
      _store.where((t) => t.projectId == projectId).toList();
  @override
  Future<Task?> getById(String id) async =>
      _store.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> insert(Task task) async => _store.add(task);
  @override
  Future<void> update(Task task) async {}
  @override
  Future<void> delete(String id) async {}
}

Widget _wrap(Widget child, {required TimeTrackerBloc bloc, required ProjectTaskState state}) {
  return MultiProvider(
    providers: [
      BlocProvider<TimeTrackerBloc>.value(value: bloc),
      ChangeNotifierProvider<ProjectTaskState>.value(value: state),
      ChangeNotifierProvider<EntityResolver>(
        create: (_) => EntityResolver(bloc: bloc, projectTaskState: state),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows empty state when there are no time entries', (tester) async {
    final repository = FakeTimeEntryRepository();
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([]),
      taskRepository: _FakeTaskRepository([]),
      clock: SystemClock(),
    );

    await tester.pumpWidget(
      _wrap(const DashboardChartsSection(), bloc: bloc, state: projectState),
    );
    await tester.pumpAndSettle();

    expect(find.text('No time logged for this period.'), findsOneWidget);
  });

  testWidgets('switching to bar view renders a BarChart instead of donuts', (tester) async {
    final repository = FakeTimeEntryRepository();
    final now = DateTime.now();
    repository.seed(TimeEntry(
      id: 'e1',
      projectId: 'p1',
      taskId: 't1',
      startAt: now.subtract(const Duration(hours: 1)),
      endAt: now,
      status: TimeEntryStatus.stopped,
    ));
    final bloc = TimeTrackerBloc(
      service: TimeTrackerService(repository: repository, clock: SystemClock()),
      idleMonitor: null,
    )..add(const TimeTrackerEvent.loaded());
    final projectState = ProjectTaskState(
      projectRepository: _FakeProjectRepository([
        Project(id: 'p1', name: 'Project p1', description: '', createdAt: now),
      ]),
      taskRepository: _FakeTaskRepository([
        Task(
          id: 't1',
          projectId: 'p1',
          title: 'Task t1',
          description: '',
          status: TaskStatus.open,
          createdAt: now,
        ),
      ]),
      clock: SystemClock(),
    );

    await tester.pumpWidget(
      _wrap(const DashboardChartsSection(), bloc: bloc, state: projectState),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.donut_large_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pumpAndSettle();

    expect(find.text('No time logged for this period.'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
fvm flutter test test/feature/home/dashboard_charts_section_test.dart
```

Expected: FAIL — `dashboard_charts_section.dart` doesn't exist yet (unresolved import / undefined `DashboardChartsSection`).

- [ ] **Step 3: Implement the widget file**

Create `apps/worklog_studio/lib/feature/home/presentation/components/dashboard_charts_section.dart`:

```dart
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/home/bloc/dashboard_charts_bloc.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _chartsWideBreakpoint = 900;

class DashboardChartsSection extends StatelessWidget {
  const DashboardChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardChartsBloc>(
      create: (_) => DashboardChartsBloc(),
      child: const _DashboardChartsSectionBody(),
    );
  }
}

class _DashboardChartsSectionBody extends StatelessWidget {
  const _DashboardChartsSectionBody();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return BlocBuilder<DashboardChartsBloc, DashboardChartsState>(
      builder: (context, chartsState) {
        return Selector<EntityResolver, List<ResolvedTimeEntry>>(
          selector: (context, resolver) => resolver.getResolvedTimeEntries(),
          shouldRebuild: (prev, next) => !const ListEquality().equals(prev, next),
          builder: (context, entries, child) {
            final data = DashboardChartAggregator.aggregate(
              entries: entries,
              period: chartsState.period,
              anchorDate: chartsState.anchorDate,
              now: DateTime.now(),
            );
            final isEmpty = data.byProject.isEmpty && data.byTask.isEmpty;

            return BaseCard(
              padding: EdgeInsets.all(theme.spacings.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChartsHeader(state: chartsState, rangeLabel: data.rangeLabel),
                  SizedBox(height: theme.spacings.lg),
                  if (isEmpty)
                    const _EmptyChartsState()
                  else if (chartsState.view == DashboardChartView.donut)
                    _DonutPair(data: data)
                  else
                    _BarChart(data: data),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChartsHeader extends StatelessWidget {
  final DashboardChartsState state;
  final String rangeLabel;

  const _ChartsHeader({required this.state, required this.rangeLabel});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final bloc = context.read<DashboardChartsBloc>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _chartsWideBreakpoint;

        final periodControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Select<DashboardPeriod>(
              value: state.period,
              minWidth: 110,
              options: const [
                SelectOption(value: DashboardPeriod.today, label: 'Today'),
                SelectOption(value: DashboardPeriod.week, label: 'Week'),
                SelectOption(value: DashboardPeriod.month, label: 'Month'),
              ],
              onChanged: (value) {
                if (value != null) {
                  bloc.add(DashboardChartsEvent.periodChanged(value));
                }
              },
            ),
            SizedBox(width: theme.spacings.sm),
            _StepperButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => bloc.add(const DashboardChartsEvent.periodStepped(-1)),
            ),
            SizedBox(width: theme.spacings.xxs),
            Text(
              rangeLabel,
              style: theme.commonTextStyles.body2.copyWith(color: palette.text.secondary),
            ),
            SizedBox(width: theme.spacings.xxs),
            _StepperButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => bloc.add(const DashboardChartsEvent.periodStepped(1)),
            ),
          ],
        );

        final viewToggle = SegmentedToggle<DashboardChartView>(
          value: state.view,
          options: const [
            SegmentedToggleOption(
              value: DashboardChartView.donut,
              icon: Icons.donut_large_rounded,
            ),
            SegmentedToggleOption(
              value: DashboardChartView.bar,
              icon: Icons.bar_chart_rounded,
            ),
          ],
          onChanged: (value) => bloc.add(DashboardChartsEvent.viewChanged(value)),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [periodControls, viewToggle],
          );
        }

        return Wrap(
          spacing: theme.spacings.sm,
          runSpacing: theme.spacings.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [periodControls, viewToggle],
        );
      },
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        onTap: onTap,
        borderRadius: theme.radiuses.sm.circular,
        child: Padding(
          padding: EdgeInsets.all(theme.spacings.xxs),
          child: Icon(icon, size: 18, color: palette.text.secondary),
        ),
      ),
    );
  }
}

class _DonutPair extends StatelessWidget {
  final DashboardChartData data;

  const _DonutPair({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _chartsWideBreakpoint;
        final projectDonut = _Donut(title: 'Project', slices: data.byProject);
        final taskDonut = _Donut(title: 'Task', slices: data.byTask);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: projectDonut),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: taskDonut),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            projectDonut,
            SizedBox(height: theme.spacings.x2l),
            taskDonut,
          ],
        );
      },
    );
  }
}

class _Donut extends StatelessWidget {
  final String title;
  final List<DashboardSlice> slices;

  const _Donut({required this.title, required this.slices});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.commonTextStyles.labelMedium.copyWith(color: palette.text.secondary),
        ),
        SizedBox(height: theme.spacings.md),
        if (slices.isEmpty)
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'No time logged for this period.',
                style: theme.commonTextStyles.body2.copyWith(color: palette.text.muted),
              ),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sections: slices.map((slice) {
                      return PieChartSectionData(
                        value: slice.duration.inMinutes.toDouble(),
                        color: _colorFor(slice, palette),
                        showTitle: false,
                        radius: 28,
                      );
                    }).toList(),
                    centerSpaceRadius: 42,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              SizedBox(width: theme.spacings.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: slices.map((slice) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _colorFor(slice, palette),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: theme.spacings.sm),
                          Expanded(
                            child: Text(
                              slice.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.commonTextStyles.caption.copyWith(
                                color: palette.text.primary,
                              ),
                            ),
                          ),
                          Text(
                            '${_formatHours(slice.duration)} '
                            '(${(slice.percentOfTotal * 100).round()}%)',
                            style: theme.commonTextStyles.caption.copyWith(
                              color: palette.text.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Color _colorFor(DashboardSlice slice, ColorsPalette palette) {
    if (slice.id.isEmpty) return palette.text.muted;
    return BadgeUtils.getBadgeColor(slice.id).$1;
  }

  String _formatHours(Duration duration) {
    final hours = duration.inMinutes / 60;
    return '${hours.toStringAsFixed(1)}h';
  }
}

class _BarChart extends StatelessWidget {
  final DashboardChartData data;

  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final maxHours = data.bars
        .map((b) => b.duration.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final chartMaxY = maxHours <= 0 ? 1.0 : maxHours * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: theme.spacings.xs),
                    child: Text(
                      data.bars[index].label,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: data.bars.asMap().entries.map((entry) {
            final hours = entry.value.duration.inMinutes / 60;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: palette.accent.primary,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyChartsState extends StatelessWidget {
  const _EmptyChartsState();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'No time logged for this period.',
          style: theme.commonTextStyles.body.copyWith(color: palette.text.muted),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
fvm flutter test test/feature/home/dashboard_charts_section_test.dart
```

Expected: `All tests passed!`. If `fl_chart`'s `SideTitleWidget`/`AxisTitles`/`getTitlesWidget` signature differs from what's shown here for the version resolved in Task 1, fix the call sites to match the installed version's API (check `.dart_tool/package_config.json` or run `fvm flutter pub deps` to see the resolved `fl_chart` version, then cross-reference its pub.dev documentation) — the chart *behavior* (bottom labels from `data.bars[i].label`, bar height from hours) must stay the same.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/home/presentation/components/dashboard_charts_section.dart apps/worklog_studio/test/feature/home/dashboard_charts_section_test.dart
git commit -m "feat: add DashboardChartsSection widget (donut + bar chart views)"
```

---

### Task 5: Wire `DashboardChartsSection` into the Dashboard, remove the old cards

**Files:**
- Modify: `apps/worklog_studio/lib/feature/home/presentation/home_page.dart`
- Modify: `apps/worklog_studio/lib/feature/app/layout/app_shell.dart:128-135`

**Interfaces:**
- Consumes: `DashboardChartsSection` (Task 4).

- [ ] **Step 1: Replace `HomePage`'s build method and remove the old card classes**

In `apps/worklog_studio/lib/feature/home/presentation/home_page.dart`, replace lines 1-105 (everything from the imports through the end of `_HomePageState.build`) with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/presentation/components/live_duration_text.dart';
import 'package:worklog_studio/feature/common/utils/date_format_utils.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/history/presentation/components/time_entry_actions_cell.dart';
import 'package:worklog_studio/feature/home/presentation/components/dashboard_charts_section.dart';
import 'package:worklog_studio/state/entity_resolver.dart';

const double _recentActivityWideBreakpoint = 700;

class HomePage extends StatefulWidget {
  final String title;
  final VoidCallback onViewAllHistory;
  final ValueChanged<String> onSelectHistoryEntry;
  final VoidCallback onAddTimeEntry;

  const HomePage({
    super.key,
    required this.title,
    required this.onViewAllHistory,
    required this.onSelectHistoryEntry,
    required this.onAddTimeEntry,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(onAddTimeEntry: widget.onAddTimeEntry),
          SizedBox(height: theme.spacings.lg),
          const DashboardChartsSection(),
          SizedBox(height: theme.spacings.lg),
          _RecentActivitySection(
            onViewAll: widget.onViewAllHistory,
            onSelectEntry: widget.onSelectHistoryEntry,
          ),
        ],
      ),
    );
  }
}
```

Note: `onViewAllTasks` and `onSelectTask` are removed from `HomePage`'s constructor — they existed only to support the now-deleted `_TopTasksPreviewCard`, and nothing else on the page used them.

- [ ] **Step 2: Delete the old card classes**

In the same file, delete everything from `class _DailyFocusCard` through the end of `class _CompactTaskRow` (originally lines 131-429 — the classes `_DailyFocusCard`, the top-level `_formatDuration` helper, `_WeeklyTotalsCard`, `_TopTasksPreviewCard`, and `_CompactTaskRow`). Keep `class _DashboardHeader` (originally lines 107-129) and everything from `class _RecentActivitySection` onward (originally line 431 to the end of the file) untouched.

- [ ] **Step 3: Update the `HomePage(...)` call site in `app_shell.dart`**

In `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`, find:

```dart
        return HomePage(
          title: 'Dashboard',
          onViewAllTasks: () => _onRouteSelected(AppRoute.tasks),
          onViewAllHistory: () => _onRouteSelected(AppRoute.history),
          onSelectHistoryEntry: _openHistoryEntry,
          onAddTimeEntry: _openHistoryCreateEntry,
          onSelectTask: _openTask,
        );
```

Replace it with:

```dart
        return HomePage(
          title: 'Dashboard',
          onViewAllHistory: () => _onRouteSelected(AppRoute.history),
          onSelectHistoryEntry: _openHistoryEntry,
          onAddTimeEntry: _openHistoryCreateEntry,
        );
```

(`_openTask` remains defined and used elsewhere in this file — only this one call site is changed.)

- [ ] **Step 4: Run static analysis on the changed files**

From `apps/worklog_studio`:

```bash
fvm flutter analyze lib/feature/home/presentation/home_page.dart lib/feature/app/layout/app_shell.dart
```

Expected: no new errors related to this change (any pre-existing warnings unrelated to `HomePage`/`app_shell.dart`'s Dashboard route are out of scope).

- [ ] **Step 5: Run the full test suite**

From `apps/worklog_studio`:

```bash
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/worklog_studio/lib/feature/home/presentation/home_page.dart apps/worklog_studio/lib/feature/app/layout/app_shell.dart
git commit -m "feat: replace dashboard stat cards with chart section"
```

---

## Self-Review Notes

- **Spec coverage:** placement (Task 5), donut grouping by Project+Task side-by-side (Task 4 `_DonutPair`), period set Today/Week/Month default Week (Task 3 default state), prev/next stepping (Task 3 `periodStepped` + Task 4 `_StepperButton`), month-as-weekly-columns (Task 2 `_monthlyBuckets`), Today-as-hourly-bars (Task 2 `_hourlyBuckets`), fl_chart dependency (Task 1), thin-bloc + pure-aggregator architecture (Tasks 2 & 3), responsive narrow-layout stacking (Task 4 `_chartsWideBreakpoint` in both `_ChartsHeader` and `_DonutPair`), empty state (Task 4 `_EmptyChartsState`) — all covered.
- **Placeholder scan:** none found; the one deliberately-flagged uncertainty (Task 4 Step 4, `fl_chart` API drift across versions) is a concrete fallback instruction, not a placeholder.
- **Type consistency:** `DashboardPeriod` defined once in Task 2, imported everywhere else; `DashboardChartView` defined once in Task 3; `DashboardChartsBloc`/`DashboardChartsEvent`/`DashboardChartsState` names match between Task 3's implementation and Task 4/5's usage; `DashboardChartsSection` (Task 4) is the exact name wired into `home_page.dart` (Task 5).
