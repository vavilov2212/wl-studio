import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import 'select_option.dart';

class SelectContent<T> extends StatefulWidget {
  final bool searchable;
  final TextEditingController searchController;
  final List<SelectOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelect;
  final String searchQuery;
  final Widget Function(BuildContext context, String searchQuery)?
  actionBuilder;
  final Widget Function(BuildContext context, String searchQuery)? emptyBuilder;

  const SelectContent({
    super.key,
    required this.searchable,
    required this.searchController,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.searchQuery,
    this.actionBuilder,
    this.emptyBuilder,
  });

  @override
  State<SelectContent<T>> createState() => _SelectContentState<T>();
}

class _SelectContentState<T> extends State<SelectContent<T>> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.searchable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    final hasAction = widget.actionBuilder != null;

    // 1. Identify the selected option from ALL options
    final selectedOption = widget.options
        .where((o) => o.value == widget.selectedValue)
        .firstOrNull;

    // 2. Filter options based on search query
    final filteredOptions = widget.options.where((option) {
      if (!widget.searchable || widget.searchQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(
        widget.searchQuery.toLowerCase(),
      );
    }).toList();

    // 3. Remove selected option from filtered results to avoid duplication
    final filteredWithoutSelected = filteredOptions
        .where((o) => o.value != widget.selectedValue)
        .toList();

    // 4. Explicitly compose the list items
    final List<Widget> listItems = [];

    // A. Action Item (Always at the top)
    if (hasAction) {
      listItems.add(widget.actionBuilder!(context, widget.searchQuery));
    }

    // B. Selected Item (Always visible, pinned to top)
    if (selectedOption != null) {
      listItems.add(
        _buildOptionItem(context, selectedOption, isSelected: true),
      );
    }

    // C. Divider (Separate pinned items from scrollable results)
    final hasPinnedItems = listItems.isNotEmpty;
    if (hasPinnedItems && filteredWithoutSelected.isNotEmpty) {
      listItems.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
          child: Divider(height: 1, color: palette.border.primary),
        ),
      );
    }

    // D. Filtered Results or Empty State
    if (filteredWithoutSelected.isEmpty && !hasPinnedItems) {
      // Only show empty state if there are no pinned items and no results
      listItems.add(
        Padding(
          padding: EdgeInsets.all(theme.spacings.lg),
          child: widget.emptyBuilder != null
              ? widget.emptyBuilder!(context, widget.searchQuery)
              : Text(
                  'No results found',
                  style: theme.commonTextStyles.body.copyWith(
                    color: palette.text.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
        ),
      );
    } else {
      // Add the remaining filtered options
      listItems.addAll(
        filteredWithoutSelected.map(
          (option) => _buildOptionItem(context, option, isSelected: false),
        ),
      );
    }

    return Container(
      width: 240,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: listItems.length,
        itemBuilder: (context, index) => listItems[index],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    SelectOption<T> option, {
    required bool isSelected,
  }) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return InkWell(
      onTap: () => widget.onSelect(option.value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.md,
          vertical: theme.spacings.md,
        ),
        color: isSelected
            ? palette.accent.primary.withValues(alpha: 0.08)
            : null,
        child: Row(
          children: [
            if (option.leading != null) ...[
              option.leading!,
              SizedBox(width: theme.spacings.sm),
            ],
            Expanded(
              child: Text(
                option.label,
                style: theme.commonTextStyles.body.copyWith(
                  color: isSelected
                      ? palette.accent.primary
                      : palette.text.primary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 16, color: palette.accent.primary),
          ],
        ),
      ),
    );
  }
}
