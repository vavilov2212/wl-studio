# Reports Charts Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Reports page charts block as a Dashboard-style card: total hours + Project and Task donuts, plus a stacked-by-project bar chart view with a hover legend overlay, toggled via SegmentedToggle.

**Architecture:** Pure aggregation additions in `ReportsAggregator` (byTask slices, stacked bar buckets), a `view` field in `ReportsBloc` (freezed file hand-edited, build_runner is broken), and a rewritten `ReportsSummaryPanel` wrapped in `BaseCard`. The `DashboardChartView` enum moves to the shared aggregator file; the Dashboard's `_chartScale` axis math is extracted to a shared util. Period controls stay at page level (they drive the table too).

**Tech Stack:** Flutter (Windows desktop), fl_chart, flutter_bloc + freezed (hand-written codegen), Melos monorepo, fvm.

**Spec:** `docs/superpowers/specs/2026-07-15-reports-charts-block-design.md`

## Global Constraints

- Run all commands via `fvm`; tests from `apps\worklog_studio\`: `fvm flutter test test/core/ test/feature/ --reporter expanded`.
- build_runner is BROKEN (POST_MORTEM 3.1): edit `.freezed.dart` files by hand, mirroring `dashboard_charts_bloc.freezed.dart` patterns.
- Absolute `package:worklog_studio/...` imports only; never import a package sub-path (barrel only); never name `ColorsPalette` explicitly in app code (POST_MORTEM 3.18) - use inline ternaries.
- No hardcoded colors/paddings in `apps\`: use `theme.colorsPalette.*` / `theme.spacings.*`. fl_chart geometry literals (180/40/45/2/220/32/8/140/200) are the accepted exception (POST_MORTEM 4.2).
- Every new user-visible string gets `// TODO: l10n`.
- No em/en dashes anywhere (code, comments, commit messages) - plain hyphen only. No AI-attribution trailers in commits.
- No italic text in UI.
- TDD: red -> green per task; UI-only widget code is exempt from unit tests but must pass `fvm flutter analyze`.
- Commit per completed task.

---

### Task 1: Move DashboardChartView enum to the shared aggregator file

**Files:**
- Modify: `apps\worklog_studio\lib\feature\home\dashboard_chart_aggregator.dart` (add enum after `DashboardPeriod`)
- Modify: `apps\worklog_studio\lib\feature\home\bloc\dashboard_charts_bloc.dart:11` (remove enum)

**Interfaces:**
- Produces: `enum DashboardChartView { donut, bar }` importable from `package:worklog_studio/feature/home/dashboard_chart_aggregator.dart`. Tasks 5 and 6 import it from there.

Reports already imports `dashboard_chart_aggregator.dart` for `DashboardPeriod`; moving the enum there follows the "shared enum moves to a shared file" rule instead of importing another feature's bloc. All current users already import the aggregator file (`dashboard_charts_section.dart` directly; the bloc part-files through `dashboard_charts_bloc.dart`; `test\feature\home\dashboard_charts_bloc_test.dart` imports both) - zero import changes needed.

- [ ] **Step 1: Add the enum to the aggregator file**

In `apps\worklog_studio\lib\feature\home\dashboard_chart_aggregator.dart`, directly under `enum DashboardPeriod { today, week, month, custom }` add:

```dart
enum DashboardChartView { donut, bar }
```

- [ ] **Step 2: Remove the enum from the bloc file**

In `apps\worklog_studio\lib\feature\home\bloc\dashboard_charts_bloc.dart` delete the line:

```dart
enum DashboardChartView { donut, bar }
```

- [ ] **Step 3: Verify nothing else declared or lost it**

Run from repo root: `grep -rn "enum DashboardChartView" apps/worklog_studio/lib`
Expected: exactly one hit, in `dashboard_chart_aggregator.dart`.

- [ ] **Step 4: Analyze and run the home tests**

From `apps\worklog_studio\`:
Run: `fvm flutter analyze lib\feature\home`
Expected: No issues found.
Run: `fvm flutter test test/feature/home/ --reporter expanded`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/home/dashboard_chart_aggregator.dart apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.dart
git commit -m "refactor(home): move DashboardChartView enum to dashboard_chart_aggregator"
```

---

### Task 2: Extract chartScale axis math into a shared util (TDD)

**Files:**
- Create: `apps\worklog_studio\lib\feature\common\utils\chart_scale.dart`
- Create: `apps\worklog_studio\test\core\chart_scale_test.dart`
- Modify: `apps\worklog_studio\lib\feature\home\presentation\components\dashboard_charts_section.dart:459-472` (delete private `_chartScale` + its comment, import the util, rename call)

**Interfaces:**
- Produces: `({double interval, double maxY}) chartScale(double maxHours)` in `package:worklog_studio/feature/common/utils/chart_scale.dart`. Task 6 consumes it.

- [ ] **Step 1: Write the failing test**

