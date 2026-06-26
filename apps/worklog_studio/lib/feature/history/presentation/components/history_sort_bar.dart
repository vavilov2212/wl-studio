import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/domain/history_sort.dart';
import 'package:worklog_studio/domain/sort_direction.dart';

class HistorySortBar extends StatelessWidget {
  final HistorySortField field;
  final SortDirection direction;
  final ValueChanged<HistorySortField> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  const HistorySortBar({
    super.key,
    required this.field,
    required this.direction,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  static const _fieldOptions = [
    SelectOption(value: HistorySortField.date, label: 'Date'),
    SelectOption(value: HistorySortField.duration, label: 'Duration'),
    SelectOption(value: HistorySortField.taskProjectName, label: 'Task & Project'),
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
              child: Select<HistorySortField>(
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
