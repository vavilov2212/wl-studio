import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/common/utils/badge_utils.dart';
import 'package:worklog_studio/feature/common/utils/chart_bars.dart';
import 'package:worklog_studio/feature/common/utils/chart_scale.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

// Width reserved for left Y-axis labels - must match SideTitles.reservedSize.
const double _kLeftReservedSize = 36.0;

String _formatHours(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)}h';
}

/// Stacked-by-project bar chart with a hover legend overlay, shared by the
/// Dashboard charts card and the Reports charts card.
class StackedBarChart extends StatefulWidget {
  final List<ChartBar> bars;

  const StackedBarChart({super.key, required this.bars});

  @override
  State<StackedBarChart> createState() => _StackedBarChartState();
}

class _StackedBarChartState extends State<StackedBarChart> {
  static const double _overlayWidth = 200;

  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final maxHours = widget.bars
        .map((b) => b.total.inMinutes / 60)
        .fold<double>(0, (max, v) => v > max ? v : max);
    final scale = chartScale(maxHours);
    final n = widget.bars.length;

    return SizedBox(
      height: 220,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartAreaWidth = constraints.maxWidth - _kLeftReservedSize;
          final hovered = _hoveredIndex;

          return MouseRegion(
            onExit: (_) {
              if (mounted) setState(() => _hoveredIndex = null);
            },
            onHover: (event) {
              if (n == 0 || chartAreaWidth <= 0) return;
              final zoneWidth = chartAreaWidth / n;
              final x = event.localPosition.dx - _kLeftReservedSize;
              final i = (x / zoneWidth).floor().clamp(0, n - 1);
              if (i != _hoveredIndex) setState(() => _hoveredIndex = i);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: BarChart(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    _buildBarChartData(
                      chartMaxY: scale.maxY,
                      interval: scale.interval,
                    ),
                  ),
                ),
                if (hovered != null &&
                    hovered < n &&
                    widget.bars[hovered].segments.isNotEmpty)
                  Positioned(
                    left: _overlayLeft(
                      hovered,
                      n,
                      chartAreaWidth,
                      constraints.maxWidth,
                    ),
                    top: 0,
                    child: IgnorePointer(
                      child: _BarLegendOverlay(bar: widget.bars[hovered]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Prefer the right side of the hovered bar; flip to the left near the
  // right edge; always stay inside the chart bounds.
  double _overlayLeft(
    int index,
    int n,
    double chartAreaWidth,
    double totalWidth,
  ) {
    final zoneWidth = chartAreaWidth / n;
    final barCenterX = _kLeftReservedSize + zoneWidth * (index + 0.5);
    var left = barCenterX + 24;
    if (left + _overlayWidth > totalWidth) {
      left = barCenterX - 24 - _overlayWidth;
    }
    return left.clamp(0.0, (totalWidth - _overlayWidth).clamp(0.0, totalWidth));
  }

  BarChartData _buildBarChartData({
    required double chartMaxY,
    required double interval,
  }) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return BarChartData(
      maxY: chartMaxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (_) => FlLine(
          color: palette.border.primary.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value == meta.max) return const SizedBox.shrink();
              final label = value % 1 == 0
                  ? '${value.toInt()}h'
                  : '${value.toStringAsFixed(1)}h';
              return Text(
                label,
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.text.muted,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= widget.bars.length) {
                return const SizedBox.shrink();
              }
              final isActive = index == _hoveredIndex;
              return Padding(
                padding: EdgeInsets.only(top: theme.spacings.xs),
                child: Text(
                  widget.bars[index].label,
                  style: isActive
                      ? theme.commonTextStyles.captionBold.copyWith(
                          color: palette.accent.primary,
                        )
                      : theme.commonTextStyles.caption.copyWith(
                          color: palette.text.muted,
                        ),
                ),
              );
            },
          ),
        ),
      ),
      barGroups: widget.bars.asMap().entries.map((entry) {
        final index = entry.key;
        final bar = entry.value;
        final isHovered = index == _hoveredIndex;
        final items = <BarChartRodStackItem>[];
        var from = 0.0;
        for (final seg in bar.segments) {
          final to = from + seg.duration.inMinutes / 60;
          items.add(BarChartRodStackItem(
            from,
            to,
            seg.id.isEmpty
                ? palette.text.muted
                : BadgeUtils.getBadgeColor(seg.id).$2,
          ));
          from = to;
        }
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: from,
              width: 32,
              borderRadius: BorderRadius.circular(4),
              rodStackItems: items,
              backDrawRodData: BackgroundBarChartRodData(
                show: isHovered,
                toY: chartMaxY,
                color: palette.accent.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _BarLegendOverlay extends StatelessWidget {
  final ChartBar bar;

  const _BarLegendOverlay({required this.bar});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      width: 200,
      padding: EdgeInsets.all(theme.spacings.sm),
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.md.circular,
        border: Border.all(color: palette.border.primary),
        boxShadow: [theme.shadows.md],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bar.label,
                style: theme.commonTextStyles.caption.copyWith(
                  color: palette.text.muted,
                ),
              ),
              Text(
                _formatHours(bar.total),
                style: theme.commonTextStyles.captionBold.copyWith(
                  color: palette.text.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacings.xxs),
          ...bar.segments.map((seg) {
            return Padding(
              padding: EdgeInsets.only(top: theme.spacings.xs),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: seg.id.isEmpty
                          ? palette.text.muted
                          : BadgeUtils.getBadgeColor(seg.id).$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: theme.spacings.sm),
                  Expanded(
                    child: Text(
                      seg.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.commonTextStyles.caption.copyWith(
                        color: palette.text.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacings.sm),
                  Text(
                    _formatHours(seg.duration),
                    style: theme.commonTextStyles.caption.copyWith(
                      color: palette.text.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
