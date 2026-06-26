import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'inline_field_controller.dart';
import 'inline_field.dart';
import 'package:intl/intl.dart';

class DateTimeInlineField extends StatefulWidget {
  final String label;
  final DateTime value;
  final InlineFieldController controller;
  final bool isEditable;
  final ControlSize size;
  final ValueChanged<DateTime> onChanged;

  const DateTimeInlineField({
    super.key,
    required this.label,
    required this.value,
    required this.controller,
    required this.onChanged,
    this.isEditable = true,
    this.size = ControlSize.sm,
  });

  @override
  State<DateTimeInlineField> createState() => _DateTimeInlineFieldState();
}

class DateTimeSegments {
  String year;
  String month;
  String day;
  String hour;
  String minute;
  String second;

  DateTimeSegments({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
  });

  factory DateTimeSegments.fromText(String text) {
    text = text.padRight(19, '_');
    return DateTimeSegments(
      year: text.substring(0, 4),
      month: text.substring(5, 7),
      day: text.substring(8, 10),
      hour: text.substring(11, 13),
      minute: text.substring(14, 16),
      second: text.substring(17, 19),
    );
  }

  void clamp() {
    // Year (allow partial, only normalize when full)
    if (!year.contains('_') && year.length == 4) {
      year = year.padLeft(4, '0');
    }

    // Month
    if (!month.contains('_') && month.length == 2) {
      month = _clamp(month, 1, 12).toString().padLeft(2, '0');
    }

    // Day (basic clamp, no month-specific logic yet)
    if (!day.contains('_') && day.length == 2) {
      day = _clamp(day, 1, 31).toString().padLeft(2, '0');
    }

    // Hour
    if (!hour.contains('_') && hour.length == 2) {
      hour = _clamp(hour, 0, 23).toString().padLeft(2, '0');
    }

    // Minute
    if (!minute.contains('_') && minute.length == 2) {
      minute = _clamp(minute, 0, 59).toString().padLeft(2, '0');
    }

    // Second
    if (!second.contains('_') && second.length == 2) {
      second = _clamp(second, 0, 59).toString().padLeft(2, '0');
    }
  }

  int _clamp(String val, int min, int max) {
    // Remove underscores before parsing
    final cleaned = val.replaceAll('_', '');
    if (cleaned.isEmpty) return min;

    final parsed = int.tryParse(cleaned);
    if (parsed == null) return min;

    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  @override
  String toString() {
    return '$year.$month.$day $hour:$minute:$second';
  }
}

class DateTimeMaskFormatter extends TextInputFormatter {
  static const _mask = '____.__.__ __:__:__';

  static const _slots = [
    0, 1, 2, 3, // year
    5, 6, // month
    8, 9, // day
    11, 12, // hour
    14, 15, // minute
    17, 18, // second
  ];

  bool _isSlot(int i) => _slots.contains(i);

  int _nextSlot(int from) {
    for (final s in _slots) {
      if (s >= from) return s;
    }
    return 19;
  }

