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
    // Progress bars are relative to the busiest project (it shows a full
    // bar); the share of the grand total is spelled out next to the hours.
    final maxGroupMinutes = data.projectGroups.fold<int>(
      0,
      (max, g) =>
          g.totalDuration.inMinutes > max ? g.totalDuration.inMinutes : max,
    );

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
          groupCellBuilder: (ctx, group) => _HoursCell(
            duration: group.totalDuration,
            percentOfTotal: group.percentOfTotal,
          ),
          itemCellBuilder: (ctx, group, item) => _HoursCell(
            duration: item.duration,
            percentOfTotal: item.percentOfTotal,
          ),
          flex: 1,
          alignment: Alignment.centerRight,
        ),
        WsGroupedTableColumn<ReportsProjectGroup, ReportsTaskRow>(
          title: 'Progress', // TODO: l10n
          groupCellBuilder: (ctx, group) => _ProgressBar(
            value: maxGroupMinutes == 0
                ? 0
                : group.totalDuration.inMinutes / maxGroupMinutes,
            color: group.projectId.isEmpty
                ? ctx.theme.colorsPalette.text.muted
                : BadgeUtils.getBadgeColor(group.projectId).$2,
          ),
          itemCellBuilder: (ctx, group, item) => _ProgressBar(
            value: maxGroupMinutes == 0
                ? 0
                : item.duration.inMinutes / maxGroupMinutes,
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

class _HoursCell extends StatelessWidget {
  final Duration duration;
  final double percentOfTotal;

  const _HoursCell({required this.duration, required this.percentOfTotal});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(DateFormatter.formatDurationHm(duration)),
        SizedBox(width: theme.spacings.xxs),
        Text(
          '${(percentOfTotal * 100).round()}%',
          style: theme.commonTextStyles.caption.copyWith(
            color: palette.text.muted,
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
      height: 12,
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
            child: Padding(
              padding: EdgeInsets.only(right: theme.spacings.md),
              child: Text(
                'Total', // TODO: l10n
                style: theme.commonTextStyles.body2Bold.copyWith(
                  color: palette.text.primary,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(right: theme.spacings.md),
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
          ),
          const Expanded(flex: 2, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
