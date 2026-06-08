import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/resolved_task.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio/feature/common/presentation/components/card_row.dart';
import 'package:worklog_studio/feature/common/presentation/interactive_card.dart';
import 'package:worklog_studio_style_system/theme/colors_palette/colors_palette_entity.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/presentation/components/ws_initial_badge.dart';

class TaskCard extends StatelessWidget {
  final ResolvedTask task;
  final bool isSelected;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    IconData trailingIcon;
    Color trailingIconColor;

    switch (task.status) {
      case TaskStatus.open:
        trailingIcon = Icons.radio_button_unchecked;
        trailingIconColor = palette.text.muted;
        break;
      case TaskStatus.done:
        trailingIcon = Icons.check_circle;
        trailingIconColor = palette.text.secondary;
        break;
      default:
        trailingIcon = Icons.radio_button_unchecked;
        trailingIconColor = palette.text.muted;
        break;
    }

    return InteractiveCard(
      isSelected: isSelected,
      onTap: onTap,
      child: CardRow(
        columns: [
          CardColumn(
            flex: 3,
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final initials = BadgeUtils.getTaskInitials(
                      task.title,
                      task.projectName,
                    );
                    final colors = BadgeUtils.getBadgeColor(task.id);
                    return WsInitialBadge(
                      initials: initials,
                      backgroundColor: colors.$1,
                      textColor: colors.$2,
                    );
                  },
                ),
                SizedBox(width: theme.spacings.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task.title,
                        style: task.status == TaskStatus.done
                            ? theme.commonTextStyles.bodyBold.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: palette.text.secondary,
                                overflow: TextOverflow.ellipsis,
                              )
                            : theme.commonTextStyles.bodyBold.copyWith(
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      Builder(
                        builder: (context) {
                          final isActive = context
                              .select<TimeTrackerBloc, bool>(
                                (bloc) =>
                                    bloc.state.activeEntryOrNull?.taskId ==
                                    task.id,
                              );
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacings.sm,
                                  vertical: theme.spacings.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? palette.accent.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : _getStatusColor(
                                          task.status,
                                          palette,
                                        ).withValues(alpha: 0.1),
                                  borderRadius: theme.radiuses.sm.circular,
                                ),
                                child: Text(
                                  isActive
                                      ? 'RUNNING'
                                      : _getStatusText(task.status),
                                  style: theme.commonTextStyles.caption3Bold
                                      .copyWith(
                                        color: isActive
                                            ? palette.accent.primary
                                            : _getStatusColor(
                                                task.status,
                                                palette,
                                              ),
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ),
                              SizedBox(width: theme.spacings.sm),
                              Expanded(
                                child: Text(
                                  task.projectName,
                                  style: theme.commonTextStyles.caption
                                      .copyWith(
                                        color: palette.text.secondary,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CardColumn(
            flex: 4,
            child: Text(
              task.description.isEmpty ? 'No description' : task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: task.status == TaskStatus.done
                  ? theme.commonTextStyles.caption.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: palette.text.secondary.withValues(alpha: 0.5),
                    )
                  : theme.commonTextStyles.caption.copyWith(
                      color: task.description.isEmpty
                          ? palette.text.secondary.withValues(alpha: 0.5)
                          : palette.text.secondary,
                    ),
            ),
          ),
          CardColumn(
            flex: 1,
            alignment: Alignment.centerRight,
            child: Icon(trailingIcon, color: trailingIconColor, size: 24),
          ),
        ],
      ),
    );
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'OPEN';
      case TaskStatus.done:
        return 'DONE';
      case TaskStatus.archived:
        return 'ARCHIVED';
    }
  }

  Color _getStatusColor(TaskStatus status, ColorsPalette palette) {
    switch (status) {
      case TaskStatus.open:
        return palette.accent.primary;
      case TaskStatus.done:
        return palette.accent.success;
      case TaskStatus.archived:
        return palette.text.secondary;
    }
  }
}
