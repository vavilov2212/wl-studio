# Reports Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Reports page to Worklog Studio that shows total hours, a donut chart (by project), a breakdown bar, and a hierarchical grouped table (projects -> tasks) for a selectable time period.

**Architecture:** A new `feature/reports/` slice containing `ReportsAggregator` (pure static aggregation), `ReportsBloc` (period state), and a three-widget presentation layer (`ReportsSummaryPanel`, `ReportsTable`, `ReportsPage`). A new generic `WsGroupedTable<G, I>` widget is added to the style system package. No cross-feature BLoC dependencies - only `DashboardPeriod` enum is imported from `feature/home/`.

**Tech Stack:** Flutter/Dart, flutter_bloc, freezed (hand-written .freezed.dart), fl_chart (PieChart), provider (Selector), worklog_studio_style_system

## Global Constraints

- `build_runner` is broken (Dart 3.10.4 + native_toolchain_c): hand-write `.freezed.dart` following the exact pattern of `apps/worklog_studio/lib/feature/home/bloc/dashboard_charts_bloc.freezed.dart`.
- No hardcoded `Color(0xFF...)`: use `context.theme.colorsPalette.*`.
- No hardcoded pixel paddings: use `context.theme.spacings.*`.
- No italic text anywhere.
- All user-visible hardcoded strings: `// TODO: l10n`.
- No new assets: standard Material `Icons` only.
- `setState` only for cosmetic state (expand/collapse qualifies per POST_MORTEM 2.2).
- No `Co-Authored-By: Claude` in commit messages.
- Commands use `fvm flutter` prefix.

---

### Task 1: ReportsAggregator - data models and aggregation logic

**Files:**
- Create: `apps/worklog_studio/lib/feature/reports/reports_aggregator.dart`
- Create: `apps/worklog_studio/test/core/reports_aggregator_test.dart`

**Interfaces:**
- Produces: `ReportsAggregator.aggregate(...)`, `ReportsData`, `ReportsProjectGroup`, `ReportsTaskRow`, `ReportSlice` - consumed by Task 2 tests and Task 5 UI.

---

- [ ] **Step 1.1: Create stub aggregator with empty method**

Create `apps/worklog_studio/lib/feature/reports/reports_aggregator.dart`:

```dart
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

class ReportSlice {
  final String id;
  final String label;
  final Duration duration;
  final double percentOfTotal;

  const ReportSlice({
    required this.id,
    required this.label,
    required this.duration,
    required this.percentOfTotal,
  });
}

class ReportsTaskRow {
  final String? taskId;
  final String taskName;
  final Duration duration;
  final double percentOfTotal;

  const ReportsTaskRow({
    required this.taskId,
    required this.taskName,
    required this.duration,
    required this.percentOfTotal,
  });
}

class ReportsProjectGroup {
  final String projectId;
  final String projectName;
  final Duration totalDuration;
  final double percentOfTotal;
  final List<ReportsTaskRow> tasks;

  const ReportsProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.totalDuration,
    required this.percentOfTotal,
    required this.tasks,
  });
}

class ReportsData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final Duration totalDuration;
  final List<ReportSlice> byProject;
  final List<ReportsProjectGroup> projectGroups;

  const ReportsData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.totalDuration,
    required this.byProject,
    required this.projectGroups,
  });
}

class _Range {
  final DateTime start;
  final DateTime end;
  const _Range(this.start, this.end);
}

class ReportsAggregator {
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static ReportsData aggregate({
    required List<ResolvedTimeEntry> entries,
    required DashboardPeriod period,
    required DateTime anchorDate,
    required DateTime now,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) {
    throw UnimplementedError();
  }
}
```

- [ ] **Step 1.2: Write the failing tests**

Create `apps/worklog_studio/test/core/reports_aggregator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';

ResolvedTimeEntry _makeEntry({
  required String id,
  required DateTime start,
  required DateTime end,
  String? projectId,
  String? projectName,
  String? taskId,
  String? taskName,
}) {
  final entry = TimeEntry(
    id: id,
    projectId: projectId,
    taskId: taskId,
    startAt: start,
    endAt: end,
    status: TimeEntryStatus.stopped,
  );
  final project = projectId == null
      ? null
      : Project(
          id: projectId,
          name: projectName ?? projectId,
          description: '',
          createdAt: DateTime(2026, 1, 1),
        );
  final task = taskId == null
      ? null
      : Task(
          id: taskId,
          projectId: projectId ?? '',
          title: taskName ?? taskId,
          description: '',
          status: TaskStatus.open,
          createdAt: DateTime(2026, 1, 1),
        );
  return ResolvedTimeEntry(entry: entry, project: project, task: task);
}

void main() {
  // anchor: Monday 2026-07-06; week range: [2026-07-06, 2026-07-13)
  final weekAnchor = DateTime(2026, 7, 6);
  final now = DateTime(2026, 7, 8, 12, 0);

  group('ReportsAggregator.aggregate', () {
    test('empty entries -> zero total, empty groups', () {
      final data = ReportsAggregator.aggregate(
        entries: [],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.totalDuration, equals(Duration.zero));
      expect(data.projectGroups, isEmpty);
      expect(data.byProject, isEmpty);
    });

    test('single entry with no project and no task -> No Project group with Unassigned task', () {
      final entry = _makeEntry(
        id: 'e1',
        start: DateTime(2026, 7, 7, 9),
        end: DateTime(2026, 7, 7, 10),
      );
      final data = ReportsAggregator.aggregate(
        entries: [entry],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.projectGroups.length, equals(1));
      expect(data.projectGroups.first.projectId, equals(''));
      expect(data.projectGroups.first.projectName, equals('No Project'));
      expect(data.projectGroups.first.tasks.length, equals(1));
      expect(data.projectGroups.first.tasks.first.taskName, equals('Unassigned'));
      expect(data.totalDuration, equals(const Duration(hours: 1)));
    });

    test('two projects in period -> sorted by totalDuration descending', () {
      final e1 = _makeEntry(
        id: 'e1',
        start: DateTime(2026, 7, 7, 9),
        end: DateTime(2026, 7, 7, 11),
        projectId: 'p1', projectName: 'Alpha',
        taskId: 't1', taskName: 'Task A',
      );
      final e2 = _makeEntry(
        id: 'e2',
        start: DateTime(2026, 7, 7, 13),
        end: DateTime(2026, 7, 7, 14),
        projectId: 'p2', projectName: 'Beta',
        taskId: 't2', taskName: 'Task B',
      );
      final data = ReportsAggregator.aggregate(
        entries: [e2, e1], // deliberately reversed
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.projectGroups.length, equals(2));
      expect(data.projectGroups[0].projectName, equals('Alpha')); // 2h > 1h
      expect(data.projectGroups[1].projectName, equals('Beta'));
    });

    test('entry outside week range -> excluded from results', () {
      final inRange = _makeEntry(
        id: 'in',
        start: DateTime(2026, 7, 7, 9),
        end: DateTime(2026, 7, 7, 10),
        projectId: 'p1', taskId: 't1',
      );
      final outRange = _makeEntry(
        id: 'out',
        start: DateTime(2026, 6, 30, 9), // previous week
        end: DateTime(2026, 6, 30, 11),
        projectId: 'p1', taskId: 't1',
      );
      final data = ReportsAggregator.aggregate(
        entries: [inRange, outRange],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.totalDuration, equals(const Duration(hours: 1)));
    });

    test('percentOfTotal across byProject sums to 1.0', () {
      final e1 = _makeEntry(
        id: 'e1',
        start: DateTime(2026, 7, 7, 9),
        end: DateTime(2026, 7, 7, 10),
        projectId: 'p1', taskId: 't1',
      );
      final e2 = _makeEntry(
        id: 'e2',
        start: DateTime(2026, 7, 7, 11),
        end: DateTime(2026, 7, 7, 13),
        projectId: 'p2', taskId: 't2',
      );
      final data = ReportsAggregator.aggregate(
        entries: [e1, e2],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      final total = data.byProject.fold<double>(
        0.0, (sum, s) => sum + s.percentOfTotal);
      expect(total, closeTo(1.0, 0.001));
    });

    test('No Project group always sorts to the bottom regardless of duration', () {
      final e1 = _makeEntry(
        id: 'e1',
        start: DateTime(2026, 7, 7, 9),
        end: DateTime(2026, 7, 7, 9, 30), // 30 min
        projectId: 'p1', taskId: 't1',
      );
      final e2 = _makeEntry(
        id: 'e2',
        start: DateTime(2026, 7, 7, 10),
        end: DateTime(2026, 7, 7, 12), // 2h - more than p1
      ); // no project
      final data = ReportsAggregator.aggregate(
        entries: [e1, e2],
        period: DashboardPeriod.week,
        anchorDate: weekAnchor,
        now: now,
      );
      expect(data.projectGroups.last.projectId, equals(''));
    });

    test('custom range -> only entries within [start, inclusive end] included', () {
      final e1 = _makeEntry(
        id: 'e1',
        start: DateTime(2026, 7, 3, 9),
        end: DateTime(2026, 7, 3, 10),
        projectId: 'p1', taskId: 't1',
      );
      final e2 = _makeEntry(
        id: 'e2',
        start: DateTime(2026, 7, 5, 9), // after customRangeEnd
        end: DateTime(2026, 7, 5, 11),
        projectId: 'p1', taskId: 't1',
      );
      final data = ReportsAggregator.aggregate(
        entries: [e1, e2],
        period: DashboardPeriod.custom,
        anchorDate: DateTime(2026, 7, 3),
        now: now,
        customRangeStart: DateTime(2026, 7, 3),
        customRangeEnd: DateTime(2026, 7, 4), // effective end: [Jul 3, Jul 5)
      );
      // e1 starts Jul 3 -> included; e2 starts Jul 5 -> excluded (range.end is Jul 5 exclusive)
      expect(data.totalDuration, equals(const Duration(hours: 1)));
    });
  });
}
```

