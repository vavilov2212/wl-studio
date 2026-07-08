import 'dart:async';

import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/runner/runner.dart' as runner;

FutureOr<void> main(List<String> args) async {
  AppEnvironment.init(
    config: const AppConfig(
      debugOptions: DebugOptions(),
      flavor: Flavor.development,
    ),
  );

  await runner.run(args);
}
