import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Shared row layout for [Select] and [MultiSelect] dropdown items: hover
/// highlight, selected-row tint, leading [SelectOption.leading] icon, label,
/// and a trailing indicator slot. Select passes a checkmark-when-selected
/// builder; MultiSelect passes an always-visible checkbox builder — that is
/// the only visual difference between the two widgets' rows.
class SelectOptionRow<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final ControlSize size;
  final VoidCallback onTap;
  final Widget Function(bool isSelected) trailingIndicator;

  const SelectOptionRow({
    super.key,
    required this.option,
    required this.isSelected,
    required this.size,
    required this.onTap,
    required this.trailingIndicator,
  });

  @override
  State<SelectOptionRow<T>> createState() => _SelectOptionRowState<T>();
}

class _SelectOptionRowState<T> extends State<SelectOptionRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);
    final option = widget.option;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.horizontalPadding,
            vertical: tokens.verticalPadding == 0
                ? theme.spacings.sm
                : tokens.verticalPadding,
          ),
          color: isSelected
              ? palette.accent.primary.withValues(alpha: 0.08)
              : (_isHovered ? palette.background.surfaceMuted : null),
          child: Row(
            children: [
              if (option.leading != null) ...[
                option.leading!,
                SizedBox(width: theme.spacings.sm),
              ],
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: tokens.textStyle.copyWith(
                    color: isSelected
                        ? palette.accent.primary
                        : palette.text.primary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              widget.trailingIndicator(isSelected),
            ],
          ),
        ),
      ),
    );
  }
}