- [ ] **Step 1.3: Run tests - confirm they fail**

```
cd apps\worklog_studio
fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded
```

Expected: all 6 tests FAIL with `UnimplementedError`.

- [ ] **Step 1.4: Implement `ReportsAggregator.aggregate`**

Replace the `aggregate` stub and add private helpers in `apps/worklog_studio/lib/feature/reports/reports_aggregator.dart`. Replace the entire file:

```dart
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

class ReportSlice {
  final String id;
  final String label;
  final Duration duration;
  final double percentOfTotal;

  const ReportSlice({
    required this.id,
    required this.label,
    required this.duration,
    required this.percentOfTotal,
  });
}

class ReportsTaskRow {
  final String? taskId;
  final String taskName;
  final Duration duration;
  final double percentOfTotal;

  const ReportsTaskRow({
    required this.taskId,
    required this.taskName,
    required this.duration,
    required this.percentOfTotal,
  });
}

class ReportsProjectGroup {
  final String projectId;
  final String projectName;
  final Duration totalDuration;
  final double percentOfTotal;
  final List<ReportsTaskRow> tasks;

  const ReportsProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.totalDuration,
    required this.percentOfTotal,
    required this.tasks,
  });
}

class ReportsData {
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String rangeLabel;
  final Duration totalDuration;
  final List<ReportSlice> byProject;
  final List<ReportsProjectGroup> projectGroups;

  const ReportsData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.totalDuration,
    required this.byProject,
    required this.projectGroups,
  });
}

class _Range {
  final DateTime start;
  final DateTime end;
  const _Range(this.start, this.end);
}

class ReportsAggregator {
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static ReportsData aggregate({
    required List<ResolvedTimeEntry> entries,
    required DashboardPeriod period,
    required DateTime anchorDate,
    required DateTime now,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) {
    final range = _resolveRange(
      period,
      anchorDate,
      customRangeStart: customRangeStart,
      customRangeEnd: customRangeEnd,
    );

    final inRange = entries.where((e) {
      final day = _dateOnly(e.startAt);
      return !day.isBefore(range.start) && day.isBefore(range.end);
    }).toList();

    // Accumulate: projectId -> {taskId -> duration}, projectId -> name, etc.
    final Map<String, Duration> projectDurs = {};
    final Map<String, String> projectNames = {};
    final Map<String, Map<String, Duration>> taskDurs = {};
    final Map<String, Map<String, String>> taskNames = {};

    for (final e in inRange) {
      final pid = e.projectId ?? '';
      final pname = pid.isEmpty ? 'No Project' : (e.project?.name ?? 'No Project'); // TODO: l10n
      final tid = e.taskId ?? '';
      final tname = tid.isEmpty ? 'Unassigned' : (e.task?.title ?? 'Unassigned'); // TODO: l10n
      final dur = e.duration(now);

      projectNames[pid] ??= pname;
      projectDurs[pid] = (projectDurs[pid] ?? Duration.zero) + dur;
      taskDurs[pid] ??= {};
      taskDurs[pid]![tid] = (taskDurs[pid]![tid] ?? Duration.zero) + dur;
      taskNames[pid] ??= {};
      taskNames[pid]![tid] ??= tname;
    }

    final totalMinutes = projectDurs.values
        .fold<int>(0, (sum, d) => sum + d.inMinutes);

    final projectGroups = projectDurs.keys.map((pid) {
      final pDur = projectDurs[pid]!;
      final tDurMap = taskDurs[pid]!;
      final tNameMap = taskNames[pid]!;

      final tasks = tDurMap.keys.map((tid) {
        final tDur = tDurMap[tid]!;
        return ReportsTaskRow(
          taskId: tid.isEmpty ? null : tid,
          taskName: tNameMap[tid]!,
          duration: tDur,
          percentOfTotal: totalMinutes == 0 ? 0.0 : tDur.inMinutes / totalMinutes,
        );
      }).toList()
        ..sort((a, b) => b.duration.compareTo(a.duration));

      return ReportsProjectGroup(
        projectId: pid,
        projectName: projectNames[pid]!,
        totalDuration: pDur,
        percentOfTotal: totalMinutes == 0 ? 0.0 : pDur.inMinutes / totalMinutes,
        tasks: tasks,
      );
    }).toList();

    // Sort: named projects by duration desc; "No Project" always last.
    projectGroups.sort((a, b) {
      if (a.projectId.isEmpty) return 1;
      if (b.projectId.isEmpty) return -1;
      return b.totalDuration.compareTo(a.totalDuration);
    });

    final byProject = projectGroups.map((g) => ReportSlice(
      id: g.projectId,
      label: g.projectName,
      duration: g.totalDuration,
      percentOfTotal: g.percentOfTotal,
    )).toList();

    return ReportsData(
      rangeStart: range.start,
      rangeEnd: range.end,
      rangeLabel: _label(period, range),
      totalDuration: Duration(minutes: totalMinutes),
      byProject: byProject,
      projectGroups: projectGroups,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static _Range _resolveRange(
    DashboardPeriod period,
    DateTime anchorDate, {
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) {
    final anchor = _dateOnly(anchorDate);
    switch (period) {
      case DashboardPeriod.today:
        return _Range(anchor, anchor.add(const Duration(days: 1)));
      case DashboardPeriod.week:
        final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
        return _Range(weekStart, weekStart.add(const Duration(days: 7)));
      case DashboardPeriod.month:
        final monthStart = DateTime(anchor.year, anchor.month, 1);
        return _Range(monthStart, DateTime(anchor.year, anchor.month + 1, 1));
      case DashboardPeriod.custom:
        final start = _dateOnly(customRangeStart!);
        final end = _dateOnly(customRangeEnd!).add(const Duration(days: 1));
        return _Range(start, end);
    }
  }

  static String _label(DashboardPeriod period, _Range range) {
    switch (period) {
      case DashboardPeriod.today:
        return '${_monthNames[range.start.month - 1]} ${range.start.day}';
      case DashboardPeriod.week:
      case DashboardPeriod.custom:
        final lastDay = range.end.subtract(const Duration(days: 1));
        return '${_monthNames[range.start.month - 1]} ${range.start.day} → '
            '${_monthNames[lastDay.month - 1]} ${lastDay.day}';
      case DashboardPeriod.month:
        return '${_monthNames[range.start.month - 1]} ${range.start.year}';
    }
  }
}
```