Create `apps\worklog_studio\test\core\chart_scale_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';

void main() {
  group('chartScale', () {
    test('zero or negative maxHours -> default 1h interval, 4h maxY', () {
      expect(chartScale(0), equals((interval: 1.0, maxY: 4.0)));
      expect(chartScale(-3), equals((interval: 1.0, maxY: 4.0)));
    });

    test('2h max -> 0.5h interval, top gridline one step above (2.5h)', () {
      expect(chartScale(2), equals((interval: 0.5, maxY: 2.5)));
    });

    test('7.5h max -> 2h interval, maxY 10h', () {
      expect(chartScale(7.5), equals((interval: 2.0, maxY: 10.0)));
    });

    test('beyond the step table (60h) -> fallback interval 15h, maxY 75h', () {
      expect(chartScale(60), equals((interval: 15.0, maxY: 75.0)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

From `apps\worklog_studio\`:
Run: `fvm flutter test test/core/chart_scale_test.dart --reporter expanded`
Expected: FAIL to compile - `chart_scale.dart` does not exist.

- [ ] **Step 3: Write the implementation (verbatim move from dashboard_charts_section.dart)**

Create `apps\worklog_studio\lib\feature\common\utils\chart_scale.dart`:

```dart
// Returns interval and chartMaxY as a clean pair.
// chartMaxY is always (numSteps+1)*interval so the top gridline is a round
// number one step above the tallest bar - no floating 7.2h or 0.6h labels.
({double interval, double maxY}) chartScale(double maxHours) {
  const steps = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0];
  if (maxHours <= 0) return (interval: 1.0, maxY: 4.0);
  final raw = maxHours / 4;
  final interval =
      steps.firstWhere((v) => v >= raw, orElse: () => (raw / 5).ceil() * 5.0);
  final numSteps = (maxHours / interval).ceil() + 1;
  return (interval: interval, maxY: interval * numSteps);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/core/chart_scale_test.dart --reporter expanded`
Expected: 4 tests PASS.

- [ ] **Step 5: Switch the Dashboard to the shared util**

In `apps\worklog_studio\lib\feature\home\presentation\components\dashboard_charts_section.dart`:
1. Add import (keep alphabetical order among `worklog_studio` imports):
```dart
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';
```
2. Delete the private function and its comment block (the lines starting `// Returns interval and chartMaxY as a clean pair.` through the closing `}` of `_chartScale`, currently lines 462-472; keep the `_kLeftReservedSize` constant above them).
3. In `_BarChartState.build` replace `final scale = _chartScale(maxHours);` with `final scale = chartScale(maxHours);`.

- [ ] **Step 6: Analyze and run full suite**

