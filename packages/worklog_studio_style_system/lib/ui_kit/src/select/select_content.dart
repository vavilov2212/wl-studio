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

  /// Closes the popover. Used both after a selection (already wrapped into
  /// [onSelect] by the caller) and after a row's action icon is tapped.
  final VoidCallback close;

  const SelectContent({
    super.key,
    required this.searchable,
    required this.searchController,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.searchQuery,
    required this.close,
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
    return _SelectOptionRow<T>(
      option: option,
      isSelected: isSelected,
      size: widget.size,
      onSelect: () => widget.onSelect(option.value),
      onAction: option.onAction == null
          ? null
          : () {
              option.onAction!();
              widget.close();
            },
    );
  }
}

class _SelectOptionRow<T> extends StatefulWidget {
  final SelectOption<T> option;
  final bool isSelected;
  final ControlSize size;
  final VoidCallback onSelect;
  final VoidCallback? onAction;

  const _SelectOptionRow({
    required this.option,
    required this.isSelected,
    required this.size,
    required this.onSelect,
    required this.onAction,
  });

  @override
  State<_SelectOptionRow<T>> createState() => _SelectOptionRowState<T>();
}

class _SelectOptionRowState<T> extends State<_SelectOptionRow<T>> {
  bool _isHovered = false;
  bool _isActionHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final tokens = theme.controlSize(widget.size);
    final option = widget.option;
    final isSelected = widget.isSelected;

    Widget? actionIcon;
    if (widget.onAction != null) {
      final icon = MouseRegion(
        onEnter: (_) => setState(() => _isActionHovered = true),
        onExit: (_) => setState(() => _isActionHovered = false),
        child: InkWell(
          borderRadius: theme.radiuses.sm.circular,
          onTap: widget.onAction,
          child: Container(
            padding: EdgeInsets.all(theme.spacings.xxs),
            decoration: BoxDecoration(
              color: palette.background.surfaceMuted,
              borderRadius: theme.radiuses.sm.circular,
            ),
            child: Icon(
              option.actionIcon ?? Icons.open_in_new,
              size: 14,
              color: palette.text.secondary,
            ),
          ),
        ),
      );
      actionIcon = icon;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onSelect,
        child: Stack(
          children: [
            Container(
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
                  if (isSelected)
                    Icon(
                      Icons.check,
                      size: tokens.iconSize,
                      color: palette.accent.primary,
                    ),
                ],
              ),
            ),
            if (actionIcon != null)
              Positioned(
                top: theme.spacings.xs,
                right: theme.spacings.xs,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1 : 0,
                  duration: const Duration(milliseconds: 20),
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    // Local tooltip bubble drawn directly in this Stack
                    // rather than via the framework Tooltip widget: Tooltip
                    // positions itself through an Overlay-hosted
                    // CompositedTransformFollower, and its target here would
                    // live inside this popover's own custom OverlayEntry —
                    // a combination Flutter's rendering pipeline can't
                    // reliably lay out (reentrant/undeterminable paint
                    // transform). Staying overlay-free avoids that entirely.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (option.actionTooltip != null && _isActionHovered) ...[
                          _ActionTooltipBubble(message: option.actionTooltip!),
                          SizedBox(width: theme.spacings.xs),
                        ],
                        actionIcon,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Minimal, overlay-free tooltip bubble for the action icon. See the
/// usage site above for why the framework [Tooltip] widget can't be used
/// here.
class _ActionTooltipBubble extends StatelessWidget {
  final String message;

  const _ActionTooltipBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.sm,
        vertical: theme.spacings.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.text.primary,
        borderRadius: theme.radiuses.sm.circular,
      ),
      child: Text(
        message,
        style: theme.commonTextStyles.caption.copyWith(
          color: palette.background.surface,
        ),
      ),
    );
  }
}
