import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/chart_bars.dart';

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
  final now = DateTime(2026, 7, 8, 12, 0);

  group('dailyStackedBars', () {
    test('7 day buckets with per-project stacked segments', () {
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
      final bars = dailyStackedBars(DateTime(2026, 7, 6), entries, now);
      expect(bars.length, equals(7));
      expect(bars[0].label, equals('Mon 6'));
      expect(bars[0].total, equals(Duration.zero));
      expect(bars[0].segments, isEmpty);
      // Tue Jul 7: Alpha 2h stacked before Beta 1h (global duration order).
      expect(bars[1].label, equals('Tue 7'));
      expect(bars[1].total, equals(const Duration(hours: 3)));
      expect(bars[1].segments.length, equals(2));
      expect(bars[1].segments[0].id, equals('p1'));
      expect(bars[1].segments[0].label, equals('Alpha'));
      expect(bars[1].segments[0].duration, equals(const Duration(hours: 2)));
      expect(bars[1].segments[1].id, equals('p2'));
      // Thu Jul 9: single No Project segment.
      expect(bars[3].segments.single.id, equals(''));
      expect(bars[3].segments.single.label, equals('No Project'));
    });

    test('No Project always stacks last even with the largest duration', () {
      final entries = [
        _makeEntry(
          id: 'e1',
          start: DateTime(2026, 7, 7, 9),
          end: DateTime(2026, 7, 7, 14),
        ),
        _makeEntry(
          id: 'e2',
          start: DateTime(2026, 7, 7, 14),
          end: DateTime(2026, 7, 7, 15),
          projectId: 'p1',
          projectName: 'Alpha',
        ),
      ];
      final bars = dailyStackedBars(DateTime(2026, 7, 6), entries, now);
      expect(bars[1].segments.length, equals(2));
      expect(bars[1].segments[0].id, equals('p1'));
      expect(bars[1].segments[1].id, equals(''));
    });
  });

  group('hourlyStackedBars', () {
    test('buckets clipped to hours with entries', () {
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
      final bars = hourlyStackedBars(entries, now);
      expect(bars.length, equals(4)); // 9 AM .. 12 PM
      expect(bars.first.label, equals('9 AM'));
      expect(bars.last.label, equals('12 PM'));
      expect(bars[1].total, equals(Duration.zero));
      expect(
        bars.first.segments.single.duration,
        equals(const Duration(hours: 1)),
      );
    });

    test('empty entries -> no bars', () {
      expect(hourlyStackedBars([], now), isEmpty);
    });
  });

  group('monthlyStackedBars', () {
    test('calendar week buckets', () {
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
      final bars = monthlyStackedBars(
        DateTime(2026, 7, 1),
        DateTime(2026, 8, 1),
        entries,
        DateTime(2026, 7, 31, 23),
      );
      expect(bars.length, equals(5));
      expect(bars.first.label, equals('Week 1'));
      expect(bars.first.total, equals(const Duration(hours: 1)));
      expect(bars.last.label, equals('Week 5'));
      expect(bars.last.total, equals(const Duration(hours: 2)));
    });
  });
}