Run: `fvm flutter analyze lib\feature\home lib\feature\common\utils`
Expected: No issues found.
Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: all PASS (295 existing + 4 new).

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/feature/common/utils/chart_scale.dart apps/worklog_studio/test/core/chart_scale_test.dart apps/worklog_studio/lib/feature/home/presentation/components/dashboard_charts_section.dart
git commit -m "refactor(common): extract chartScale axis math into shared util"
```

---

### Task 3: ReportsAggregator - flat byTask slices (TDD)

**Files:**
- Modify: `apps\worklog_studio\lib\feature\reports\reports_aggregator.dart`
- Test: `apps\worklog_studio\test\core\reports_aggregator_test.dart`

**Interfaces:**
- Consumes: existing `ReportSlice`, `ReportsData`, `ReportsAggregator.aggregate(...)`.
- Produces: `ReportsData.byTask` (`List<ReportSlice>`, id '' = Unassigned sentinel, sorted duration desc with sentinel last). Task 6 consumes it.

- [ ] **Step 1: Write the failing tests**

Append a new group inside `main()` of `apps\worklog_studio\test\core\reports_aggregator_test.dart` (reuses the file's `_makeEntry`, `weekAnchor`, `now`):

```dart
  group('ReportsAggregator.aggregate byTask', () {
    test('flat task slices across projects, sorted desc, Unassigned last', () {
      final entries = [
        _makeEntry(
          id: 'e1',
          start: DateTime(2026, 7, 7, 9),
          end: DateTime(2026, 7, 7, 10),
          projectId: 'p1',
          projectName: 'Alpha',
          taskId: 't1',
          taskName: 'Design',
        ),
        _makeEntry(
          id: 'e2',
          start: DateTime(2026, 7, 7, 10),
          end: DateTime(2026, 7, 7, 13),
          projectId: 'p2',
          projectName: 'Beta',
          taskId: 't2',
          taskName: 'Build',
        ),
        _makeEntry(
          id: 'e3',
          start: DateTime(2026, 7, 8, 9),
          end: DateTime(2026, 7, 8, 10),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
      ];
      final data = ReportsAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.byTask.length, equals(3));
      expect(data.byTask[0].id, equals('t2'));
      expect(data.byTask[0].label, equals('Build'));
      expect(data.byTask[0].duration, equals(const Duration(hours: 3)));
      expect(data.byTask[0].percentOfTotal, closeTo(3 / 5, 0.001));
      expect(data.byTask[1].label, equals('Design'));
      expect(data.byTask.last.id, equals(''));
      expect(data.byTask.last.label, equals('Unassigned'));
    });

    test('empty entries -> empty byTask', () {
      final data = ReportsAggregator.aggregate(
        entries: [],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.byTask, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded`
Expected: FAIL to compile - `byTask` getter does not exist on `ReportsData`.

- [ ] **Step 3: Implement byTask**

In `apps\worklog_studio\lib\feature\reports\reports_aggregator.dart`:

1. Add the field to `ReportsData` (after `byProject`) and to its constructor:

```dart
class ReportsData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final Duration totalDuration;
  final List<ReportSlice> byProject;
  final List<ReportSlice> byTask;
  final List<ReportsProjectGroup> projectGroups;

  const ReportsData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.totalDuration,
    required this.byProject,
    required this.byTask,
    required this.projectGroups,
  });
}
```

2. In `aggregate()`, add flat accumulators next to the existing maps:

```dart
    final Map<String, Duration> flatTaskDurs = {};
    final Map<String, String> flatTaskNames = {};
```

and inside the existing `for (final e in inRange)` loop (after the `taskNames[pid]![tid] ??= tname;` line):

```dart
      flatTaskNames[tid] ??= tname;
      flatTaskDurs[tid] = (flatTaskDurs[tid] ?? Duration.zero) + dur;
```

3. After the `byProject` list is built, add:

```dart
    final byTask = flatTaskDurs.keys.map((tid) {
      final tDur = flatTaskDurs[tid]!;
      return ReportSlice(
        id: tid,
        label: flatTaskNames[tid]!,
        duration: tDur,
        percentOfTotal:
            totalMinutes == 0 ? 0.0 : tDur.inMinutes / totalMinutes,
      );
    }).toList()
      ..sort((a, b) {
        if (a.id.isEmpty) return 1;
        if (b.id.isEmpty) return -1;
        return b.duration.compareTo(a.duration);
      });
```

4. Pass `byTask: byTask,` in the returned `ReportsData(...)`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded`
Expected: all PASS (existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/reports_aggregator.dart apps/worklog_studio/test/core/reports_aggregator_test.dart
git commit -m "feat(reports): add flat byTask slices to ReportsAggregator"
```

---

### Task 4: ReportsAggregator - stacked per-project bar buckets (TDD)

**Files:**
- Modify: `apps\worklog_studio\lib\feature\reports\reports_aggregator.dart`
- Test: `apps\worklog_studio\test\core\reports_aggregator_test.dart`

**Interfaces:**
- Consumes: `ReportSlice`, the `byProject` list built inside `aggregate()` (defines segment order), `_Range`, `_dateOnly`.
- Produces (Task 6/7 consume these exact shapes):

```dart
class ReportsBarSegment {
  final String projectId;   // '' sentinel = No Project
  final String projectName;
  final Duration duration;
}

class ReportsBar {
  final String label;       // bucket label: '9 AM' / 'Mon 6' / 'Week 1'
  final Duration total;
  final List<ReportsBarSegment> segments; // only nonzero, in byProject order
}
```

and `ReportsData.bars` (`List<ReportsBar>`; empty for `DashboardPeriod.custom`).

Bucketing mirrors `DashboardChartAggregator._buildBuckets`: today -> hourly clipped to [minHour, maxHour] of entries; week -> 7 days; month -> calendar weeks; custom -> empty. Entries attribute to the bucket containing `startAt`.

- [ ] **Step 1: Write the failing tests**

Append a new group inside `main()` of `apps\worklog_studio\test\core\reports_aggregator_test.dart`:

```dart
  group('ReportsAggregator.aggregate bars', () {
    test('week period -> 7 day buckets with per-project stacked segments', () {
      final entries = [
        _makeEntry(
          id: 'e1',
          start: DateTime(2026, 7, 7, 9),
          end: DateTime(2026, 7, 7, 11),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
        _makeEntry(
          id: 'e2',
          start: DateTime(2026, 7, 7, 11),
          end: DateTime(2026, 7, 7, 12),
          projectId: 'p2',
          projectName: 'Beta',
        ),
        _makeEntry(
          id: 'e3',
          start: DateTime(2026, 7, 9, 9),
          end: DateTime(2026, 7, 9, 10),
        ),
      ];
      final data = ReportsAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.bars.length, equals(7));
      expect(data.bars[0].label, equals('Mon 6'));
      expect(data.bars[0].total, equals(Duration.zero));
      expect(data.bars[0].segments, isEmpty);
      // Tue Jul 7: Alpha 2h stacked before Beta 1h (byProject order).
      expect(data.bars[1].label, equals('Tue 7'));
      expect(data.bars[1].total, equals(const Duration(hours: 3)));
      expect(data.bars[1].segments.length, equals(2));
      expect(data.bars[1].segments[0].projectId, equals('p1'));
      expect(data.bars[1].segments[0].projectName, equals('Alpha'));
      expect(data.bars[1].segments[0].duration, equals(const Duration(hours: 2)));
      expect(data.bars[1].segments[1].projectId, equals('p2'));
      // Thu Jul 9: single No Project segment.
      expect(data.bars[3].segments.single.projectId, equals(''));
      expect(data.bars[3].segments.single.projectName, equals('No Project'));
    });

    test('today period -> hourly buckets clipped to hours with entries', () {
      final entries = [
        _makeEntry(
          id: 'e1',
          start: DateTime(2026, 7, 6, 9),
          end: DateTime(2026, 7, 6, 10),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
        _makeEntry(
          id: 'e2',
          start: DateTime(2026, 7, 6, 12),
          end: DateTime(2026, 7, 6, 13),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
      ];
      final data = ReportsAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.today,
        anchorDate: DateTime(2026, 7, 6),
        now: now,
      );
      expect(data.bars.length, equals(4)); // 9 AM .. 12 PM
      expect(data.bars.first.label, equals('9 AM'));
      expect(data.bars.last.label, equals('12 PM'));
      expect(data.bars[1].total, equals(Duration.zero));
      expect(data.bars.first.segments.single.duration,
          equals(const Duration(hours: 1)));
    });

    test('month period -> calendar week buckets', () {
      // July 2026 starts on Wednesday -> offset 2; 31 days -> 5 week buckets.
      final entries = [
        _makeEntry(
          id: 'e1',
          start: DateTime(2026, 7, 1, 9),
          end: DateTime(2026, 7, 1, 10),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
        _makeEntry(
          id: 'e2',
          start: DateTime(2026, 7, 31, 9),
          end: DateTime(2026, 7, 31, 11),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
      ];
      final data = ReportsAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.month,
        anchorDate: DateTime(2026, 7, 15),
        now: DateTime(2026, 7, 31, 23),
      );
      expect(data.bars.length, equals(5));
      expect(data.bars.first.label, equals('Week 1'));
      expect(data.bars.first.total, equals(const Duration(hours: 1)));
      expect(data.bars.last.label, equals('Week 5'));
      expect(data.bars.last.total, equals(const Duration(hours: 2)));
    });

    test('custom period -> no bars', () {
      final data = ReportsAggregator.aggregate(
        entries: [
          _makeEntry(
            id: 'e1',
            start: DateTime(2026, 7, 2, 9),
            end: DateTime(2026, 7, 2, 10),
            projectId: 'p1',
            projectName: 'Alpha',
          ),
        ],
        period: DashboardPeriod.custom,
        anchorDate: DateTime(2026, 7, 1),
        now: now,
        customRangeStart: DateTime(2026, 7, 1),
        customRangeEnd: DateTime(2026, 7, 3),
      );
      expect(data.bars, isEmpty);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded`
Expected: FAIL to compile - `bars` getter does not exist on `ReportsData`.

- [ ] **Step 3: Implement bars**

In `apps\worklog_studio\lib\feature\reports\reports_aggregator.dart`:

1. Add the two model classes after `ReportSlice`:

```dart
class ReportsBarSegment {
  final String projectId;
  final String projectName;
  final Duration duration;

  const ReportsBarSegment({
    required this.projectId,
    required this.projectName,
    required this.duration,
  });
}

class ReportsBar {
  final String label;
  final Duration total;
  final List<ReportsBarSegment> segments;

  const ReportsBar({
    required this.label,
    required this.total,
    required this.segments,
  });
}
```

2. Add `final List<ReportsBar> bars;` to `ReportsData` (after `byTask`) plus the `required this.bars,` constructor entry.

3. Add the weekday label table next to `_monthNames` in `ReportsAggregator`:

```dart
  // TODO: l10n
  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
```

4. In `aggregate()`, after `byTask` is built:

```dart
    final bars = _buildBars(period, range, inRange, now, byProject);
```

and pass `bars: bars,` in the returned `ReportsData(...)`.

5. Add the private helpers at the bottom of `ReportsAggregator` (bucketing mirrors `DashboardChartAggregator`; entries attribute to the bucket containing startAt):

```dart
  static List<ReportsBar> _buildBars(
    DashboardPeriod period,
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
    List<ReportSlice> byProject,
  ) {
    switch (period) {
      case DashboardPeriod.today:
        return _hourlyBars(inRange, now, byProject);
      case DashboardPeriod.week:
        return _dailyBars(range, inRange, now, byProject);
      case DashboardPeriod.month:
        return _weeklyBars(range, inRange, now, byProject);
      case DashboardPeriod.custom:
        // Custom ranges are donut-only in the UI (variable day counts don't
        // map to a fixed bucket layout) - bars are simply unused.
        return const [];
    }
  }

  static List<ReportsBar> _barsFromBuckets({
    required int bucketCount,
    required String Function(int index) labelOf,
    required int Function(ResolvedTimeEntry entry) bucketIndexOf,
    required List<ResolvedTimeEntry> inRange,
    required DateTime now,
    required List<ReportSlice> byProject,
  }) {
    final perBucket = List.generate(bucketCount, (_) => <String, Duration>{});
    for (final e in inRange) {
      final i = bucketIndexOf(e);
      if (i < 0 || i >= bucketCount) continue;
      final pid = e.projectId ?? '';
      perBucket[i][pid] = (perBucket[i][pid] ?? Duration.zero) + e.duration(now);
    }
    return List.generate(bucketCount, (i) {
      final durs = perBucket[i];
      final segments = byProject
          .where((p) => (durs[p.id] ?? Duration.zero) > Duration.zero)
          .map((p) => ReportsBarSegment(
                projectId: p.id,
                projectName: p.label,
                duration: durs[p.id]!,
              ))
          .toList();
      final total =
          segments.fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
      return ReportsBar(label: labelOf(i), total: total, segments: segments);
    });
  }

  static List<ReportsBar> _hourlyBars(
    List<ResolvedTimeEntry> inRange,
    DateTime now,
    List<ReportSlice> byProject,
  ) {
    if (inRange.isEmpty) return const [];
    final hours = inRange.map((e) => e.startAt.hour).toList();
    final minHour = hours.reduce((a, b) => a < b ? a : b);
    final maxHour = hours.reduce((a, b) => a > b ? a : b);
    return _barsFromBuckets(
      bucketCount: maxHour - minHour + 1,
      labelOf: (i) => _hourLabel(minHour + i),
      bucketIndexOf: (e) => e.startAt.hour - minHour,
      inRange: inRange,
      now: now,
      byProject: byProject,
    );
  }

  static String _hourLabel(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display $period';
  }

  static List<ReportsBar> _dailyBars(
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
    List<ReportSlice> byProject,
  ) {
    return _barsFromBuckets(
      bucketCount: 7,
      labelOf: (i) {
        final date = range.start.add(Duration(days: i));
        return '${_weekdayLabels[i]} ${date.day}';
      },
      bucketIndexOf: (e) =>
          _dateOnly(e.startAt).difference(range.start).inDays,
      inRange: inRange,
      now: now,
      byProject: byProject,
    );
  }

  static List<ReportsBar> _weeklyBars(
    _Range range,
    List<ResolvedTimeEntry> inRange,
    DateTime now,
    List<ReportSlice> byProject,
  ) {
    final monthStart = range.start;
    final firstWeekdayOffset = monthStart.weekday - 1;
    final daysInMonth = range.end.difference(monthStart).inDays;
    final weekCount = ((daysInMonth + firstWeekdayOffset - 1) ~/ 7) + 1;
    return _barsFromBuckets(
      bucketCount: weekCount,
      labelOf: (i) => 'Week ${i + 1}', // TODO: l10n
      bucketIndexOf: (e) =>
          (_dateOnly(e.startAt).difference(monthStart).inDays +
              firstWeekdayOffset) ~/
          7,
      inRange: inRange,
      now: now,
      byProject: byProject,
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/reports_aggregator.dart apps/worklog_studio/test/core/reports_aggregator_test.dart
git commit -m "feat(reports): add stacked per-project bar buckets to ReportsAggregator"
```

---

### Task 5: ReportsBloc - chart view state (TDD, hand-edited freezed)

**Files:**
- Modify: `apps\worklog_studio\lib\feature\reports\bloc\reports_state.dart`
- Modify: `apps\worklog_studio\lib\feature\reports\bloc\reports_event.dart`
- Modify: `apps\worklog_studio\lib\feature\reports\bloc\reports_bloc.dart`
- Modify: `apps\worklog_studio\lib\feature\reports\bloc\reports_bloc.freezed.dart` (hand edit)
- Test: `apps\worklog_studio\test\feature\reports\reports_bloc_test.dart`

**Interfaces:**
- Consumes: `DashboardChartView` from `package:worklog_studio/feature/home/dashboard_chart_aggregator.dart` (Task 1).
- Produces: `ReportsState.view` (`DashboardChartView`, defaults to `donut`) and event `ReportsViewChanged(DashboardChartView view)`. Task 6 consumes both.

- [ ] **Step 1: Write the failing tests**

Append inside the `group('ReportsBloc', ...)` of `apps\worklog_studio\test\feature\reports\reports_bloc_test.dart`:

```dart
    test('initial state: view is donut', () async {
      final bloc = ReportsBloc(clock: clock);
      expect(bloc.state.view, equals(DashboardChartView.donut));
      await bloc.close();
    });

    test('ReportsViewChanged(bar) -> view flips to bar', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsViewChanged(DashboardChartView.bar));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.view, equals(DashboardChartView.bar));
      await bloc.close();
    });

    test('view survives period change and stepping', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsViewChanged(DashboardChartView.bar));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodChanged(DashboardPeriod.month));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodStepped(-1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.view, equals(DashboardChartView.bar));
      await bloc.close();
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/feature/reports/reports_bloc_test.dart --reporter expanded`
Expected: FAIL to compile - `view` / `ReportsViewChanged` undefined.

- [ ] **Step 3: Update state, event, bloc**

`apps\worklog_studio\lib\feature\reports\bloc\reports_state.dart` - the factory becomes:

```dart
  const factory ReportsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    @Default(DashboardChartView.donut) DashboardChartView view,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) = _ReportsState;
```

`apps\worklog_studio\lib\feature\reports\bloc\reports_event.dart` - append:

```dart
class ReportsViewChanged extends ReportsEvent {
  final DashboardChartView view;
  ReportsViewChanged(this.view);
}
```

`apps\worklog_studio\lib\feature\reports\bloc\reports_bloc.dart` - register in the constructor body after the existing three:

```dart
    on<ReportsViewChanged>(_onViewChanged);
```

and add the handler after `_onCustomRangeSelected`:

```dart
  void _onViewChanged(
    ReportsViewChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(view: event.view));
  }
```

- [ ] **Step 4: Hand-edit reports_bloc.freezed.dart**

Mirror how `dashboard_charts_bloc.freezed.dart` threads its `view` field (same field, same default). Ten precise edits; `view` always goes between `anchorDate` and `customRangeStart`:

1. Mixin getters (line 18):
```dart
 DashboardPeriod get period; DateTime get anchorDate; DashboardChartView get view; DateTime? get customRangeStart; DateTime? get customRangeEnd;
```
2. Mixin `operator ==` - insert after the anchorDate clause:
```dart
&&(identical(other.view, view) || other.view == view)
```
3. Mixin `hashCode`:
```dart
int get hashCode => Object.hash(runtimeType,period,anchorDate,view,customRangeStart,customRangeEnd);
```
4. Mixin `toString`:
```dart
  return 'ReportsState(period: $period, anchorDate: $anchorDate, view: $view, customRangeStart: $customRangeStart, customRangeEnd: $customRangeEnd)';
```
5. `$ReportsStateCopyWith.call` signature:
```dart
 DashboardPeriod period, DateTime anchorDate, DashboardChartView view, DateTime? customRangeStart, DateTime? customRangeEnd
```
6. `_$ReportsStateCopyWithImpl.call` - add `Object? view = null,` after `Object? anchorDate = null,` in the parameter list, and add to the `_self.copyWith(...)` body after the anchorDate line:
```dart
view: null == view ? _self.view : view // ignore: cast_nullable_to_non_nullable
as DashboardChartView,
```
7. Patterns extension - in `maybeWhen`, `when`, and `whenOrNull`, each function type gains ` DashboardChartView view,` after ` DateTime anchorDate,`, and each `$default(...)` call gains `_that.view` after `_that.anchorDate` (three signatures + three call sites).
8. `_ReportsState` class - constructor and field:
```dart
  const _ReportsState({required this.period, required this.anchorDate, this.view = DashboardChartView.donut, this.customRangeStart, this.customRangeEnd}): super._();
```
```dart
@override@JsonKey() final  DashboardChartView view;
```
plus the same `==` clause, `hashCode` member list, and `toString` change as edits 2-4 (they appear a second time in this class).
9. `_$ReportsStateCopyWith.call` signature - same change as edit 5.
10. `__$ReportsStateCopyWithImpl.call` - same change as edit 6 (parameter + `_ReportsState(...)` body line).

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm flutter test test/feature/reports/reports_bloc_test.dart --reporter expanded`
Expected: all PASS (existing + 3 new).

- [ ] **Step 6: Analyze**

Run: `fvm flutter analyze lib\feature\reports`
Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/bloc/ apps/worklog_studio/test/feature/reports/reports_bloc_test.dart
git commit -m "feat(reports): add chart view state to ReportsBloc"
```

---

### Task 6: Charts card UI - donuts, toggle, static stacked bar, page wiring

**Files:**
- Rewrite: `apps\worklog_studio\lib\feature\reports\presentation\components\reports_summary_panel.dart`
- Modify: `apps\worklog_studio\lib\feature\reports\presentation\reports_page.dart:79` (panel call site)

**Interfaces:**
- Consumes: `ReportsData` (`byProject`, `byTask`, `bars`, `totalDuration`), `DashboardChartView`, `DashboardPeriod`, `ReportsViewChanged`, `chartScale`, `BaseCard`, `SegmentedToggle`, `BadgeUtils.getBadgeColor`, `DateFormatter.formatDurationHm`.
- Produces: `ReportsSummaryPanel({required ReportsData data, required DashboardChartView view, required DashboardPeriod period, required ValueChanged<DashboardChartView> onViewChanged})`. Task 7 replaces only the private `_ReportsStackedBarChart` widget inside this file.

UI-only task: no unit tests (TDD exemption), verified by analyze + full suite.

- [ ] **Step 1: Rewrite the panel**

Replace the entire content of `apps\worklog_studio\lib\feature\reports\presentation\components\reports_summary_panel.dart` with:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

const double _wideBreakpoint = 900;

String _formatHours(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}h';
}

class ReportsSummaryPanel extends StatelessWidget {
  final ReportsData data;
  final DashboardChartView view;
  final DashboardPeriod period;
  final ValueChanged<DashboardChartView> onViewChanged;

  const ReportsSummaryPanel({
    super.key,
    required this.data,
    required this.view,
    required this.period,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Custom ranges have no bar buckets - force donut and hide the toggle.
    final isCustom = period == DashboardPeriod.custom;
    final effectiveView = isCustom ? DashboardChartView.donut : view;

    return BaseCard(
      padding: EdgeInsets.all(theme.spacings.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: effectiveView == DashboardChartView.donut
                ? _DonutContent(data: data)
                : _BarContent(data: data),
          ),
          if (!isCustom) ...[
            SizedBox(width: theme.spacings.sm),
            SegmentedToggle<DashboardChartView>(
              value: effectiveView,
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
              onChanged: onViewChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalColumn extends StatelessWidget {
  final Duration total;

  const _TotalColumn({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Total hours', // TODO: l10n
          style: theme.commonTextStyles.caption.copyWith(
            color: palette.text.secondary,
          ),
        ),
        SizedBox(height: theme.spacings.xxs),
        Text(
          DateFormatter.formatDurationHm(total),
          style: theme.commonTextStyles.displayLarge.copyWith(
            color: palette.text.primary,
          ),
        ),
      ],
    );
  }
}

class _DonutContent extends StatelessWidget {
  final ReportsData data;

  const _DonutContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        final projectDonut = _Donut(title: 'Project', slices: data.byProject); // TODO: l10n
        final taskDonut = _Donut(title: 'Task', slices: data.byTask); // TODO: l10n

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TotalColumn(total: data.totalDuration),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: projectDonut),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: taskDonut),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalColumn(total: data.totalDuration),
            SizedBox(height: theme.spacings.lg),
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
  final List<ReportSlice> slices;

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
          style: theme.commonTextStyles.labelMedium.copyWith(
            color: palette.text.secondary,
          ),
        ),
        SizedBox(height: theme.spacings.md),
        if (slices.isEmpty)
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'No time logged for this period.', // TODO: l10n
                style: theme.commonTextStyles.body2.copyWith(
                  color: palette.text.muted,
                ),
              ),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: PieChart(
                  PieChartData(
                    sections: slices.map((slice) {
                      return PieChartSectionData(
                        value: slice.duration.inMinutes.toDouble(),
                        color: slice.id.isEmpty
                            ? palette.text.muted
                            : BadgeUtils.getBadgeColor(slice.id).$2,
                        showTitle: false,
                        radius: 40,
                      );
                    }).toList(),
                    centerSpaceRadius: 45,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              SizedBox(width: theme.spacings.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: slices.map((slice) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: slice.id.isEmpty
                                ? palette.text.muted
                                : BadgeUtils.getBadgeColor(slice.id).$2,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: theme.spacings.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            slice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.commonTextStyles.caption.copyWith(
                              color: palette.text.primary,
                            ),
                          ),
                        ),
                        SizedBox(width: theme.spacings.sm),
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
            ],
          ),
      ],
    );
  }
}

class _BarContent extends StatelessWidget {
  final ReportsData data;

  const _BarContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _TotalColumn(total: data.totalDuration),
              SizedBox(width: theme.spacings.x2l),
              Expanded(child: _ReportsStackedBarChart(bars: data.bars)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalColumn(total: data.totalDuration),
            SizedBox(height: theme.spacings.lg),
            _ReportsStackedBarChart(bars: data.bars),
          ],
        );
      },
    );
  }
}

class _ReportsStackedBarChart extends StatelessWidget {
  final List<ReportsBar> bars;

  const _ReportsStackedBarChart({required this.bars});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final maxHours = bars
        .map((b) => b.total.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final scale = chartScale(maxHours);

    return SizedBox(
      height: 220,
      child: BarChart(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        BarChartData(
          maxY: scale.maxY,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: scale.interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: palette.border.primary.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: scale.interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  final label = value % 1 == 0
                      ? '${value.toInt()}h'
                      : '${value.toStringAsFixed(1)}h';
                  return Text(
                    label,
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= bars.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: theme.spacings.xs),
                    child: Text(
                      bars[index].label,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: bars.asMap().entries.map((entry) {
            final index = entry.key;
            final bar = entry.value;
            final items = <BarChartRodStackItem>[];
            var from = 0.0;
            for (final seg in bar.segments) {
              final to = from + seg.duration.inMinutes / 60;
              items.add(BarChartRodStackItem(
                from,
                to,
                seg.projectId.isEmpty
                    ? palette.text.muted
                    : BadgeUtils.getBadgeColor(seg.projectId).$2,
              ));
              from = to;
            }
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: from,
                  width: 32,
                  borderRadius: BorderRadius.circular(4),
                  rodStackItems: items,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Wire the page**

In `apps\worklog_studio\lib\feature\reports\presentation\reports_page.dart`, replace the `ReportsSummaryPanel(data: data),` call (inside the non-empty branch) with:

```dart
                                ReportsSummaryPanel(
                                  data: data,
                                  view: reportsState.view,
                                  period: reportsState.period,
                                  onViewChanged: (value) => context
                                      .read<ReportsBloc>()
                                      .add(ReportsViewChanged(value)),
                                ),
```

- [ ] **Step 3: Analyze and run full suite**

Run: `fvm flutter analyze lib\feature\reports`
Expected: No issues found.
Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/presentation/
git commit -m "feat(reports): charts card with project and task donuts and stacked bar view"
```

---

### Task 7: Hover legend overlay for the stacked bar chart

**Files:**
- Modify: `apps\worklog_studio\lib\feature\reports\presentation\components\reports_summary_panel.dart` (replace `_ReportsStackedBarChart` with a stateful version + add `_BarLegendOverlay`)

**Interfaces:**
- Consumes: `ReportsBar`/`ReportsBarSegment` (Task 4), `chartScale` (Task 2). Call site (`_BarContent`) is unchanged.

Hover technique copied from Dashboard `_BarChart`: fl_chart tooltips stay disabled; a `MouseRegion` maps pointer x to a bar index. The overlay is a positioned card inside a `Stack` - it must not capture pointer events (`IgnorePointer`) and must clamp to the chart width.

UI-only task: no unit tests, verified by analyze + full suite.

- [ ] **Step 1: Replace the static chart with the hover version**

In `apps\worklog_studio\lib\feature\reports\presentation\components\reports_summary_panel.dart`:

1. Add below the `_wideBreakpoint` constant at the top of the file:

```dart
// Width reserved for left Y-axis labels - must match SideTitles.reservedSize.
const double _kLeftReservedSize = 36.0;
```

2. Replace the ENTIRE `_ReportsStackedBarChart` class (one edit, per POST_MORTEM 3.5) with:

```dart
class _ReportsStackedBarChart extends StatefulWidget {
  final List<ReportsBar> bars;

  const _ReportsStackedBarChart({required this.bars});

  @override
  State<_ReportsStackedBarChart> createState() =>
      _ReportsStackedBarChartState();
}

class _ReportsStackedBarChartState extends State<_ReportsStackedBarChart> {
  static const double _overlayWidth = 200;

  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final maxHours = widget.bars
        .map((b) => b.total.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final scale = chartScale(maxHours);
    final n = widget.bars.length;

    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartAreaWidth = constraints.maxWidth - _kLeftReservedSize;
          final hovered = _hoveredIndex;

          return MouseRegion(
            onExit: (_) {
              if (mounted) setState(() => _hoveredIndex = null);
            },
            onHover: (event) {
              if (n == 0 || chartAreaWidth <= 0) return;
              final zoneWidth = chartAreaWidth / n;
              final x = event.localPosition.dx - _kLeftReservedSize;
              final i = (x / zoneWidth).floor().clamp(0, n - 1);
              if (i != _hoveredIndex) setState(() => _hoveredIndex = i);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: BarChart(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    _buildBarChartData(
                      chartMaxY: scale.maxY,
                      interval: scale.interval,
                    ),
                  ),
                ),
                if (hovered != null &&
                    hovered < n &&
                    widget.bars[hovered].segments.isNotEmpty)
                  Positioned(
                    left: _overlayLeft(hovered, n, chartAreaWidth,
                        constraints.maxWidth),
                    top: 0,
                    child: IgnorePointer(
                      child: _BarLegendOverlay(bar: widget.bars[hovered]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Prefer the right side of the hovered bar; flip to the left near the
  // right edge; always stay inside the chart bounds.
  double _overlayLeft(
    int index,
    int n,
    double chartAreaWidth,
    double totalWidth,
  ) {
    final zoneWidth = chartAreaWidth / n;
    final barCenterX = _kLeftReservedSize + zoneWidth * (index + 0.5);
    var left = barCenterX + 24;
    if (left + _overlayWidth > totalWidth) {
      left = barCenterX - 24 - _overlayWidth;
    }
    return left.clamp(0.0, (totalWidth - _overlayWidth).clamp(0.0, totalWidth));
  }

  BarChartData _buildBarChartData({
    required double chartMaxY,
    required double interval,
  }) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return BarChartData(
      maxY: chartMaxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) => FlLine(
          color: palette.border.primary.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value == meta.max) return const SizedBox.shrink();
              final label = value % 1 == 0
                  ? '${value.toInt()}h'
                  : '${value.toStringAsFixed(1)}h';
              return Text(
                label,
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.text.muted,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= widget.bars.length) {
                return const SizedBox.shrink();
              }
              final isActive = index == _hoveredIndex;
              return Padding(
                padding: EdgeInsets.only(top: theme.spacings.xs),
                child: Text(
                  widget.bars[index].label,
                  style: isActive
                      ? theme.commonTextStyles.captionBold.copyWith(
                          color: palette.accent.primary,
                        )
                      : theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                        ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: widget.bars.asMap().entries.map((entry) {
        final index = entry.key;
        final bar = entry.value;
        final isHovered = index == _hoveredIndex;
        final items = <BarChartRodStackItem>[];
        var from = 0.0;
        for (final seg in bar.segments) {
          final to = from + seg.duration.inMinutes / 60;
          items.add(BarChartRodStackItem(
            from,
            to,
            seg.projectId.isEmpty
                ? palette.text.muted
                : BadgeUtils.getBadgeColor(seg.projectId).$2,
          ));
          from = to;
        }
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: from,
              width: 32,
              borderRadius: BorderRadius.circular(4),
              rodStackItems: items,
              backDrawRodData: BackgroundBarChartRodData(
                show: isHovered,
                toY: chartMaxY,
                color: palette.accent.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _BarLegendOverlay extends StatelessWidget {
  final ReportsBar bar;

  const _BarLegendOverlay({required this.bar});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: 200,
      padding: EdgeInsets.all(theme.spacings.sm),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bar.label,
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.text.muted,
                ),
              ),
              Text(
                _formatHours(bar.total),
                style: theme.commonTextStyles.captionBold.copyWith(
                  color: palette.text.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacings.xxs),
          ...bar.segments.map((seg) {
            return Padding(
              padding: EdgeInsets.only(top: theme.spacings.xs),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: seg.projectId.isEmpty
                          ? palette.text.muted
                          : BadgeUtils.getBadgeColor(seg.projectId).$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: theme.spacings.sm),
                  Expanded(
                    child: Text(
                      seg.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacings.sm),
                  Text(
                    _formatHours(seg.duration),
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze and run full suite**

Run: `fvm flutter analyze lib\feature\reports`
Expected: No issues found.
Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/presentation/components/reports_summary_panel.dart
git commit -m "feat(reports): hover legend overlay for stacked bar chart"
```

---

### Task 8: Final verification and POST_MORTEM entry

**Files:**
- Modify: `POST_MORTEM.md` (extend section 1.9 / add session notes)

- [ ] **Step 1: Full analyze over every touched path**

From `apps\worklog_studio\`:
Run: `fvm flutter analyze lib\feature\reports lib\feature\home lib\feature\common\utils`
Expected: No issues found.

- [ ] **Step 2: Full test suite**

Run: `fvm flutter test test/core/ test/feature/ --reporter expanded`
Expected: all PASS (295 pre-existing + new chart_scale, aggregator, and bloc tests).

- [ ] **Step 3: Update POST_MORTEM.md**

Append a short session block (date 2026-07-15, [feature] Reports charts block) recording: `DashboardChartView` now lives in `dashboard_chart_aggregator.dart`; `chartScale` extracted to `feature/common/utils/chart_scale.dart`; `ReportsAggregator` gained `byTask` + stacked `bars` (bucketing duplicated from Dashboard by the same deliberate-duplication decision as 1.9); reports charts UI remains without widget tests (known gap 4.2). Note the overlay legend/hover technique if any new pitfall surfaced during implementation.

- [ ] **Step 4: Commit**

```bash
git add POST_MORTEM.md
git commit -m "docs: post-mortem entry for reports charts block"
```

---

## Appendix: Task Dependency Graph

```
Task 1 (enum move) ----------------+
                                   +--> Task 5 (bloc view) --+
Task 2 (chartScale util) ---+      |                         |
                            |      |                         +--> Task 6 (charts card UI) --> Task 7 (hover overlay) --> Task 8 (verify + docs)
Task 3 (byTask) --> Task 4 (bars) -+-------------------------+
```

- Task 1: no prerequisites.
- Task 2: no prerequisites.
- Task 3: no prerequisites.
- Task 4: requires Task 3 (extends the same ReportsData constructor and aggregate flow).
- Task 5: requires Task 1 (imports DashboardChartView from the aggregator file).
- Task 6: requires Tasks 1, 2, 3, 4, 5 (consumes the enum, chartScale, byTask, bars, view state).
- Task 7: requires Task 6 (replaces a widget inside the file Task 6 writes).
- Task 8: requires Tasks 1-7 (final verification and docs).
