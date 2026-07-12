import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class WsGroupedTableColumn<G, I> {
  final String title;
  final Widget Function(BuildContext context, G group) groupCellBuilder;
  final Widget Function(BuildContext context, G group, I item) itemCellBuilder;
  final int flex;
  final double? fixedWidth;
  final Alignment alignment;

  const WsGroupedTableColumn({
    required this.title,
    required this.groupCellBuilder,
    required this.itemCellBuilder,
    this.flex = 1,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
  });
}

class WsGroupedTable<G, I> extends StatefulWidget {
  final List<WsGroupedTableColumn<G, I>> columns;
  final List<G> groups;
  final List<I> Function(G group) itemsOf;
  final Key Function(G group) groupKeyBuilder;
  final Key Function(G group, I item) itemKeyBuilder;
  final Widget Function(BuildContext context)? totalRowBuilder;
  final bool initiallyExpanded;
  final bool showHeader;

  const WsGroupedTable({
    super.key,
    required this.columns,
    required this.groups,
    required this.itemsOf,
    required this.groupKeyBuilder,
    required this.itemKeyBuilder,
    this.totalRowBuilder,
    this.initiallyExpanded = true,
    this.showHeader = true,
  });

  @override
  State<WsGroupedTable<G, I>> createState() => _WsGroupedTableState<G, I>();
}

class _WsGroupedTableState<G, I> extends State<WsGroupedTable<G, I>> {
  final Set<Key> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) {
      _expandedGroups.addAll(
        widget.groups.map((g) => widget.groupKeyBuilder(g)),
      );
    }
  }

  @override
  void didUpdateWidget(WsGroupedTable<G, I> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_groupsUnchanged(oldWidget.groups, widget.groups)) {
      _expandedGroups.clear();
      if (widget.initiallyExpanded) {
        _expandedGroups.addAll(
          widget.groups.map((g) => widget.groupKeyBuilder(g)),
        );
      }
    }
  }

  bool _groupsUnchanged(List<G> oldGroups, List<G> newGroups) {
    if (oldGroups.length != newGroups.length) return false;
    for (var i = 0; i < newGroups.length; i++) {
      if (widget.groupKeyBuilder(oldGroups[i]) !=
          widget.groupKeyBuilder(newGroups[i])) return false;
    }
    return true;
  }

  void _toggleGroup(Key key) {
    setState(() {
      if (_expandedGroups.contains(key)) {
        _expandedGroups.remove(key);
      } else {
        _expandedGroups.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final borderColor = palette.border.primary.withValues(alpha: 0.4);

    final List<Widget> rows = [];

    for (var gi = 0; gi < widget.groups.length; gi++) {
      final group = widget.groups[gi];
      final gKey = widget.groupKeyBuilder(group);
      final isExpanded = _expandedGroups.contains(gKey);
      final items = widget.itemsOf(group);

      rows.add(_GroupRow<G, I>(
        group: group,
        columns: widget.columns,
        isExpanded: isExpanded,
        onToggle: () => _toggleGroup(gKey),
      ));

      if (isExpanded) {
        for (final item in items) {
          rows.add(_ItemRow<G, I>(
            key: widget.itemKeyBuilder(group, item),
            group: group,
            item: item,
            columns: widget.columns,
          ));
        }
      }

      final isLastGroup = gi == widget.groups.length - 1;
      if (!isLastGroup || widget.totalRowBuilder != null) {
        rows.add(Divider(height: 1, thickness: 1, color: borderColor));
      }
    }

    if (widget.totalRowBuilder != null) {
      rows.add(widget.totalRowBuilder!(context));
    }

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
          children: [
            if (widget.showHeader) _buildHeader(context, borderColor),
            if (widget.groups.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No data', // TODO: l10n
                    style: theme.commonTextStyles.body2.copyWith(
                      color: palette.text.muted,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(children: rows),
              ),
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
        children: widget.columns.asMap().entries.map((entry) {
          final col = entry.value;
          final isLast = entry.key == widget.columns.length - 1;
          final cell = Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : theme.spacings.md),
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
          );
          if (col.fixedWidth != null) {
            return SizedBox(width: col.fixedWidth, child: cell);
          }
          return Expanded(flex: col.flex, child: cell);
        }).toList(),
      ),
    );
  }
}

