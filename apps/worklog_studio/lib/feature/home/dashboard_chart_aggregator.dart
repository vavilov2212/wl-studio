import 'package:worklog_studio/domain/resolved_time_entry.dart';

enum DashboardPeriod { today, week, month, custom }

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
    DateTime? customRangeStart,
    DateTime? customRangeEnd,
  }) {
    final range = _resolveRange(
      period,
      anchorDate,
      customRangeStart: customRangeStart,
      customRangeEnd: customRangeEnd,
    );
    // Entries are attributed to the bucket containing their start time, not
    // split across buckets they overlap (matches the bucketing the deleted
    // Daily Focus/This Week cards used) — a session crossing a range boundary
    // counts entirely toward whichever side it started on.
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
        final monthEnd = DateTime(anchor.year, anchor.month + 1, 1);
        return _Range(monthStart, monthEnd);
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
      case DashboardPeriod.custom:
        // Custom ranges are donut-only in the UI (variable day counts don't
        // map to a fixed bucket layout) — bars are simply unused.
        return [];
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
    return List.generate(7, (i) {
      final date = range.start.add(Duration(days: i));
      return DashboardBucket(
        label: '${_weekdayLabels[i]} ${date.day}',
        duration: totals[i],
      );
    });
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
