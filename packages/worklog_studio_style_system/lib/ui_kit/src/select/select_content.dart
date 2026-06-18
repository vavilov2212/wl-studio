import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SelectContent<T> extends StatefulWidget {
  final bool searchable;
  final TextEditingController searchController;
  final List<SelectOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelect;
  final String searchQuery;
  final Widget Function(BuildContext context, String searchQuery)? actionBuilder;
  final Widget Function(BuildContext context, String searchQuery)? emptyBuilder;
  final ControlSize size;

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
    this.size = ControlSize.sm,
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

    final selectedOption = widget.options
        .where((o) => o.value == widget.selectedValue)
        .firstOrNull;

    final filteredOptions = widget.options.where((option) {
      if (!widget.searchable || widget.searchQuery.isEmpty) return true;
      return option.label.toLowerCase().contains(
        widget.searchQuery.toLowerCase(),
      );
    }).toList();

    final filteredWithoutSelected = filteredOptions
        .where((o) => o.value != widget.selectedValue)
        .toList();

    final List<Widget> listItems = [];

    if (hasAction) {
      listItems.add(widget.actionBuilder!(context, widget.searchQuery));
    }

    if (selectedOption != null) {
      listItems.add(
        _buildOptionItem(context, selectedOption, isSelected: true),
      );
    }

    final hasPinnedItems = listItems.isNotEmpty;
    if (hasPinnedItems && filteredWithoutSelected.isNotEmpty) {
      listItems.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacings.sm),
          child: Divider(height: 1, color: palette.border.primary),
        ),
      );
    }

    if (filteredWithoutSelected.isEmpty && !hasPinnedItems) {
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
    final tokens = theme.controlSize(widget.size);

    return InkWell(
      onTap: () => widget.onSelect(option.value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.horizontalPadding,
          vertical: tokens.verticalPadding == 0 ? theme.spacings.sm : tokens.verticalPadding,
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
                style: tokens.textStyle.copyWith(
                  color: isSelected
                      ? palette.accent.primary
                      : palette.text.primary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: tokens.iconSize, color: palette.accent.primary),
          ],
        ),
      ),
    );
  }
}
