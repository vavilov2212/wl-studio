import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SegmentedToggleOption<T> {
  final T value;
  final IconData icon;

  const SegmentedToggleOption({required this.value, required this.icon});
}

/// Compact icon-only segmented control for switching between view modes.
/// Sized to match [ButtonSize.sm] controls (36px); with [compact] it shrinks
/// to match [ButtonSize.xs] controls (28px).
class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentedToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    // Explicit heights mirror the PrimaryButton size constants (sm: 36,
    // xs: 28) so the toggle lines up exactly with neighbouring buttons.
    // Muted track + white selected thumb: the filled track makes the whole
    // box read as the control (a white track on the near-white canvas made
    // it look smaller than solid neighbouring buttons).
    return Container(
      height: compact ? 28 : 36,
      decoration: BoxDecoration(
        color: palette.background.surfaceMuted,
        borderRadius: theme.radiuses.sm.circular,
        border: Border.all(color: palette.border.primary),
      ),
      padding: EdgeInsets.all(theme.spacings.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options) ...[
            if (option != options.first) SizedBox(width: theme.spacings.xxs),
            _ToggleButton(
              icon: option.icon,
              isSelected: option.value == value,
              compact: compact,
              onTap: () => onChanged(option.value),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Material(
      color: isSelected ? palette.background.surface : Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? theme.spacings.xxs : theme.spacings.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(
                    color: palette.border.primary.withValues(alpha: 0.5),
                  )
                : Border.all(color: Colors.transparent),
            borderRadius: theme.radiuses.sm.circular,
          ),
          child: Icon(
            icon,
            size: compact ? 14 : 16,
            color: isSelected ? palette.text.primary : palette.text.secondary,
          ),
        ),
      ),
    );
  }
}
