import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/sort_direction.dart';
import 'package:worklog_studio/domain/tasks_sort.dart';

class TasksSortBar extends StatelessWidget {
  final TasksSortField field;
  final SortDirection direction;
  final ValueChanged<TasksSortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const TasksSortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: TasksSortField.name, label: 'Name'),
    SelectOption(value: TasksSortField.timeTracked, label: 'Time tracked'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: theme.spacings.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              child: Select<TasksSortField>(
                value: field,
                onChanged: (value) {
                  if (value != null) onFieldChanged(value);
                },
                options: _fieldOptions,
                placeholder: 'Sort by',
                size: ControlSize.xs,
              ),
            ),
            SizedBox(width: theme.spacings.sm),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.xs,
              leftIconWidget: Icon(
                direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
              ),
              onTap: () => onDirectionChanged(
                direction == SortDirection.asc ? SortDirection.desc : SortDirection.asc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
