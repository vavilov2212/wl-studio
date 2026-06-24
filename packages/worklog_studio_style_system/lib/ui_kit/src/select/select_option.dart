import 'package:flutter/material.dart';

/// Data model for Select option
class SelectOption<T> {
  final T value;
  final String label;
  final Widget? leading;

  /// Called when the row's small action icon is tapped instead of the row
  /// itself. Closes the popover but does not change the current selection.
  final VoidCallback? onAction;

  /// Icon for the action button. Defaults to [Icons.open_in_new] when
  /// [onAction] is set and this is left null.
  final IconData? actionIcon;

  final String? actionTooltip;

  const SelectOption({
    required this.value,
    required this.label,
    this.leading,
    this.onAction,
    this.actionIcon,
    this.actionTooltip,
  });
}
