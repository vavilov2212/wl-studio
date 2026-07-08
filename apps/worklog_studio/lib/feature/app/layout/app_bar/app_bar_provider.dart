import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';

import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_config.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_service.dart';

class AppBarProvider extends StatelessWidget {
  const AppBarProvider({super.key, required this.config, required this.child});

  final AppBarConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    /* 
     * ⚠ IMPORTANT: This uses postFrameCallback to avoid
     * updating AppBarService during the build phase
     * (see: https://api.flutter.dev/flutter/scheduler/WidgetsBinding/addPostFrameCallback.html).
     * 
     * Edge cases to watch for:
     *
     * 1) If config is asynchronous or depends on delayed data,
     *    you may need to handle this differently — e.g., schedule an update
     *    after data arrives, or integrate with state management.
     *    Otherwise, AppBar may flicker or get stale.
     *
     * 2) For screens with rapid rebuilds (e.g., animations),
     *    this will continuously call set() on the service.
     *    A future improvement could debounce or check for identity
     *    to avoid redundant sets.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<AppBarService>().set(config);
    });
    return child;
  }
}
