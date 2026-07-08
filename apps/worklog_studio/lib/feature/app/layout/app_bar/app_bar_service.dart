import 'package:flutter/foundation.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_config.dart';

class AppBarService extends ValueNotifier<AppBarConfig> {
  AppBarService() : super(const AppBarConfig.hidden());

  void set(AppBarConfig config) => value = config;
  void reset() => value = const AppBarConfig.hidden();
}