- [ ] **Step 1.5: Run tests - confirm they pass**

```
cd apps\worklog_studio
fvm flutter test test/core/reports_aggregator_test.dart --reporter expanded
```

Expected: 6 tests PASS.

- [ ] **Step 1.6: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/reports_aggregator.dart \
        apps/worklog_studio/test/core/reports_aggregator_test.dart
git commit -m "feat(reports): add ReportsAggregator with data models and TDD tests"
```

---

### Task 2: ReportsBloc - period state machine

**Files:**
- Create: `apps/worklog_studio/lib/feature/reports/bloc/reports_event.dart`
- Create: `apps/worklog_studio/lib/feature/reports/bloc/reports_state.dart`
- Create: `apps/worklog_studio/lib/feature/reports/bloc/reports_bloc.dart`
- Create: `apps/worklog_studio/lib/feature/reports/bloc/reports_bloc.freezed.dart`
- Create: `apps/worklog_studio/test/feature/reports/reports_bloc_test.dart`

**Interfaces:**
- Consumes: `DashboardPeriod` from `feature/home/dashboard_chart_aggregator.dart`, `Clock` from `domain/time_tracker.dart`, `SystemClock` from `data/system_clock.dart`.
- Produces: `ReportsBloc`, `ReportsState`, `ReportsPeriodChanged`, `ReportsPeriodStepped`, `ReportsCustomRangeSelected`, `ReportsBloc.canStepForward` - consumed by Task 4 navigation wiring and Task 5 UI.

---

- [ ] **Step 2.1: Create all four bloc files**

Create `apps/worklog_studio/lib/feature/reports/bloc/reports_event.dart`:

```dart
part of 'reports_bloc.dart';

abstract class ReportsEvent {}

class ReportsPeriodChanged extends ReportsEvent {
  final DashboardPeriod period;
  ReportsPeriodChanged(this.period);
}

class ReportsPeriodStepped extends ReportsEvent {
  final int direction; // -1 or +1
  ReportsPeriodStepped(this.direction);
}

class ReportsCustomRangeSelected extends ReportsEvent {
  final DateTime start;
  final DateTime end;
  ReportsCustomRangeSelected(this.start, this.end);
}
```

Create `apps/worklog_studio/lib/feature/reports/bloc/reports_state.dart`:

```dart
part of 'reports_bloc.dart';

@freezed
abstract class ReportsState with _$ReportsState {
  const ReportsState._();

  const factory ReportsState({
    required DashboardPeriod period,
    required DateTime anchorDate,
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) = _ReportsState;
}
```

Create `apps/worklog_studio/lib/feature/reports/bloc/reports_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:worklog_studio/data/system_clock.dart';
import 'package:worklog_studio/domain/time_tracker.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';

part 'reports_event.dart';
part 'reports_state.dart';
part 'reports_bloc.freezed.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final Clock _clock;

  ReportsBloc({Clock? clock}) : this._(clock ?? SystemClock());

  ReportsBloc._(Clock clock)
      : _clock = clock,
        super(
          ReportsState(
            period: DashboardPeriod.week,
            anchorDate: _truncate(clock.now(), DashboardPeriod.week),
          ),
        ) {
    on<ReportsPeriodChanged>(_onPeriodChanged);
    on<ReportsPeriodStepped>(_onPeriodStepped);
    on<ReportsCustomRangeSelected>(_onCustomRangeSelected);
  }

  void _onPeriodChanged(
    ReportsPeriodChanged event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      period: event.period,
      anchorDate: _truncate(_clock.now(), event.period),
    ));
  }

  void _onPeriodStepped(
    ReportsPeriodStepped event,
    Emitter<ReportsState> emit,
  ) {
    if (event.direction > 0 &&
        !canStepForward(state.period, state.anchorDate, _clock.now())) {
      return;
    }
    emit(state.copyWith(
      anchorDate: _stepAnchor(state.period, state.anchorDate, event.direction),
    ));
  }

  void _onCustomRangeSelected(
    ReportsCustomRangeSelected event,
    Emitter<ReportsState> emit,
  ) {
    emit(state.copyWith(
      period: DashboardPeriod.custom,
      customRangeStart: event.start,
      customRangeEnd: event.end,
    ));
  }

  static bool canStepForward(
    DashboardPeriod period,
    DateTime anchorDate,
    DateTime now,
  ) {
    if (period == DashboardPeriod.custom) return false;
    return _truncate(anchorDate, period).isBefore(_truncate(now, period));
  }

  static DateTime _truncate(DateTime date, DashboardPeriod period) {
    return period == DashboardPeriod.month
        ? DateTime(date.year, date.month, 1)
        : DateTime(date.year, date.month, date.day);
  }

  static DateTime _stepAnchor(
    DashboardPeriod period,
    DateTime anchor,
    int direction,
  ) {
    switch (period) {
      case DashboardPeriod.today:
        return anchor.add(Duration(days: direction));
      case DashboardPeriod.week:
        return anchor.add(Duration(days: 7 * direction));
      case DashboardPeriod.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
      case DashboardPeriod.custom:
        return anchor;
    }
  }
}
```

Create `apps/worklog_studio/lib/feature/reports/bloc/reports_bloc.freezed.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reports_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReportsState {

 DashboardPeriod get period; DateTime get anchorDate; DateTime? get customRangeStart; DateTime? get customRangeEnd;
/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReportsStateCopyWith<ReportsState> get copyWith => _$ReportsStateCopyWithImpl<ReportsState>(this as ReportsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReportsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.customRangeStart, customRangeStart) || other.customRangeStart == customRangeStart)&&(identical(other.customRangeEnd, customRangeEnd) || other.customRangeEnd == customRangeEnd));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,customRangeStart,customRangeEnd);

@override
String toString() {
  return 'ReportsState(period: $period, anchorDate: $anchorDate, customRangeStart: $customRangeStart, customRangeEnd: $customRangeEnd)';
}


}

/// @nodoc
abstract mixin class $ReportsStateCopyWith<$Res>  {
  factory $ReportsStateCopyWith(ReportsState value, $Res Function(ReportsState) _then) = _$ReportsStateCopyWithImpl;
@useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DateTime? customRangeStart, DateTime? customRangeEnd
});




}
/// @nodoc
class _$ReportsStateCopyWithImpl<$Res>
    implements $ReportsStateCopyWith<$Res> {
  _$ReportsStateCopyWithImpl(this._self, this._then);

  final ReportsState _self;
  final $Res Function(ReportsState) _then;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? period = null,Object? anchorDate = null,Object? customRangeStart = freezed,Object? customRangeEnd = freezed,}) {
  return _then(_self.copyWith(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,customRangeStart: freezed == customRangeStart ? _self.customRangeStart : customRangeStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customRangeEnd: freezed == customRangeEnd ? _self.customRangeEnd : customRangeEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReportsState].
extension ReportsStatePatterns on ReportsState {
@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReportsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReportsState value)  $default,){
final _that = this;
switch (_that) {
case _ReportsState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReportsState value)?  $default,){
final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that);case _:
  return null;

}
}

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DateTime? customRangeStart,  DateTime? customRangeEnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.customRangeStart,_that.customRangeEnd);case _:
  return orElse();

}
}

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DashboardPeriod period,  DateTime anchorDate,  DateTime? customRangeStart,  DateTime? customRangeEnd)  $default,) {final _that = this;
switch (_that) {
case _ReportsState():
return $default(_that.period,_that.anchorDate,_that.customRangeStart,_that.customRangeEnd);case _:
  throw StateError('Unexpected subclass');

}
}

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DashboardPeriod period,  DateTime anchorDate,  DateTime? customRangeStart,  DateTime? customRangeEnd)?  $default,) {final _that = this;
switch (_that) {
case _ReportsState() when $default != null:
return $default(_that.period,_that.anchorDate,_that.customRangeStart,_that.customRangeEnd);case _:
  return null;

}
}

}

