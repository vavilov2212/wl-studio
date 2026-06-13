import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class WsTableColumn<T> {
  final String title;
  final Widget Function(BuildContext context, T item, bool isHovered) builder;
  final int flex;
  final Alignment alignment;

  const WsTableColumn({
    required this.title,
    required this.builder,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
}

class WsTable<T> extends StatelessWidget {
  final List<WsTableColumn<T>> columns;
  final List<T> data;
  final bool showHeader;
  final T? selectedItem;
  final ValueChanged<T>? onRowTap;
  final bool Function(T item, T? selectedItem)? isSelected;

  const WsTable({
    super.key,
    required this.columns,
    required this.data,
    this.showHeader = true,
    this.selectedItem,
    this.onRowTap,
    this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty && !showHeader) return const SizedBox.shrink();

    final theme = context.theme;
    final palette = theme.colorsPalette;
    final borderColor = palette.border.primary.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: borderColor),
        boxShadow: [theme.shadows.sm],
      ),
      child: ClipRRect(
        borderRadius: theme.radiuses.md.circular,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHeader) _buildHeader(context, borderColor),
            ...data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final selected = isSelected != null
                  ? isSelected!(item, selectedItem)
                  : item == selectedItem;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WsTableRow<T>(
                    item: item,
                    columns: columns,
                    isSelected: selected,
                    onTap: onRowTap != null ? () => onRowTap!(item) : null,
                  ),
                  if (index < data.length - 1)
                    Divider(height: 1, thickness: 1, color: borderColor),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color borderColor) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacings.lg,
        vertical: theme.spacings.xxs,
      ),
      child: Row(
        children: columns.asMap().entries.map((entry) {
          final col = entry.value;
          return Expanded(
            flex: col.flex,
            child: Padding(
              padding: EdgeInsets.only(right: theme.spacings.xl),
              child: Align(
                alignment: col.alignment,
                child: Text(
                  col.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.commonTextStyles.labelSmall.copyWith(
                    color: palette.text.muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WsTableRow<T> extends StatefulWidget {
  final T item;
  final List<WsTableColumn<T>> columns;
  final bool isSelected;
  final VoidCallback? onTap;

  const _WsTableRow({
    required this.item,
    required this.columns,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<_WsTableRow<T>> createState() => _WsTableRowState<T>();
}

class _WsTableRowState<T> extends State<_WsTableRow<T>> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    Color backgroundColor = Colors.transparent;

    if (widget.isSelected) {
      backgroundColor = palette.accent.primary.withValues(alpha: 0.1);
    } else if (_isPressed) {
      backgroundColor = palette.background.surfaceMuted;
    } else if (_isHovered) {
      backgroundColor = palette.background.surfaceMuted.withValues(alpha: 0.5);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        // Borders are handled by the parent container and dividers
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (val) => setState(() => _isHovered = val),
          onHighlightChanged: (val) => setState(() => _isPressed = val),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacings.lg,
              vertical: theme.spacings.lg,
            ),
            child: Row(
              children: widget.columns.asMap().entries.map((entry) {
                final col = entry.value;
                return Expanded(
                  flex: col.flex,
                  child: Padding(
                    padding: EdgeInsets.only(right: theme.spacings.md),
                    child: Align(
                      alignment: col.alignment,
                      child: col.builder(context, widget.item, _isHovered),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