class _GroupRow<G, I> extends StatefulWidget {
  final G group;
  final List<WsGroupedTableColumn<G, I>> columns;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _GroupRow({
    required this.group,
    required this.columns,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_GroupRow<G, I>> createState() => _GroupRowState<G, I>();
}

class _GroupRowState<G, I> extends State<_GroupRow<G, I>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 40,
      child: Container(
        color: _isHovered
            ? palette.background.surfaceMuted
            : palette.background.surface,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onToggle,
            onHover: (val) => setState(() => _isHovered = val),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
              child: Row(
                children: widget.columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final col = entry.value;
                  final isFirst = idx == 0;
                  final isLast = idx == widget.columns.length - 1;

                  Widget cell;
                  if (isFirst) {
                    // First column: chevron + content side by side.
                    // Avoid Align wrapper here - it gives unbounded width to
                    // its child, breaking Expanded inside.
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: DefaultTextStyle(
                        style: theme.commonTextStyles.body2Bold.copyWith(
                          color: palette.text.primary,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.isExpanded
                                  ? Icons.expand_more_rounded
                                  : Icons.chevron_right_rounded,
                              size: 16,
                              color: palette.text.secondary,
                            ),
                            SizedBox(width: theme.spacings.xxs),
                            Expanded(
                              child: col.groupCellBuilder(context, widget.group),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: Align(
                        alignment: col.alignment,
                        child: DefaultTextStyle(
                          style: theme.commonTextStyles.body2Bold.copyWith(
                            color: palette.text.primary,
                          ),
                          child: col.groupCellBuilder(context, widget.group),
                        ),
                      ),
                    );
                  }

                  if (col.fixedWidth != null) {
                    return SizedBox(width: col.fixedWidth, child: cell);
                  }
                  return Expanded(flex: col.flex, child: cell);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow<G, I> extends StatefulWidget {
  final G group;
  final I item;
  final List<WsGroupedTableColumn<G, I>> columns;

  const _ItemRow({
    super.key,
    required this.group,
    required this.item,
    required this.columns,
  });

  @override
  State<_ItemRow<G, I>> createState() => _ItemRowState<G, I>();
}

class _ItemRowState<G, I> extends State<_ItemRow<G, I>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return SizedBox(
      height: 36,
      child: Container(
        color: _isHovered
            ? palette.background.surfaceMuted.withValues(alpha: 0.5)
            : palette.background.canvas,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null,
            onHover: (val) => setState(() => _isHovered = val),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
              child: Row(
                children: widget.columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final col = entry.value;
                  final isFirst = idx == 0;
                  final isLast = idx == widget.columns.length - 1;

                  Widget cell;
                  if (isFirst) {
                    // Indent item rows under their group.
                    cell = Padding(
                      padding: EdgeInsets.only(
                        left: theme.spacings.x2l,
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: DefaultTextStyle(
                        style: theme.commonTextStyles.body2.copyWith(
                          color: palette.text.secondary,
                        ),
                        child: col.itemCellBuilder(
                            context, widget.group, widget.item),
                      ),
                    );
                  } else {
                    cell = Padding(
                      padding: EdgeInsets.only(
                        right: isLast ? 0 : theme.spacings.md,
                      ),
                      child: Align(
                        alignment: col.alignment,
                        child: DefaultTextStyle(
                          style: theme.commonTextStyles.body2.copyWith(
                            color: palette.text.secondary,
                          ),
                          child: col.itemCellBuilder(
                              context, widget.group, widget.item),
                        ),
                      ),
                    );
                  }

                  if (col.fixedWidth != null) {
                    return SizedBox(width: col.fixedWidth, child: cell);
                  }
                  return Expanded(flex: col.flex, child: cell);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
