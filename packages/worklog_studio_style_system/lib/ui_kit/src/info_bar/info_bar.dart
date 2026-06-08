import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

enum InfoBarVariant { info, success, warning, danger }

enum InfoBarStyle { filled, outline }

class InfoBar extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? description;
  final Widget? actions;
  final InfoBarVariant variant;
  final InfoBarStyle style;

  const InfoBar({
    super.key,
    this.leading,
    required this.title,
    this.description,
    this.actions,
    this.variant = InfoBarVariant.info,
    this.style = InfoBarStyle.filled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    Color baseColor;
    switch (variant) {
      case InfoBarVariant.info:
        baseColor = palette.accent.primary;
        break;
      case InfoBarVariant.success:
        baseColor = palette.accent.success;
        break;
      case InfoBarVariant.warning:
        baseColor = palette.accent.warning;
        break;
      case InfoBarVariant.danger:
        baseColor = palette.accent.danger;
        break;
    }

    final backgroundColor = style == InfoBarStyle.filled
        ? (variant == InfoBarVariant.info
              ? palette.accent.primaryMuted
              : baseColor.withValues(alpha: 0.12))
        : palette.background.surface;

    final borderColor = style == InfoBarStyle.outline
        ? baseColor.withValues(alpha: 0.4)
        : baseColor.withValues(alpha: 0.1);

    return Container(
      padding: EdgeInsets.all(theme.spacings.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: baseColor, size: 20),
              child: leading!,
            ),
            SizedBox(width: theme.spacings.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: theme.commonTextStyles.body2Bold.copyWith(
                    color: palette.text.primary,
                  ),
                  child: title,
                ),
                if (description != null) ...[
                  SizedBox(height: theme.spacings.xxs),
                  DefaultTextStyle(
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.secondary,
                    ),
                    child: description!,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...[
            SizedBox(width: theme.spacings.md),
            Flexible(child: actions!),
          ],
        ],
      ),
    );
  }
}
