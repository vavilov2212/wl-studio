import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_service.dart';

class AppBarNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    // ----------------------------
    // 🧠 EDGE CASE: Nested Navigators
    // If you start using nested navigators (e.g., tab navigation,
    // shell routes or Navigator 2.0 / Router),
    // this observer will *not* receive events for those navigators.
    //
    // In that scenario you will need to either:
    // - register this observer with nested Navigator instances
    // - or implement a Router-aware solution
    //
    // See NavigatorObserver docs:
    // https://api.flutter.dev/flutter/widgets/NavigatorObserver-class.html
    // ----------------------------
    getIt<AppBarService>().reset();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);

    // ----------------------------
    // ⚠ Modal routes or custom transitions (dialogs/sheets)
    // may not trigger this method consistently.
    // Dialogs opened via showDialog() do *not* trigger didPush/didPop
    // on the root navigator:
    //
    //  - showDialog docs:
    //    https://api.flutter.dev/flutter/widgets/showDialog.html
    //
    // To support these cases you may need additional logic
    // to capture overlay dismissals.
    // ----------------------------
    getIt<AppBarService>().reset();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    // ----------------------------
    // 📌 Reset here clears AppBar on push.
    // If multiple routes push without an AppBarConfig on the new route,
    // the AppBar will stay hidden. If you want to preserve a stack of configs,
    // consider maintaining a stack of AppBarConfigs in the service.
    //
    // See Navigator docs:
    // https://api.flutter.dev/flutter/widgets/Navigator-class.html
    // ----------------------------
    getIt<AppBarService>().reset();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    // ----------------------------
    // ❗ Replace semantics differ from pop/push.
    // If the route being replaced contained AppBar state,
    // you may need to re-evaluate how to restore previous configs.
    // ----------------------------
    getIt<AppBarService>().reset();
  }
}
