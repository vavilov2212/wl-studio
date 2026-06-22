import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MultiSelectContent<T> extends StatelessWidget {
  final bool searchable;
  final List<SelectOption<T>> options;
  final List<T> selectedValues;
  final ValueChanged<T> onToggle;
  final String searchQuery;
  final ControlSize size;

  const MultiSelectContent({
    super.key,
    required this.searchable,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    required this.searchQuery,
    this.size = ControlSize.sm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final filteredOptions = options.where((option) {
      if (!searchable || searchQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: filteredOptions.isEmpty
          ? Padding(
              padding: EdgeInsets.all(theme.spacings.lg),
              child: Text(
                'No results found',
                style: theme.commonTextStyles.body.copyWith(
                  color: palette.text.muted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: filteredOptions.length,
              itemBuilder: (context, index) {
                final option = filteredOptions[index];
                final isSelected = selectedValues.contains(option.value);
                return _MultiSelectOptionRow<T>(
                  option: option,
                  isSelected: isSelected,
                  size: size,
                  onTap: () => onToggle(option.value),
                );
              },
            ),
    );
  }
}

class _MultiSelectOptionRow<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final ControlSize size;
  final VoidCallback onTap;

  const _MultiSelectOptionRow({
    required this.option,
    required this.isSelected,
    required this.size,
    required this.onTap,
  });

  @override
  State<_MultiSelectOptionRow<T>> createState() =>
      _MultiSelectOptionRowState<T>();
}

class _MultiSelectOptionRowState<T> extends State<_MultiSelectOptionRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);

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
          color: _isHovered ? palette.background.surfaceMuted : null,
          child: Row(
            children: [
              Icon(
                widget.isSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: tokens.iconSize,
                color: widget.isSelected
                    ? palette.accent.primary
                    : palette.text.muted,
              ),
              SizedBox(width: theme.spacings.sm),
              if (widget.option.leading != null) ...[
                widget.option.leading!,
                SizedBox(width: theme.spacings.sm),
              ],
              Expanded(
                child: Text(
                  widget.option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.textStyle.copyWith(
                    color: widget.isSelected
                        ? palette.text.primary
                        : palette.text.secondary,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
