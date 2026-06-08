import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';

class EntityMetaInfoRow extends StatelessWidget {
  final BadgeStatus status;
  final String statusLabel;
  final DateTime createdAt;

  const EntityMetaInfoRow({
    super.key,
    required this.status,
    required this.statusLabel,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacings.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StatusBadge(
            status: status,
            label: statusLabel,
          ),
          SizedBox(width: theme.spacings.md),
          Text(
            'Created ${DateFormatter.formatDateTime(createdAt)}',
            style: theme.commonTextStyles.body2.copyWith(
              color: palette.text.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
