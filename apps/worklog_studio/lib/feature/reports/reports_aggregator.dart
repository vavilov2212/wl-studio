import 'package:worklog_studio/domain/resolved_time_entry.dart';
import 'package:worklog_studio/feature/common/utils/chart_bars.dart';
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
  final List<ReportSlice> byTask;
  final List<ChartBar> bars;
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

    // Custom ranges are donut-only in the UI (variable day counts don't map
    // to a fixed bucket layout) - bars are simply unused.
    final bars = switch (period) {
      DashboardPeriod.today => hourlyStackedBars(inRange, now),
      DashboardPeriod.week => dailyStackedBars(range.start, inRange, now),
      DashboardPeriod.month =>
        monthlyStackedBars(range.start, range.end, inRange, now),
      DashboardPeriod.custom => const <ChartBar>[],
    };

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