/// @nodoc


class _ReportsState extends ReportsState {
  const _ReportsState({required this.period, required this.anchorDate, this.customRangeStart, this.customRangeEnd}): super._();
  

@override final  DashboardPeriod period;
@override final  DateTime anchorDate;
@override final  DateTime? customRangeStart;
@override final  DateTime? customRangeEnd;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReportsStateCopyWith<_ReportsState> get copyWith => __$ReportsStateCopyWithImpl<_ReportsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReportsState&&(identical(other.period, period) || other.period == period)&&(identical(other.anchorDate, anchorDate) || other.anchorDate == anchorDate)&&(identical(other.customRangeStart, customRangeStart) || other.customRangeStart == customRangeStart)&&(identical(other.customRangeEnd, customRangeEnd) || other.customRangeEnd == customRangeEnd));
}


@override
int get hashCode => Object.hash(runtimeType,period,anchorDate,customRangeStart,customRangeEnd);

@override
String toString() {
  return 'ReportsState(period: $period, anchorDate: $anchorDate, customRangeStart: $customRangeStart, customRangeEnd: $customRangeEnd)';
}


}

/// @nodoc
abstract mixin class _$ReportsStateCopyWith<$Res> implements $ReportsStateCopyWith<$Res> {
  factory _$ReportsStateCopyWith(_ReportsState value, $Res Function(_ReportsState) _then) = __$ReportsStateCopyWithImpl;
@override @useResult
$Res call({
 DashboardPeriod period, DateTime anchorDate, DateTime? customRangeStart, DateTime? customRangeEnd
});




}
/// @nodoc
class __$ReportsStateCopyWithImpl<$Res>
    implements _$ReportsStateCopyWith<$Res> {
  __$ReportsStateCopyWithImpl(this._self, this._then);

  final _ReportsState _self;
  final $Res Function(_ReportsState) _then;

/// Create a copy of ReportsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? period = null,Object? anchorDate = null,Object? customRangeStart = freezed,Object? customRangeEnd = freezed,}) {
  return _then(_ReportsState(
period: null == period ? _self.period : period // ignore: cast_nullable_to_non_nullable
as DashboardPeriod,anchorDate: null == anchorDate ? _self.anchorDate : anchorDate // ignore: cast_nullable_to_non_nullable
as DateTime,customRangeStart: freezed == customRangeStart ? _self.customRangeStart : customRangeStart // ignore: cast_nullable_to_non_nullable
as DateTime?,customRangeEnd: freezed == customRangeEnd ? _self.customRangeEnd : customRangeEnd // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
```

- [ ] **Step 2.2: Write failing BLoC tests**

Create directory and test file `apps/worklog_studio/test/feature/reports/reports_bloc_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import '../../helpers/test_fakes.dart';

void main() {
  group('ReportsBloc', () {
    // Fixed Monday: 2026-07-06 12:00
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(DateTime(2026, 7, 6, 12, 0));
    });

    test('initial state: week period, anchorDate is truncated to week Monday', () async {
      final bloc = ReportsBloc(clock: clock);
      expect(bloc.state.period, equals(DashboardPeriod.week));
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6))); // Monday
      await bloc.close();
    });

    test('ReportsPeriodChanged(today) -> period changes, anchorDate resets to today', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodChanged(DashboardPeriod.today));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.today));
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6)));
      await bloc.close();
    });

    test('ReportsPeriodStepped(-1) on week -> anchorDate moves back 7 days', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodStepped(-1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(DateTime(2026, 6, 29)));
      await bloc.close();
    });

    test('ReportsPeriodStepped(+1) on current week -> no change (canStepForward guard)', () async {
      final bloc = ReportsBloc(clock: clock);
      final before = bloc.state.anchorDate;
      bloc.add(ReportsPeriodStepped(1));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(before));
      await bloc.close();
    });

    test('ReportsPeriodStepped(+1) on past week -> anchorDate moves forward 7 days', () async {
      final bloc = ReportsBloc(clock: clock);
      bloc.add(ReportsPeriodStepped(-1)); // go to June 29 week
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReportsPeriodStepped(1)); // back to July 6 week
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.anchorDate, equals(DateTime(2026, 7, 6)));
      await bloc.close();
    });

    test('ReportsCustomRangeSelected -> period becomes custom, dates set', () async {
      final bloc = ReportsBloc(clock: clock);
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 5);
      bloc.add(ReportsCustomRangeSelected(start, end));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.period, equals(DashboardPeriod.custom));
      expect(bloc.state.customRangeStart, equals(start));
      expect(bloc.state.customRangeEnd, equals(end));
      await bloc.close();
    });

    test('canStepForward is false for current week', () {
      final now = DateTime(2026, 7, 6, 12, 0);
      final anchor = DateTime(2026, 7, 6); // current week
      expect(ReportsBloc.canStepForward(DashboardPeriod.week, anchor, now), isFalse);
    });

    test('canStepForward is true for past week', () {
      final now = DateTime(2026, 7, 6, 12, 0);
      final anchor = DateTime(2026, 6, 29); // previous week
      expect(ReportsBloc.canStepForward(DashboardPeriod.week, anchor, now), isTrue);
    });

    test('canStepForward is always false for custom period', () {
      final now = DateTime(2026, 7, 6);
      final anchor = DateTime(2026, 6, 1);
      expect(ReportsBloc.canStepForward(DashboardPeriod.custom, anchor, now), isFalse);
    });
  });
}
```

- [ ] **Step 2.3: Run tests - confirm they fail**

```
cd apps\worklog_studio
fvm flutter test test/feature/reports/reports_bloc_test.dart --reporter expanded
```

Expected: all tests FAIL - `reports_bloc.dart` references `_$ReportsState` from the freezed file; if the freezed file is malformed the errors show as parse/compile errors. Fix any syntax issues in the freezed file until the tests fail with actual assertion errors.

- [ ] **Step 2.4: Run tests - confirm they pass**

The implementation is already complete from Step 2.1. Re-run:

```
cd apps\worklog_studio
fvm flutter test test/feature/reports/reports_bloc_test.dart --reporter expanded
```

Expected: all 9 tests PASS.

- [ ] **Step 2.5: Analyze bloc directory**

```
cd apps\worklog_studio
fvm flutter analyze lib/feature/reports/bloc/
```

Expected: No issues found.

- [ ] **Step 2.6: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/bloc/ \
        apps/worklog_studio/test/feature/reports/reports_bloc_test.dart
git commit -m "feat(reports): add ReportsBloc with period state and TDD tests"
```

---

### Task 3: WsGroupedTable widget in style system

**Files:**
- Create: `packages/worklog_studio_style_system/lib/ui_kit/src/table/ws_grouped_table.dart`
- Modify: `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart` - add export line
- Modify: `packages/worklog_studio_style_system/UI_KIT.md` - document new component

**Interfaces:**
- Produces: `WsGroupedTable<G, I>`, `WsGroupedTableColumn<G, I>` - consumed by Task 5 `ReportsTable`.

---

- [ ] **Step 3.1: Create `ws_grouped_table.dart`**

