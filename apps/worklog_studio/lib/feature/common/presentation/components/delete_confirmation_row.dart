import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DeleteConfirmationRow extends StatelessWidget {
  final bool isShowing;
  final String entityLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const DeleteConfirmationRow({
    super.key,
    required this.isShowing,
    required this.entityLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: isShowing
          ? Padding(
              key: const ValueKey('delete_confirmation'),
              padding: EdgeInsets.fromLTRB(
                theme.spacings.xl,
                theme.spacings.lg,
                theme.spacings.xl,
                0,
              ),
              child: InfoBar(
                variant: InfoBarVariant.danger,
                title: Text('Delete this $entityLabel?'), // TODO: l10n
                description: const Text(
                  'This action cannot be undone', // TODO: l10n
                ),
                actions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      onTap: onConfirm,
                      title: 'Delete', // TODO: l10n
                      type: ButtonType.danger,
                      size: ButtonSize.sm,
                    ),
                    SizedBox(width: theme.spacings.sm),
                    PrimaryButton(
                      onTap: onCancel,
                      title: 'Cancel', // TODO: l10n
                      type: ButtonType.ghost,
                      size: ButtonSize.sm,
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no_confirmation')),
    );
  }
}
