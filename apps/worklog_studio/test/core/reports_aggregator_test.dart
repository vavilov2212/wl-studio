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
}
