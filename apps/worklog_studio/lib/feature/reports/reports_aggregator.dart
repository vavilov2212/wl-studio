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
  final List<ReportSlice> byTask;
  final List<ReportsBar> bars;
  final List<ReportsProjectGroup> projectGroups;

  const ReportsData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeLabel,
    required this.totalDuration,
    required this.byProject,
    required this.byTask,
    required this.bars,
    required this.projectGroups,
  });
}

class _Range {
  final DateTime start;
  final DateTime end;
  const _Range(this.start, this.end);
}

class ReportsAggregator {
  // TODO: l10n
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // TODO: l10n
  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
    final Map<String, Duration> flatTaskDurs = {};
    final Map<String, String> flatTaskNames = {};

    for (final e in inRange) {
      final pid = e.projectId ?? ''; // '' sentinel = No Project
      final pname = pid.isEmpty ? 'No Project' : (e.project?.name ?? 'No Project'); // TODO: l10n
      final tid = e.taskId ?? ''; // '' sentinel = Unassigned
      final tname = tid.isEmpty ? 'Unassigned' : (e.task?.title ?? 'Unassigned'); // TODO: l10n
      final dur = e.duration(now);

      projectNames[pid] ??= pname;
      projectDurs[pid] = (projectDurs[pid] ?? Duration.zero) + dur;
      taskDurs[pid] ??= {};
      taskDurs[pid]![tid] = (taskDurs[pid]![tid] ?? Duration.zero) + dur;
      taskNames[pid] ??= {};
      taskNames[pid]![tid] ??= tname;
      flatTaskNames[tid] ??= tname;
      flatTaskDurs[tid] = (flatTaskDurs[tid] ?? Duration.zero) + dur;
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

    final bars = _buildBars(period, range, inRange, now, byProject);

    return ReportsData(
      rangeStart: range.start,
      rangeEnd: range.end,
      rangeLabel: _label(period, range),
      totalDuration: Duration(minutes: totalMinutes),
      byProject: byProject,
      byTask: byTask,
      bars: bars,
      projectGroups: projectGroups,
    );
  }

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
      perBucket[i][pid] =
          (perBucket[i][pid] ?? Duration.zero) + e.duration(now);
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
      final total = segments.fold<Duration>(
          Duration.zero, (sum, s) => sum + s.duration);
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
        return '${_monthNames[range.start.month - 1]} ${range.start.day}'; // TODO: l10n
      case DashboardPeriod.week:
      case DashboardPeriod.custom:
        final lastDay = range.end.subtract(const Duration(days: 1));
        return '${_monthNames[range.start.month - 1]} ${range.start.day} → '
            '${_monthNames[lastDay.month - 1]} ${lastDay.day}'; // TODO: l10n
      case DashboardPeriod.month:
        return '${_monthNames[range.start.month - 1]} ${range.start.year}'; // TODO: l10n
    }
  }
}
