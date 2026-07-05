import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/projects_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

class ProjectsSortBar extends StatelessWidget {
  final ProjectsSortField field;
  final SortDirection direction;
  final ValueChanged<ProjectsSortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const ProjectsSortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: ProjectsSortField.name, label: 'Name'),
    SelectOption(value: ProjectsSortField.timeTracked, label: 'Time tracked'),
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
              child: Select<ProjectsSortField>(
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
