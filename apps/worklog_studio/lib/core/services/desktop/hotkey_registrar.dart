import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Thin seam between [HotkeyService] and the `hotkey_manager` package.
///
/// `hotkey_manager`'s real registration goes through a native platform
/// channel that cannot run inside `flutter_test`. Tests supply a fake
/// implementation instead of this default, real one.
abstract interface class HotkeyRegistrar {
  Future<void> register(HotKey hotKey, {required void Function() onPressed});
  Future<void> unregisterAll();
}

/// Default [HotkeyRegistrar] backed by the real `hotkey_manager` package.
class HotkeyManagerRegistrar implements HotkeyRegistrar {
  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async {
    debugPrint('HotkeyManagerRegistrar: registering ${hotKey.debugName}');
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (pressed) {
          debugPrint('HotkeyManagerRegistrar: key pressed - ${pressed.debugName}');
          onPressed();
        },
      );
      debugPrint('HotkeyManagerRegistrar: registered ${hotKey.debugName}');
    } catch (e) {
      debugPrint('HotkeyManagerRegistrar: FAILED to register ${hotKey.debugName} - $e');
    }
  }

  @override
  Future<void> unregisterAll() => hotKeyManager.unregisterAll();
}