Create `packages/worklog_studio_style_system/lib/ui_kit/src/table/ws_grouped_table.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class WsGroupedTableColumn<G, I> {
  final String title;
  final Widget Function(BuildContext context, G group) groupCellBuilder;
  final Widget Function(BuildContext context, G group, I item) itemCellBuilder;
  final int flex;
  final double? fixedWidth;
  final Alignment alignment;

  const WsGroupedTableColumn({
    required this.title,
    required this.groupCellBuilder,
    required this.itemCellBuilder,
    this.flex = 1,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
  });
}

class WsGroupedTable<G, I> extends StatefulWidget {
  final List<WsGroupedTableColumn<G, I>> columns;
  final List<G> groups;
  final List<I> Function(G group) itemsOf;
  final Key Function(G group) groupKeyBuilder;
  final Key Function(G group, I item) itemKeyBuilder;
  final Widget Function(BuildContext context)? totalRowBuilder;
  final bool initiallyExpanded;
  final bool showHeader;

  const WsGroupedTable({
    super.key,
    required this.columns,
    required this.groups,
    required this.itemsOf,
    required this.groupKeyBuilder,
    required this.itemKeyBuilder,
    this.totalRowBuilder,
    this.initiallyExpanded = true,
    this.showHeader = true,
  });

  @override
  State<WsGroupedTable<G, I>> createState() => _WsGroupedTableState<G, I>();
}

class _WsGroupedTableState<G, I> extends State<WsGroupedTable<G, I>> {
  final Set<Key> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) {
      _expandedGroups.addAll(
        widget.groups.map((g) => widget.groupKeyBuilder(g)),
      );
    }
  }

  @override
  void didUpdateWidget(WsGroupedTable<G, I> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_groupsUnchanged(oldWidget.groups, widget.groups)) {
      _expandedGroups.clear();
      if (widget.initiallyExpanded) {
        _expandedGroups.addAll(
          widget.groups.map((g) => widget.groupKeyBuilder(g)),
        );
      }
    }
  }

  bool _groupsUnchanged(List<G> oldGroups, List<G> newGroups) {
    if (oldGroups.length != newGroups.length) return false;
    for (var i = 0; i < newGroups.length; i++) {
      if (widget.groupKeyBuilder(oldGroups[i]) !=
          widget.groupKeyBuilder(newGroups[i])) return false;
    }
    return true;
  }

  void _toggleGroup(Key key) {
    setState(() {
      if (_expandedGroups.contains(key)) {
        _expandedGroups.remove(key);
      } else {
        _expandedGroups.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final borderColor = palette.border.primary.withValues(alpha: 0.4);

    final List<Widget> rows = [];

    for (var gi = 0; gi < widget.groups.length; gi++) {
      final group = widget.groups[gi];
      final gKey = widget.groupKeyBuilder(group);
      final isExpanded = _expandedGroups.contains(gKey);
      final items = widget.itemsOf(group);

      rows.add(_GroupRow<G, I>(
        group: group,
        columns: widget.columns,
        isExpanded: isExpanded,
        onToggle: () => _toggleGroup(gKey),
      ));

      if (isExpanded) {
        for (final item in items) {
          rows.add(_ItemRow<G, I>(
            key: widget.itemKeyBuilder(group, item),
            group: group,
            item: item,
            columns: widget.columns,
          ));
        }
      }

      final isLastGroup = gi == widget.groups.length - 1;
      if (!isLastGroup || widget.totalRowBuilder != null) {
        rows.add(Divider(height: 1, thickness: 1, color: borderColor));
      }
    }

    if (widget.totalRowBuilder != null) {
      rows.add(widget.totalRowBuilder!(context));
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: borderColor),
        boxShadow: [theme.shadows.sm],
      ),
      child: ClipRRect(
        borderRadius: theme.radiuses.md.circular,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) _buildHeader(context, borderColor),
            if (widget.groups.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No data', // TODO: l10n
                    style: theme.commonTextStyles.body2.copyWith(
                      color: palette.text.muted,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(children: rows),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color borderColor) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.lg,
        vertical: theme.spacings.xxs,
      ),
      child: Row(
        children: widget.columns.asMap().entries.map((entry) {
          final col = entry.value;
          final isLast = entry.key == widget.columns.length - 1;
          final cell = Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : theme.spacings.md),
            child: Align(
              alignment: col.alignment,
              child: Text(
                col.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.commonTextStyles.labelSmall.copyWith(
                  color: palette.text.muted,
                ),
              ),
            ),
          );
          if (col.fixedWidth != null) {
            return SizedBox(width: col.fixedWidth, child: cell);
          }
          return Expanded(flex: col.flex, child: cell);
        }).toList(),
      ),
    );
  }
}

class _GroupRow<G, I> extends StatefulWidget {
  final G group;
  final List<WsGroupedTableColumn<G, I>> columns;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _GroupRow({
    required this.group,
    required this.columns,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_GroupRow<G, I>> createState() => _GroupRowState<G, I>();
}

class _GroupRowState<G, I> extends State<_GroupRow<G, I>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 40,
      child: Container(
        color: _isHovered
            ? palette.background.surfaceMuted
            : palette.background.surface,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            onHover: (val) => setState(() => _isHovered = val),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
              child: Row(
                children: widget.columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final col = entry.value;
                  final isFirst = idx == 0;
                  final isLast = idx == widget.columns.length - 1;

                  Widget cell;
                  if (isFirst) {
                    // First column: chevron + content side by side.
                    // Avoid Align wrapper here since the inner Row needs
                    // bounded width from the outer Expanded.
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: DefaultTextStyle(
                        style: theme.commonTextStyles.body2Bold.copyWith(
                          color: palette.text.primary,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.isExpanded
                                  ? Icons.expand_more_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: palette.text.secondary,
                            ),
                            SizedBox(width: theme.spacings.xxs),
                            Expanded(
                              child: col.groupCellBuilder(context, widget.group),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: Align(
                        alignment: col.alignment,
                        child: DefaultTextStyle(
                          style: theme.commonTextStyles.body2Bold.copyWith(
                            color: palette.text.primary,
                          ),
                          child: col.groupCellBuilder(context, widget.group),
                        ),
                      ),
                    );
                  }

                  if (col.fixedWidth != null) {
                    return SizedBox(width: col.fixedWidth, child: cell);
                  }
                  return Expanded(flex: col.flex, child: cell);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow<G, I> extends StatefulWidget {
  final G group;
  final I item;
  final List<WsGroupedTableColumn<G, I>> columns;

  const _ItemRow({
    super.key,
    required this.group,
    required this.item,
    required this.columns,
  });

  @override
  State<_ItemRow<G, I>> createState() => _ItemRowState<G, I>();
}

class _ItemRowState<G, I> extends State<_ItemRow<G, I>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 36,
      child: Container(
        color: _isHovered
            ? palette.background.surfaceMuted.withValues(alpha: 0.5)
            : palette.background.canvas,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null,
            onHover: (val) => setState(() => _isHovered = val),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
              child: Row(
                children: widget.columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final col = entry.value;
                  final isFirst = idx == 0;
                  final isLast = idx == widget.columns.length - 1;

                  Widget cell;
                  if (isFirst) {
                    // Indent item rows under their group.
                    cell = Padding(
                      padding: EdgeInsets.only(
                        left: theme.spacings.x2l,
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: DefaultTextStyle(
                        style: theme.commonTextStyles.body2.copyWith(
                          color: palette.text.secondary,
                        ),
                        child:
                            col.itemCellBuilder(context, widget.group, widget.item),
                      ),
                    );
                  } else {
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: Align(
                        alignment: col.alignment,
                        child: DefaultTextStyle(
                          style: theme.commonTextStyles.body2.copyWith(
                            color: palette.text.secondary,
                          ),
                          child: col.itemCellBuilder(
                              context, widget.group, widget.item),
                        ),
                      ),
                    );
                  }

                  if (col.fixedWidth != null) {
                    return SizedBox(width: col.fixedWidth, child: cell);
                  }
                  return Expanded(flex: col.flex, child: cell);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3.2: Export from barrel**

In `packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart`, add after the `ws_table.dart` line:

```dart
export 'src/table/ws_grouped_table.dart';
```

The file should read (lines 19-22):
```dart
export 'src/table/ws_table.dart';
export 'src/table/ws_grouped_table.dart';
export 'src/table/table_toolbar.dart';
export 'src/table/clearable_filter_pill.dart';
```

- [ ] **Step 3.3: Add WsGroupedTable section to UI_KIT.md**

In `packages/worklog_studio_style_system/UI_KIT.md`, add after the `### WsTable` section (before `### TableToolbar`):

