import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// A section separator: a pill-shaped label followed by a horizontal divider line.
/// Mirrors the date-group header style used in the time history table.
class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.md,
            vertical: theme.spacings.xxs,
          ),
          decoration: BoxDecoration(
            color: palette.background.surfaceMuted,
            borderRadius: theme.radiuses.pill.circular,
          ),
          child: Text(
            label,
            style: theme.commonTextStyles.labelSmall.copyWith(
              color: palette.text.secondary,
            ),
          ),
        ),
        SizedBox(width: theme.spacings.sm),
        Expanded(
          child: Divider(height: 1, thickness: 1, color: palette.border.primary),
        ),
      ],
    );
  }
}
