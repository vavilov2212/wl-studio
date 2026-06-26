import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

import '../combobox/combobox_controller.dart';
import '../select/select_trigger.dart';

class DateRangeButton extends StatefulWidget {
  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;
  final String placeholder;
  final ControlSize size;

  const DateRangeButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Date',
    this.size = ControlSize.sm,
  });

  @override
  State<DateRangeButton> createState() => _DateRangeButtonState();
}

class _DateRangeButtonState extends State<DateRangeButton> {
  final ComboboxController _controller = ComboboxController();
  bool _showCustomCalendar = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onComboboxChange);
  }

  void _onComboboxChange() {
    if (!_controller.isOpen && _showCustomCalendar) {
      setState(() => _showCustomCalendar = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onComboboxChange);
    _controller.dispose();
    super.dispose();
  }

  DateTimeRange _todayRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }

  DateTimeRange _thisWeekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return DateTimeRange(start: weekStart, end: today);
  }

  DateTimeRange _thisMonthRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(today.year, today.month, 1);
    return DateTimeRange(start: monthStart, end: today);
  }

  void _handleCustomRangePicked(DateTimeRange range, VoidCallback close) {
    widget.onChanged(range);
    setState(() => _showCustomCalendar = false);
    close();
  }

  String? get _label {
    final range = widget.value;
    if (range == null) return null;
    final fmt = DateFormat('MMM d');
    final sameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;
    if (sameDay) return fmt.format(range.start);
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Combobox(
      controller: _controller,
      triggerBuilder: (context, open, isOpen) {
        return SelectTrigger(
          label: _label,
          placeholder: widget.placeholder,
          isOpen: isOpen,
          size: widget.size,
        );
      },
      contentBuilder: (context, close) {
        return Container(
          decoration: BoxDecoration(
            color: palette.background.surface,
            borderRadius: theme.radiuses.md.circular,
            border: Border.all(color: palette.border.primary),
            boxShadow: [theme.shadows.md],
          ),
          padding: EdgeInsets.symmetric(
            vertical: theme.spacings.xxs,
            horizontal: _showCustomCalendar ? theme.spacings.sm : 0,
          ),
          child: _showCustomCalendar
              ? CalendarPicker(
                  selectedRange: widget.value,
                  onRangeSelected: (range) =>
                      _handleCustomRangePicked(range, close),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PresetRow(
                      label: 'Today',
                      onTap: () {
                        widget.onChanged(_todayRange());
                        close();
                      },
                    ),
                    _PresetRow(
                      label: 'This week',
                      onTap: () {
                        widget.onChanged(_thisWeekRange());
                        close();
                      },
                    ),
                    _PresetRow(
                      label: 'This month',
                      onTap: () {
                        widget.onChanged(_thisMonthRange());
                        close();
                      },
                    ),
                    _PresetRow(
                      label: 'All time',
                      onTap: () {
                        widget.onChanged(null);
                        close();
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacings.sm,
                      ),
                      child: Divider(height: 1, color: palette.border.primary),
                    ),
                    _PresetRow(
                      label: 'Custom range...',
                      onTap: () =>
                          setState(() => _showCustomCalendar = true),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PresetRow extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetRow({required this.label, required this.onTap});

  @override
  State<_PresetRow> createState() => _PresetRowState();
}

class _PresetRowState extends State<_PresetRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacings.md,
            vertical: theme.spacings.sm,
          ),
          color: _isHovered ? palette.background.surfaceMuted : null,
          child: Text(
            widget.label,
            style: theme.commonTextStyles.body2.copyWith(
              color: palette.text.primary,
            ),
          ),
        ),
      ),
    );
  }
}