```markdown
---

### WsGroupedTable

Hierarchical data table with collapsible group rows and indented item rows. Generically typed as `WsGroupedTable<G, I>` where `G` is the group type and `I` is the item type. Expand/collapse state is local (`setState`) - cosmetic only.

```dart
WsGroupedTable<ProjectGroup, TaskRow>(
  groups: _projectGroups,
  columns: [
    WsGroupedTableColumn<ProjectGroup, TaskRow>(
      title: 'Name',
      groupCellBuilder: (ctx, group) => Text(group.name),
      itemCellBuilder: (ctx, group, item) => Text(item.title),
      flex: 3,
    ),
    WsGroupedTableColumn<ProjectGroup, TaskRow>(
      title: 'Hours',
      groupCellBuilder: (ctx, group) => Text(group.hoursLabel),
      itemCellBuilder: (ctx, group, item) => Text(item.hoursLabel),
      flex: 1,
      alignment: Alignment.centerRight,
    ),
  ],
  itemsOf: (group) => group.tasks,
  groupKeyBuilder: (group) => ValueKey(group.id),
  itemKeyBuilder: (group, item) => ValueKey('${group.id}_${item.id}'),
  totalRowBuilder: (ctx) => MyTotalRow(),  // optional
  initiallyExpanded: true,   // all groups open by default
  showHeader: true,
)
```

- Group rows: 40px height, `body2Bold`, `background.surface` + `surfaceMuted` on hover, chevron toggle.
- Item rows: 36px height, `body2`, `background.canvas` + `surfaceMuted@50%` on hover, `spacings.x2l` indent on first cell.
- When `groups.isEmpty`: shows centered "No data" muted label.
- `didUpdateWidget` resets expand/collapse when group key set changes.
```

- [ ] **Step 3.4: Analyze style system**

```
cd packages\worklog_studio_style_system
fvm flutter analyze lib/
```

Expected: No issues found.

- [ ] **Step 3.5: Commit**

```bash
git add packages/worklog_studio_style_system/lib/ui_kit/src/table/ws_grouped_table.dart \
        packages/worklog_studio_style_system/lib/ui_kit/ui_kit.dart \
        packages/worklog_studio_style_system/UI_KIT.md
git commit -m "feat(ui-kit): add WsGroupedTable generic hierarchical table widget"
```

---

### Task 4: Navigation wiring + stub ReportsScreen

**Files:**
- Modify: `apps/worklog_studio/lib/feature/app/layout/app_route.dart`
- Modify: `apps/worklog_studio/lib/feature/app/layout/sidebar_navigation.dart`
- Modify: `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`
- Modify: `apps/worklog_studio/lib/feature/app/app.dart`
- Create: `apps/worklog_studio/lib/feature/reports/presentation/reports_page.dart` (stub)

**Interfaces:**
- Consumes: `ReportsBloc` from Task 2.
- Produces: `AppRoute.reports` enum value, `ReportsScreen` class, BLoC available via `context.read<ReportsBloc>()`.

---

- [ ] **Step 4.1: Add `AppRoute.reports` to the enum**

Edit `apps/worklog_studio/lib/feature/app/layout/app_route.dart`. Replace entire file:

```dart
enum AppRoute { dashboard, history, reports, projects, tasks, settingsGeneral, settingsHotkeys }

bool isSettingsRoute(AppRoute route) =>
    route == AppRoute.settingsGeneral || route == AppRoute.settingsHotkeys;
```

- [ ] **Step 4.2: Create stub `ReportsScreen`**

Create `apps/worklog_studio/lib/feature/reports/presentation/reports_page.dart`:

```dart
import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
```

- [ ] **Step 4.3: Wire into `app_shell.dart`**

In `apps/worklog_studio/lib/feature/app/layout/app_shell.dart`:

1. Add import after the `history_page.dart` import:
   ```dart
   import 'package:worklog_studio/feature/reports/presentation/reports_page.dart';
   ```

2. Add a case to `_buildActiveScreen()`. The current switch ends at `settingsHotkeys`. Add the new case before `settingsGeneral`:
   ```dart
   case AppRoute.reports:
     return const ReportsScreen();
   ```

The full switch after editing:
```dart
Widget _buildActiveScreen() {
  switch (_currentRoute) {
    case AppRoute.dashboard:
      return HomePage(
        title: 'Dashboard',
        onViewAllHistory: () => _onRouteSelected(AppRoute.history),
        onSelectHistoryEntry: _openHistoryEntry,
        onAddTimeEntry: _openHistoryCreateEntry,
      );
    case AppRoute.history:
      return const HistoryScreen();
    case AppRoute.reports:
      return const ReportsScreen();
    case AppRoute.projects:
      return const ProjectsScreen();
    case AppRoute.tasks:
      return const TasksScreen();
    case AppRoute.settingsGeneral:
      return const GeneralSettingsScreen();
    case AppRoute.settingsHotkeys:
      return const HotkeySettingsScreen();
  }
}
```

- [ ] **Step 4.4: Add Reports nav item to sidebar**

In `apps/worklog_studio/lib/feature/app/layout/sidebar_navigation.dart`, in the `build` method's column `children` list, add a Reports nav item after the History item and before the "Manage" section label. The relevant block (lines 116-136) should read after editing:

```dart
_navItem(AppRoute.dashboard, 'Dashboard', Icons.grid_view_rounded),
_navItem(AppRoute.history, 'History', Icons.history_rounded),
_navItem(AppRoute.reports, 'Reports', Icons.bar_chart_rounded), // TODO: l10n
if (!_collapsed)
  Padding(
    padding: EdgeInsets.only(
      top: theme.spacings.md,
      bottom: theme.spacings.xxs,
      left: theme.spacings.lg,
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Manage',
        style: theme.commonTextStyles.labelSmall.copyWith(
          color: palette.sidebar.sectionLabel,
          letterSpacing: 0.8,
        ),
      ),
    ),
  )
else
  SizedBox(height: theme.spacings.sm),
_navItem(AppRoute.projects, 'Projects', Icons.folder_outlined),
```

- [ ] **Step 4.5: Provide `ReportsBloc` at `MainApp` level**

In `apps/worklog_studio/lib/feature/app/app.dart`:

1. Add import after the `history_bloc.dart` import:
   ```dart
   import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
   ```

2. In the `MultiProvider` providers list, add `BlocProvider<ReportsBloc>` after `BlocProvider<HistoryBloc>`:
   ```dart
   BlocProvider<HistoryBloc>(create: (_) => HistoryBloc()),
   BlocProvider<ReportsBloc>(create: (_) => ReportsBloc()),
   ```

- [ ] **Step 4.6: Analyze the app**

```
cd apps\worklog_studio
fvm flutter analyze lib/
```

Expected: No issues found. If there are enum exhaustiveness errors from the new `AppRoute.reports` case, they are already handled by Step 4.3.

- [ ] **Step 4.7: Commit**

