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
                return SelectOptionRow<T>(
                  option: option,
                  isSelected: isSelected,
                  size: size,
                  onTap: () => onToggle(option.value),
                  trailingIndicator: (selected) {
                    final theme = context.theme;
                    final palette = theme.colorsPalette;
                    final tokens = theme.controlSize(size);
                    return Icon(
                      selected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: tokens.iconSize,
                      color: selected
                          ? palette.accent.primary
                          : palette.text.muted,
                    );
                  },
                );
              },
            ),
    );
  }
}
