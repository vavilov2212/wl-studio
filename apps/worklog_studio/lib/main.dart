import 'package:flutter/widgets.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/core/sparkle/sparkle_bridge.dart';

import 'runner/runner.dart' as runner;

void main(List<String> args) async {
  AppEnvironment.init(config: const AppConfig(flavor: Flavor.production));

  // Schedule a background update check after the first frame so the Flutter
  // engine and platform channel are fully ready. Errors are swallowed -
  // a failed check must never crash the app.
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SparkleBridge.checkSilently().catchError((_) {});
  });

  await runner.run(args);
}
