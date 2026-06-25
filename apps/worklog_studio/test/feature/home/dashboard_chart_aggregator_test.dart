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
      expect(data.bars.map((b) => b.label).toList(), [
        'Mon 15',
        'Tue 16',
        'Wed 17',
        'Thu 18',
        'Fri 19',
        'Sat 20',
        'Sun 21',
      ]);
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

    test('custom: range is the explicit start/end (inclusive end day), no bars', () {
      final entries = [
        _entry(
          id: 'e1',
          startAt: DateTime(2024, 1, 10, 9),
          endAt: DateTime(2024, 1, 10, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        _entry(
          id: 'e2',
          startAt: DateTime(2024, 1, 20, 9),
          endAt: DateTime(2024, 1, 20, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
        // Day after the inclusive end — must not be counted.
        _entry(
          id: 'e3',
          startAt: DateTime(2024, 1, 21, 9),
          endAt: DateTime(2024, 1, 21, 10),
          projectId: 'p1',
          taskId: 't1',
        ),
      ];

      final data = DashboardChartAggregator.aggregate(
        entries: entries,
        period: DashboardPeriod.custom,
        anchorDate: DateTime(2024, 1, 17),
        now: DateTime(2024, 1, 22),
        customRangeStart: DateTime(2024, 1, 10),
        customRangeEnd: DateTime(2024, 1, 20),
      );

      expect(data.rangeStart, DateTime(2024, 1, 10));
      expect(data.rangeEnd, DateTime(2024, 1, 21));
      expect(data.rangeLabel, 'Jan 10 → Jan 20');
      expect(data.bars, isEmpty);
      expect(data.byProject.single.duration, const Duration(hours: 2));
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
