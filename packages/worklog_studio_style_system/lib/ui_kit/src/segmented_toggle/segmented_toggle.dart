import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SegmentedToggleOption<T> {
  final T value;
  final IconData icon;

  const SegmentedToggleOption({required this.value, required this.icon});
}

/// Compact icon-only segmented control for switching between view modes.
/// Sized to align with [ButtonSize.sm] controls.
class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentedToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background.surface,
        borderRadius: theme.radiuses.sm.circular,
        border: Border.all(
          color: palette.border.primary.withValues(alpha: 0.5),
        ),
      ),
      padding: EdgeInsets.all(theme.spacings.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options) ...[
            if (option != options.first) SizedBox(width: theme.spacings.xxs),
            _ToggleButton(
              icon: option.icon,
              isSelected: option.value == value,
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
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final palette = theme.colorsPalette;

    return Material(
      color: isSelected ? palette.background.surfaceMuted : Colors.transparent,
      borderRadius: theme.radiuses.sm.circular,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(theme.spacings.xxs),
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
            size: 20,
            color: isSelected ? palette.text.primary : palette.text.secondary,
          ),
        ),
      ),
    );
  }
}
