import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum BadgeStatus { ready, inProgress, needsReview, done, urgent, logged, active }

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;
  final String label;

  const StatusBadge({required this.status, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    Color backgroundColor;
    Color textColor;

    switch (status) {
      case BadgeStatus.ready:
        backgroundColor = palette.background.surfaceMuted;
        textColor = palette.text.secondary;
        break;
      case BadgeStatus.inProgress:
        backgroundColor = palette.accent.primaryMuted;
        textColor = palette.accent.primary;
        break;
      case BadgeStatus.needsReview:
        backgroundColor = palette.accent.warning.withValues(alpha: 0.12);
        textColor = palette.accent.warning;
        break;
      case BadgeStatus.done:
        backgroundColor = palette.accent.success.withValues(alpha: 0.12);
        textColor = palette.accent.success;
        break;
      case BadgeStatus.urgent:
        backgroundColor = palette.accent.danger.withValues(alpha: 0.12);
        textColor = palette.accent.danger;
        break;
      case BadgeStatus.logged:
        backgroundColor = palette.accent.success.withValues(alpha: 0.10);
        textColor = palette.accent.success;
        break;
      case BadgeStatus.active:
        backgroundColor = palette.accent.primary.withValues(alpha: 0.08);
        textColor = palette.accent.primary;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.sm,
        vertical: theme.spacings.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: theme.radiuses.pill.circular,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.commonTextStyles.caption2Bold.copyWith(
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
