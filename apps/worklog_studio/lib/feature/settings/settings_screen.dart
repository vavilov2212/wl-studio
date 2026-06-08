import 'package:flutter/material.dart';
import 'package:worklog_studio/core/sparkle/sparkle_bridge.dart';
import 'package:worklog_studio_style_system/theme/theme_extension/app_theme_extension.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.spacings.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: theme.commonTextStyles.displayLarge),
          SizedBox(height: theme.spacings.x2l),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await SparkleBridge.checkForUpdates();
                },
                icon: const Icon(Icons.update),
                label: const Text("Check for updates"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
