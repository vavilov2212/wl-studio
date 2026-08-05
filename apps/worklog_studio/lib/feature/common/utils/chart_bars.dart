import 'package:worklog_studio/domain/resolved_time_entry.dart';

/// Shared stacked-bar chart data: one bar per time bucket, one colored
/// segment per project. Produced by both the Dashboard and Reports
/// aggregators, consumed by the shared StackedBarChart widget.
class ChartBarSegment {
  final String id; // '' sentinel = No Project
  final String label;
  final Duration duration;

  const ChartBarSegment({
    required this.id,
    required this.label,
    required this.duration,
  });
}

class ChartBar {
  final String label;
  final Duration total;

  /// Only projects with nonzero time in this bucket, in the global project
  /// order (duration desc, No Project last). Empty = nothing logged here.
  final List<ChartBarSegment> segments;

  const ChartBar({
    required this.label,
    required this.total,
    required this.segments,
  });
}

// TODO: l10n
const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Hourly buckets clipped to [minHour, maxHour] of the entries' start times.
List<ChartBar> hourlyStackedBars(
  List<ResolvedTimeEntry> inRange,
  DateTime now,
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
  );
}

/// Seven day buckets starting at [rangeStart] (a Monday for week ranges).
List<ChartBar> dailyStackedBars(
  DateTime rangeStart,
  List<ResolvedTimeEntry> inRange,
  DateTime now,
) {
  return _barsFromBuckets(
    bucketCount: 7,
    labelOf: (i) {
      final date = rangeStart.add(Duration(days: i));
      return '${_weekdayLabels[i]} ${date.day}';
    },
    bucketIndexOf: (e) => _dateOnly(e.startAt).difference(rangeStart).inDays,
    inRange: inRange,
    now: now,
  );
}

/// Calendar-week buckets for the month [rangeStart, rangeEnd).
List<ChartBar> monthlyStackedBars(
  DateTime rangeStart,
  DateTime rangeEnd,
  List<ResolvedTimeEntry> inRange,
  DateTime now,
) {
  final firstWeekdayOffset = rangeStart.weekday - 1;
  final daysInMonth = rangeEnd.difference(rangeStart).inDays;
  final weekCount = ((daysInMonth + firstWeekdayOffset - 1) ~/ 7) + 1;
  return _barsFromBuckets(
    bucketCount: weekCount,
    labelOf: (i) => 'Week ${i + 1}', // TODO: l10n
    bucketIndexOf: (e) =>
        (_dateOnly(e.startAt).difference(rangeStart).inDays +
            firstWeekdayOffset) ~/
        7,
    inRange: inRange,
    now: now,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _hourLabel(int hour) {
  final period = hour < 12 ? 'AM' : 'PM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display $period';
}

List<ChartBar> _barsFromBuckets({
  required int bucketCount,
  required String Function(int index) labelOf,
  required int Function(ResolvedTimeEntry entry) bucketIndexOf,
  required List<ResolvedTimeEntry> inRange,
  required DateTime now,
}) {
  // Global project order: duration desc, No Project sentinel last - matches
  // the byProject slice order both aggregators expose, so stack colors read
  // consistently across bars and against the donut legends.
  final totals = <String, Duration>{};
  final labels = <String, String>{};
  for (final e in inRange) {
    final pid = e.projectId ?? '';
    totals[pid] = (totals[pid] ?? Duration.zero) + e.duration(now);
    labels[pid] ??= e.projectName;
  }
  final order = totals.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty) return 1;
      if (b.isEmpty) return -1;
      return totals[b]!.compareTo(totals[a]!);
    });

  final perBucket = List.generate(bucketCount, (_) => <String, Duration>{});
  for (final e in inRange) {
    final i = bucketIndexOf(e);
    if (i < 0 || i >= bucketCount) continue;
    final pid = e.projectId ?? '';
    perBucket[i][pid] = (perBucket[i][pid] ?? Duration.zero) + e.duration(now);
  }

  return List.generate(bucketCount, (i) {
    final durs = perBucket[i];
    final segments = order
        .where((pid) => (durs[pid] ?? Duration.zero) > Duration.zero)
        .map((pid) => ChartBarSegment(
              id: pid,
              label: labels[pid]!,
              duration: durs[pid]!,
            ))
        .toList();
    final total =
        segments.fold<Duration>(Duration.zero, (sum, s) => sum + s.duration);
    return ChartBar(label: labelOf(i), total: total, segments: segments);
  });
}