  int _prevSlot(int from) {
    for (final s in _slots.reversed) {
      if (s < from) return s;
    }
    return _slots.first;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String oldText = oldValue.text.isEmpty ? _mask : oldValue.text;
    if (newValue.text.isEmpty &&
        oldValue.selection.isCollapsed &&
        newValue.selection.start == 0) {
      return TextEditingValue(
        text: _mask,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    int oldSelStart = oldValue.selection.start;
    int oldSelEnd = oldValue.selection.end;
    if (oldSelStart == -1) oldSelStart = 0;
    if (oldSelEnd == -1) oldSelEnd = 0;
    if (oldSelStart > oldSelEnd) {
      final temp = oldSelStart;
      oldSelStart = oldSelEnd;
      oldSelEnd = temp;
    }

    int newSelStart = newValue.selection.start;
    int newSelEnd = newValue.selection.end;
    if (newSelStart == -1) newSelStart = 0;
    if (newSelEnd == -1) newSelEnd = 0;

    String resultText = oldText;
    int cursor = oldSelStart;

    if (oldSelStart != oldSelEnd) {
      for (int i = oldSelStart; i < oldSelEnd; i++) {
        if (_isSlot(i)) {
          resultText = resultText.replaceRange(i, i + 1, '_');
        }
      }
      cursor = oldSelStart;
    } else if (newValue.text.length < oldValue.text.length) {
      if (newSelStart < oldSelStart) {
        int delPos = _prevSlot(oldSelStart);
        if (delPos < resultText.length && _isSlot(delPos)) {
          resultText = resultText.replaceRange(delPos, delPos + 1, '_');
        }
        cursor = delPos;
      } else {
        int delPos = _nextSlot(oldSelStart);
        if (delPos < resultText.length && _isSlot(delPos)) {
          resultText = resultText.replaceRange(delPos, delPos + 1, '_');
        }
        cursor = oldSelStart;
      }
    }

    String inserted = '';
    if (newValue.text.length >
        oldValue.text.length - (oldSelEnd - oldSelStart)) {
      if (oldSelStart != oldSelEnd) {
        inserted = newValue.text.substring(
          oldSelStart,
          oldSelStart +
              (newValue.text.length -
                  (oldValue.text.length - (oldSelEnd - oldSelStart))),
        );
      } else {
        if (newSelStart > oldSelStart) {
          inserted = newValue.text.substring(oldSelStart, newSelStart);
        } else if (newValue.text.length > oldValue.text.length) {
          inserted = newValue.text.substring(
            oldSelStart,
            oldSelStart + (newValue.text.length - oldValue.text.length),
          );
        }
      }
    }

    inserted = inserted.replaceAll(RegExp(r'[^0-9]'), '');

    if (inserted.isNotEmpty) {
      for (int i = 0; i < inserted.length; i++) {
        int slot = _nextSlot(cursor);
        if (slot < resultText.length) {
          resultText = resultText.replaceRange(slot, slot + 1, inserted[i]);
          cursor = slot + 1;
        }
      }
      cursor = _nextSlot(cursor);
    }

    if (oldSelStart == oldSelEnd &&
        newValue.text.length == oldValue.text.length &&
        inserted.isEmpty) {
      return newValue;
    }

    return TextEditingValue(
      text: resultText,
      selection: TextSelection.collapsed(offset: cursor > 19 ? 19 : cursor),
    );
  }
}

class MaskedTextController extends TextEditingController {
  MaskedTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = context.theme;
    final normalStyle = style?.copyWith(
      color: theme.colorsPalette.text.primary,
    );
    final mutedStyle = style?.copyWith(color: theme.colorsPalette.text.muted);

    final children = <TextSpan>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (i == 4 || i == 7 || i == 10 || i == 13 || i == 16 || char == '_') {
        children.add(TextSpan(text: char, style: mutedStyle));
      } else {
        children.add(TextSpan(text: char, style: normalStyle));
      }
    }

    return TextSpan(style: style, children: children);
  }
}

class _DateTimeInlineFieldState extends State<DateTimeInlineField> {
  late MaskedTextController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = MaskedTextController(
      text: _formatEditValue(widget.value),
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChanged);
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
    widget.controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (widget.controller.isEditing) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();

