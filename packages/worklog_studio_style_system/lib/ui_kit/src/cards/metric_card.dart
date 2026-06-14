import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;
  final bool accent;

  const MetricCard({
    required this.label,
    required this.value,
    this.icon,
    this.accent = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final labelColor = accent ? palette.accent.primary : palette.text.muted;

    return Container(
      padding: EdgeInsets.all(theme.spacings.lg),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.primaryMuted
            : palette.background.surfaceMuted,
        borderRadius: theme.radiuses.md.circular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: labelColor),
                SizedBox(width: theme.spacings.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.commonTextStyles.labelSmall.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacings.sm),
          value,
        ],
      ),
    );
  }
}