```bash
git add apps/worklog_studio/lib/feature/app/layout/app_route.dart \
        apps/worklog_studio/lib/feature/app/layout/sidebar_navigation.dart \
        apps/worklog_studio/lib/feature/app/layout/app_shell.dart \
        apps/worklog_studio/lib/feature/app/app.dart \
        apps/worklog_studio/lib/feature/reports/presentation/reports_page.dart
git commit -m "feat(reports): wire navigation and provide ReportsBloc at app level"
```

---

### Task 5: ReportsSummaryPanel, ReportsTable, and full ReportsPage

**Files:**
- Create: `apps/worklog_studio/lib/feature/reports/presentation/components/reports_summary_panel.dart`
- Create: `apps/worklog_studio/lib/feature/reports/presentation/components/reports_table.dart`
- Modify: `apps/worklog_studio/lib/feature/reports/presentation/reports_page.dart` (replace stub)

**Interfaces:**
- Consumes: `ReportsData`, `ReportsProjectGroup`, `ReportsTaskRow`, `ReportSlice` (Task 1), `ReportsBloc`, `ReportsState` (Task 2), `WsGroupedTable` (Task 3), `BadgeUtils.getBadgeColor` from `feature/common/utils/badge_utils.dart`, `DateFormatter.formatDurationHm` from `core/utils/date_formatter.dart`.

---

- [ ] **Step 5.1: Create `ReportsSummaryPanel`**

Create `apps/worklog_studio/lib/feature/reports/presentation/components/reports_summary_panel.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ReportsSummaryPanel extends StatelessWidget {
  final ReportsData data;

  const ReportsSummaryPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Total hours
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total hours', // TODO: l10n
                  style: theme.commonTextStyles.caption.copyWith(
                    color: palette.text.secondary,
                  ),
                ),
                SizedBox(height: theme.spacings.xxs),
                Text(
                  DateFormatter.formatDurationHm(data.totalDuration),
                  style: theme.commonTextStyles.displayLarge.copyWith(
                    color: palette.text.primary,
                  ),
                ),
              ],
            ),
            SizedBox(width: theme.spacings.xl),
            // Donut chart
            SizedBox(
              width: 180,
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: data.byProject.map((slice) {
                    return PieChartSectionData(
                      value: slice.duration.inMinutes.toDouble(),
                      color: _colorFor(slice.id, palette),
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
            // Legend
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: data.byProject.map((slice) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: theme.spacings.xxs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _colorFor(slice.id, palette),
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
        SizedBox(height: theme.spacings.lg),
        _BreakdownBar(slices: data.byProject),
      ],
    );
  }

  Color _colorFor(String projectId, colorsPalette) {
    if (projectId.isEmpty) return colorsPalette.text.muted as Color;
    return BadgeUtils.getBadgeColor(projectId).$2;
  }

  String _formatHours(Duration d) {
    final h = d.inMinutes / 60;
    return '${h.toStringAsFixed(1)}h';
  }
}

class _BreakdownBar extends StatelessWidget {
  final List<ReportSlice> slices;

  const _BreakdownBar({required this.slices});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final visible = slices.where((s) => s.duration.inMinutes > 0).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 12,
      child: Row(
        children: List.generate(visible.length, (i) {
          final slice = visible[i];
          final isFirst = i == 0;
          final isLast = i == visible.length - 1;
          final radius = theme.radiuses.pill;
          return Flexible(
            flex: (slice.percentOfTotal * 1000).round().clamp(1, 1000),
            child: Container(
              decoration: BoxDecoration(
                color: slice.id.isEmpty
                    ? palette.text.muted
                    : BadgeUtils.getBadgeColor(slice.id).$2,
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? Radius.circular(radius) : Radius.zero,
                  bottomLeft: isFirst ? Radius.circular(radius) : Radius.zero,
                  topRight: isLast ? Radius.circular(radius) : Radius.zero,
                  bottomRight: isLast ? Radius.circular(radius) : Radius.zero,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
```

- [ ] **Step 5.2: Create `ReportsTable`**

Create `apps/worklog_studio/lib/feature/reports/presentation/components/reports_table.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ReportsTable extends StatelessWidget {
  final ReportsData data;

  const ReportsTable({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return WsGroupedTable<ReportsProjectGroup, ReportsTaskRow>(
      groups: data.projectGroups,
      columns: [
        WsGroupedTableColumn<ReportsProjectGroup, ReportsTaskRow>(
          title: 'Name', // TODO: l10n
          groupCellBuilder: (ctx, group) => _ProjectCell(group: group),
          itemCellBuilder: (ctx, group, item) => Text(
            item.taskName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          flex: 3,
        ),
        WsGroupedTableColumn<ReportsProjectGroup, ReportsTaskRow>(
          title: 'Hours', // TODO: l10n
          groupCellBuilder: (ctx, group) =>
              Text(DateFormatter.formatDurationHm(group.totalDuration)),
          itemCellBuilder: (ctx, group, item) =>
              Text(DateFormatter.formatDurationHm(item.duration)),
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        WsGroupedTableColumn<ReportsProjectGroup, ReportsTaskRow>(
          title: 'Progress', // TODO: l10n
          groupCellBuilder: (ctx, group) => _ProgressBar(
            value: group.percentOfTotal,
            color: group.projectId.isEmpty
                ? ctx.theme.colorsPalette.text.muted
                : BadgeUtils.getBadgeColor(group.projectId).$2,
          ),
          itemCellBuilder: (ctx, group, item) => _ProgressBar(
            value: item.percentOfTotal,
            color: group.projectId.isEmpty
                ? ctx.theme.colorsPalette.text.muted
                : BadgeUtils.getBadgeColor(group.projectId).$2,
          ),
          flex: 2,
        ),
      ],
      itemsOf: (group) => group.tasks,
      groupKeyBuilder: (group) => ValueKey(group.projectId),
      itemKeyBuilder: (group, item) =>
          ValueKey('${group.projectId}_${item.taskId ?? item.taskName}'),
      totalRowBuilder: data.projectGroups.isEmpty
          ? null
          : (ctx) => _TotalRow(data: data),
    );
  }
}

class _ProjectCell extends StatelessWidget {
  final ReportsProjectGroup group;

  const _ProjectCell({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final color = group.projectId.isEmpty
        ? palette.text.muted
        : BadgeUtils.getBadgeColor(group.projectId).$2;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: theme.spacings.xxs),
        Expanded(
          child: Text(
            group.projectName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        borderRadius: theme.radiuses.pill.circular,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: theme.radiuses.pill.circular,
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final ReportsData data;

  const _TotalRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final borderColor = palette.border.primary.withValues(alpha: 0.4);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Total', // TODO: l10n
              style: theme.commonTextStyles.body2Bold.copyWith(
                color: palette.text.primary,
              ),
            ),
          ),
          SizedBox(width: theme.spacings.md),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormatter.formatDurationHm(data.totalDuration),
                style: theme.commonTextStyles.body2Bold.copyWith(
                  color: palette.text.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: theme.spacings.md),
          const Expanded(flex: 2, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5.3: Replace stub with full `ReportsPage`**

Replace all content in `apps/worklog_studio/lib/feature/reports/presentation/reports_page.dart`:

```dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/home/dashboard_chart_aggregator.dart';
import 'package:worklog_studio/feature/reports/bloc/reports_bloc.dart';
import 'package:worklog_studio/feature/reports/presentation/components/reports_summary_panel.dart';
import 'package:worklog_studio/feature/reports/presentation/components/reports_table.dart';
import 'package:worklog_studio/feature/reports/reports_aggregator.dart';
import 'package:worklog_studio/state/entity_resolver.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, reportsState) {
        return Selector<EntityResolver, List<ResolvedTimeEntry>>(
          selector: (context, resolver) => resolver.getResolvedTimeEntries(),
          shouldRebuild: (prev, next) =>
              !const ListEquality<ResolvedTimeEntry>().equals(prev, next),
          builder: (context, entries, _) {
            final data = ReportsAggregator.aggregate(
              entries: entries,
              period: reportsState.period,
              anchorDate: reportsState.anchorDate,
              now: DateTime.now(),
              customRangeStart: reportsState.customRangeStart,
              customRangeEnd: reportsState.customRangeEnd,
            );
            final isEmpty = data.totalDuration == Duration.zero;
            final theme = context.theme;
            final palette = theme.colorsPalette;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacings.x2l,
                theme.spacings.x2l,
                theme.spacings.x2l,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reports', // TODO: l10n
                        style: theme.commonTextStyles.h3.copyWith(
                          color: palette.text.primary,
                        ),
                      ),
                      _PeriodToolbar(state: reportsState),
                    ],
                  ),
                  SizedBox(height: theme.spacings.lg),
                  if (isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'No time logged for this period.', // TODO: l10n
                          style: theme.commonTextStyles.body.copyWith(
                            color: palette.text.muted,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ReportsSummaryPanel(data: data),
                    SizedBox(height: theme.spacings.lg),
                    Expanded(child: ReportsTable(data: data)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PeriodToolbar extends StatelessWidget {
  final ReportsState state;

  const _PeriodToolbar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final bloc = context.read<ReportsBloc>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: Select<DashboardPeriod>(
            value: state.period,
            minWidth: 110,
            options: const [
              SelectOption(value: DashboardPeriod.today, label: 'Today'), // TODO: l10n
              SelectOption(value: DashboardPeriod.week, label: 'Week'), // TODO: l10n
              SelectOption(value: DashboardPeriod.month, label: 'Month'), // TODO: l10n
              SelectOption(value: DashboardPeriod.custom, label: 'Custom...'), // TODO: l10n
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == DashboardPeriod.custom) {
                _pickCustomRange(context, bloc);
              } else {
                bloc.add(ReportsPeriodChanged(value));
              }
            },
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        if (state.period != DashboardPeriod.custom) ...[
          _StepperButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => bloc.add(ReportsPeriodStepped(-1)),
          ),
          SizedBox(width: theme.spacings.xxs),
        ],
        if (state.period == DashboardPeriod.custom)
          _CustomRangeLabel(state: state, bloc: bloc)
        else
          Text(
            ReportsAggregator.aggregate(
              entries: const [],
              period: state.period,
              anchorDate: state.anchorDate,
              now: DateTime.now(),
              customRangeStart: state.customRangeStart,
              customRangeEnd: state.customRangeEnd,
            ).rangeLabel,
            style: theme.commonTextStyles.body2
                .copyWith(color: palette.text.secondary),
          ),
        if (state.period != DashboardPeriod.custom) ...[
          SizedBox(width: theme.spacings.xxs),
          _StepperButton(
            icon: Icons.chevron_right_rounded,
            enabled: ReportsBloc.canStepForward(
              state.period,
              state.anchorDate,
              DateTime.now(),
            ),
            onTap: () => bloc.add(ReportsPeriodStepped(1)),
          ),
        ],
      ],
    );
  }
}