        // keep existing value, do not overwrite with mask
        final current = _textController.text;
        if (current.isEmpty) {
          _textController.text = _formatEditValue(widget.value);
        }
      }
    } else {
      final formatted = _formatEditValue(widget.value);
      if (_textController.text != formatted) {
        _textController.text = formatted;
      }
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final text = _textController.text;
          if (text.isEmpty) {
            _textController.text = _formatEditValue(widget.value);
          }
          if (_textController.text.length >= 19) {
            _textController.selection = const TextSelection(
              baseOffset: 11,
              extentOffset: 19,
            );
          }
        }
      });
    } else {
      // On blur: normalize + persist value if possible
      final text = _textController.text;

      if (text.length == 19 && !text.contains('_')) {
        try {
          final parsed = DateFormat('yyyy.MM.dd HH:mm:ss').parseStrict(text);

          if (parsed != widget.value) {
            widget.onChanged(parsed);
          }

          // normalize text (clamp)
          final segments = DateTimeSegments.fromText(text);
          segments.clamp();
          _textController.text = segments.toString();
        } catch (_) {}
      } else {
        // restore previous valid value if input incomplete
        _textController.text = _formatEditValue(widget.value);
      }
    }
  }

  void _onTextChanged() {
    final text = _textController.text;

    if (text.length != 19) return;

    final segments = DateTimeSegments.fromText(text);

    // Clamp ONLY fully entered segments (no underscores)
    segments.clamp();
    final clamped = segments.toString();

    if (clamped != text) {
      final selection = _textController.selection;

      _textController.value = _textController.value.copyWith(
        text: clamped,
        selection: TextSelection.collapsed(
          offset: selection.start.clamp(0, clamped.length),
        ),
      );
      return;
    }

    // Only emit valid date when fully filled
    if (!clamped.contains('_')) {
      try {
        final parsed = DateFormat('yyyy.MM.dd HH:mm:ss').parseStrict(clamped);
        if (parsed != widget.value) {
          widget.onChanged(parsed);
        }
      } catch (_) {
        // ignore invalid states
      }
    }
  }

  @override
  void didUpdateWidget(DateTimeInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.controller.isEditing) {
      final formatted = _formatEditValue(widget.value);
      if (_textController.text != formatted) {
        _textController.text = formatted;
      }
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChange);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  String _formatEditValue(DateTime time) {
    return DateFormat('yyyy.MM.dd HH:mm:ss').format(time);
  }

  String _formatDisplayValue(DateTime date) {
    return DateFormat('MMM d, HH:mm:ss').format(date);
  }

  void _onDatePicked(DateTime picked) {
    final newDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      widget.value.hour,
      widget.value.minute,
      widget.value.second,
      widget.value.millisecond,
      widget.value.microsecond,
    );
    if (newDate != widget.value) {
      widget.onChanged(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InlineField(
      label: widget.label,
      value: _formatDisplayValue(widget.value),
      controller: widget.controller,
      isEditable: widget.isEditable,
      size: widget.size,
      trailing: _CalendarPickerButton(
        value: widget.value,
        enabled: widget.isEditable,
        onPicked: _onDatePicked,
      ),
      editWidget: PrimaryInput(
        label: null,
        controller: _textController,
        focusNode: _focusNode,
        hintText: 'yyyy.MM.dd HH:mm:ss',
        autofocus: true,
        inputFormatters: [DateTimeMaskFormatter()],
        suffixWidget: _CalendarPickerButton(
          value: widget.value,
          enabled: widget.isEditable,
          onPicked: _onDatePicked,
        ),
        size: widget.size,
      ),
    );
  }
}

class _CalendarPickerButton extends StatefulWidget {
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onPicked;

  const _CalendarPickerButton({
    required this.value,
    required this.enabled,
    required this.onPicked,
  });

  @override
  State<_CalendarPickerButton> createState() => _CalendarPickerButtonState();
}

class _CalendarPickerButtonState extends State<_CalendarPickerButton> {
  final PopoverController _popoverController = PopoverController();

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return PopoverPrimitive(
      controller: _popoverController,
      onRequestClose: _popoverController.hide,
      contentBuilder: (context) => Container(
        decoration: BoxDecoration(
          color: palette.background.surface,
          borderRadius: theme.radiuses.md.circular,
          border: Border.all(color: palette.border.primary),
          boxShadow: [theme.shadows.md],
        ),
        padding: EdgeInsets.all(theme.spacings.sm),
        child: CalendarPicker(
          selectedDate: widget.value,
          onDateSelected: (date) {
            widget.onPicked(date);
            _popoverController.hide();
          },
        ),
      ),
      trigger: IconButton(
        icon: const Icon(Icons.calendar_today, size: 16),
        color: palette.text.secondary,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        onPressed: widget.enabled ? _popoverController.toggle : null,
      ),
    );
  }
}
