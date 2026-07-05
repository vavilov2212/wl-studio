import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

/// Self-contained month calendar grid used inside popovers/dropdowns
/// (date filters, date inline fields). Supports a single selected date or
/// a contiguous range, plus month navigation and a today indicator.
class CalendarPicker extends StatefulWidget {
  final DateTime? selectedDate;
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTimeRange>? onRangeSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const CalendarPicker({
    super.key,
    this.selectedDate,
    this.selectedRange,
    this.onDateSelected,
    this.onRangeSelected,
    this.firstDate,
    this.lastDate,
  }) : assert(
         onDateSelected != null || onRangeSelected != null,
         'Provide onDateSelected for single-date mode or onRangeSelected for range mode',
       );

  @override
  State<CalendarPicker> createState() => _CalendarPickerState();
}

class _CalendarPickerState extends State<CalendarPicker> {
  late DateTime _visibleMonth;
  DateTime? _pendingRangeStart;

  bool get _isRangeMode => widget.onRangeSelected != null;

  @override
  void initState() {
    super.initState();
    final anchor =
        widget.selectedDate ?? widget.selectedRange?.start ?? DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month);
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  bool _isDisabled(DateTime day) {
    final firstDate = widget.firstDate;
    final lastDate = widget.lastDate;
    if (firstDate != null && day.isBefore(firstDate)) return true;
    if (lastDate != null && day.isAfter(lastDate)) return true;
    return false;
  }

  void _handleDayTap(DateTime day) {
    if (_isDisabled(day)) return;

    if (!_isRangeMode) {
      widget.onDateSelected!(day);
      return;
    }

    final pendingStart = _pendingRangeStart;
    if (pendingStart == null) {
      setState(() => _pendingRangeStart = day);
      return;
    }

    final range = day.isBefore(pendingStart)
        ? DateTimeRange(start: day, end: pendingStart)
        : DateTimeRange(start: pendingStart, end: day);
    setState(() => _pendingRangeStart = null);
    widget.onRangeSelected!(range);
  }

  List<DateTime> _buildVisibleDays() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leadingBlanks = firstOfMonth.weekday - DateTime.monday;
    final gridStart = firstOfMonth.subtract(Duration(days: leadingBlanks));
    return List.generate(42, (index) => gridStart.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;
    final days = _buildVisibleDays();
    final today = DateTime.now();
    final rangeStart = _pendingRangeStart ?? widget.selectedRange?.start;
    final rangeEnd = _pendingRangeStart == null
        ? widget.selectedRange?.end
        : null;

    // The grid below is built from fixed-size cells (not Expanded) and the
    // whole widget is wrapped in this fixed width, so it lays out correctly
    // even when hosted in a popover that gives it unbounded width.
    return SizedBox(
      width: _CalendarCell.size * 7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacings.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMM yyyy').format(_visibleMonth),
                    style: theme.commonTextStyles.captionSemiBold.copyWith(
                      color: palette.text.primary,
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_left,
                  onTap: _goToPreviousMonth,
                ),
                SizedBox(width: theme.spacings.xxs),
                _NavButton(icon: Icons.chevron_right, onTap: _goToNextMonth),
              ],
            ),
          ),
          SizedBox(height: theme.spacings.sm),
          Row(
            children: _weekdayLabelsMondayFirst()
                .map(
                  (label) => _CalendarCell(
                    child: Text(
                      label,
                      style: theme.commonTextStyles.caption2.copyWith(
                        color: palette.text.muted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ...List.generate(6, (week) {
            final weekDays = days.sublist(week * 7, week * 7 + 7);
            return Row(
              children: weekDays.map((day) {
                final isCurrentMonth = day.month == _visibleMonth.month;
                final isToday = _isSameDay(day, today);
                final isSelected = _isRangeMode
                    ? _isSameDay(day, _pendingRangeStart)
                    : _isSameDay(day, widget.selectedDate);
                final isRangeEndpoint =
                    _isSameDay(day, rangeStart) || _isSameDay(day, rangeEnd);
                final isInRange =
                    rangeStart != null &&
                    rangeEnd != null &&
                    !day.isBefore(rangeStart) &&
                    !day.isAfter(rangeEnd);

                return _CalendarCell(
                  child: _DayCell(
                    day: day,
                    isCurrentMonth: isCurrentMonth,
                    isToday: isToday,
                    isSelected: isSelected || isRangeEndpoint,
                    isInRange: isInRange,
                    isDisabled: _isDisabled(day),
                    onTap: () => _handleDayTap(day),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static List<String> _weekdayLabelsMondayFirst() =>
      const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? palette.background.surfaceMuted : null,
            borderRadius: theme.radiuses.sm.circular,
          ),
          child: Icon(widget.icon, size: 16, color: palette.text.secondary),
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  static const double size = 36;

  final Widget child;

  const _CalendarCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: Center(child: child));
  }
}

class _DayCell extends StatefulWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isInRange;
  final bool isDisabled;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isInRange,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    Color? background;
    Color textColor;
    Border? border;

    if (widget.isSelected) {
      background = palette.accent.primary;
      textColor = Colors.white;
    } else if (widget.isInRange) {
      background = palette.accent.primaryMuted;
      textColor = palette.text.primary;
    } else if (_isHovered && !widget.isDisabled) {
      background = palette.background.surfaceMuted;
      textColor = palette.text.primary;
    } else {
      textColor = widget.isCurrentMonth
          ? palette.text.primary
          : palette.text.muted;
    }

    if (widget.isToday && !widget.isSelected) {
      border = Border.all(color: palette.accent.primary, width: 1);
    }

    if (widget.isDisabled) {
      textColor = palette.text.muted;
    }

    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Text(
            '${widget.day.day}',
            style: theme.commonTextStyles.caption.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