class _CustomRangeLabel extends StatelessWidget {
  final ReportsState state;
  final ReportsBloc bloc;

  const _CustomRangeLabel({required this.state, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final start = state.customRangeStart;
    final end = state.customRangeEnd;

    // Build the label text inline - we have start/end already in state.
    final label = (start != null && end != null)
        ? ReportsAggregator.aggregate(
            entries: const [],
            period: DashboardPeriod.custom,
            anchorDate: start,
            now: DateTime.now(),
            customRangeStart: start,
            customRangeEnd: end,
          ).rangeLabel
        : 'Custom'; // TODO: l10n

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        borderRadius: theme.radiuses.sm.circular,
        onTap: () => _pickCustomRange(
          context,
          bloc,
          initialRange: start != null && end != null
              ? DateTimeRange(start: start, end: end)
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.commonTextStyles.body2.copyWith(
                  color: palette.text.secondary,
                ),
              ),
              SizedBox(width: theme.spacings.xxs),
              Icon(
                Icons.edit_calendar_rounded,
                size: 14,
                color: palette.text.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final color = enabled ? palette.text.secondary : palette.text.muted;

    return Material(
      color: Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: theme.radiuses.sm.circular,
        child: Padding(
          padding: EdgeInsets.all(theme.spacings.xxs),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

Future<void> _pickCustomRange(
  BuildContext context,
  ReportsBloc bloc, {
  DateTimeRange? initialRange,
}) async {
  final theme = context.theme;
  final palette = theme.colorsPalette;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (dialogContext) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              color: palette.background.surface,
              borderRadius: theme.radiuses.md.circular,
              border: Border.all(color: palette.border.primary),
              boxShadow: [theme.shadows.md],
            ),
            padding: EdgeInsets.all(theme.spacings.sm),
            child: CalendarPicker(
              selectedRange: initialRange,
              lastDate: DateTime.now(),
              onRangeSelected: (range) {
                bloc.add(ReportsCustomRangeSelected(range.start, range.end));
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        ),
      );
    },
  );
}
```

> **Note on `_PeriodToolbar` range label:** The range label is computed by calling `ReportsAggregator.aggregate` with an empty entries list just to get the label string. This is a pure, cheap call (no loops run when entries is empty). If this pattern feels wrong, extract `_rangeLabel(period, anchorDate, now, ...)` as a top-level helper in `reports_aggregator.dart` in a follow-up refactor.

- [ ] **Step 5.4: Analyze the reports feature**

```
cd apps\worklog_studio
fvm flutter analyze lib/feature/reports/
```

Expected: No issues found.

- [ ] **Step 5.5: Run full test suite to confirm no regressions**

```
cd apps\worklog_studio
fvm flutter test test/core/ test/feature/ --reporter expanded
```

Expected: All existing tests + new tests pass.

- [ ] **Step 5.6: Commit**

```bash
git add apps/worklog_studio/lib/feature/reports/presentation/
git commit -m "feat(reports): implement ReportsSummaryPanel, ReportsTable, and full ReportsPage"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Total hours (displayLarge) - `ReportsSummaryPanel` column 1
- [x] Donut chart by project - `ReportsSummaryPanel` PieChart
- [x] Horizontal breakdown bar - `_BreakdownBar` in `ReportsSummaryPanel`
- [x] Period toolbar (Today/Week/Month/Custom + steppers) - `_PeriodToolbar`
- [x] Hierarchical grouped table (projects -> tasks) - `WsGroupedTable` in `ReportsTable`
- [x] Table columns: Name, Hours, Progress bar - Task 5
- [x] Total row at table bottom - `_TotalRow`
- [x] Empty state - `'No time logged for this period.'` in `ReportsScreen`
- [x] No billing columns - confirmed absent
- [x] No tabs - confirmed absent
- [x] Navigation: sidebar + AppRoute.reports + AppShell case - Task 4
- [x] BLoC at MainApp level - Task 4 Step 4.5
- [x] Hand-written .freezed.dart - Task 2
- [x] TDD for aggregator and bloc - Tasks 1+2
- [x] All user strings have `// TODO: l10n` - confirmed throughout
- [x] `BadgeUtils.getBadgeColor` consistent with Dashboard - confirmed
- [x] `didUpdateWidget` resets expand state - `_WsGroupedTableState`
- [x] `canStepForward` guard duplicated (not cross-feature shared) - `ReportsBloc.canStepForward`

**No Placeholders:** None found.

**Type consistency:**
- `ReportSlice.id` (String) used consistently in both `byProject` list and `BadgeUtils.getBadgeColor(slice.id)`
- `ReportsProjectGroup.projectId` (String, empty for "No Project") used consistently as `WsGroupedTable` key and color lookup
- `ReportsBloc.canStepForward(period, anchorDate, now)` signature matches usage in `_PeriodToolbar`
- `ReportsAggregator.aggregate(entries, period, anchorDate, now, ...)` signature matches all call sites
