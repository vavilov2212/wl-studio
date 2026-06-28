import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';

/// Registers the three global hotkeys (toggle / accept / dismiss) described
/// in the floating-comment-tracker spec, loading any custom bindings the
/// user has saved via [SettingsKeys] and falling back to the documented
/// defaults otherwise.
class HotkeyService {
  final HotkeyRegistrar _registrar;
  final Future<String?> Function(String key) _getSetting;
  final Future<void> Function(String key, String value) _setSetting;
  final Future<void> Function() _onToggle;
  final Future<void> Function() _onAccept;
  final Future<void> Function() _onDismiss;

  HotkeyService({
    required HotkeyRegistrar registrar,
    required Future<String?> Function(String key) getSetting,
    required Future<void> Function(String key, String value) setSetting,
    required Future<void> Function() onToggle,
    required Future<void> Function() onAccept,
    required Future<void> Function() onDismiss,
  })  : _registrar = registrar,
        _getSetting = getSetting,
        _setSetting = setSetting,
        _onToggle = onToggle,
        _onAccept = onAccept,
        _onDismiss = onDismiss;

  static HotKey _defaultHotKey(KeyboardKey key) => HotKey(
        key: key,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );

  /// The documented default hotkey for [settingKey], used both as the
  /// registration fallback and by the settings UI to display "what will
  /// this revert to" without needing a live [HotkeyService] instance.
  static HotKey defaultHotKeyFor(String settingKey) {
    switch (settingKey) {
      case SettingsKeys.toggleHotkey:
        return _defaultHotKey(PhysicalKeyboardKey.keyM);
      case SettingsKeys.acceptHotkey:
        return _defaultHotKey(PhysicalKeyboardKey.enter);
      case SettingsKeys.dismissHotkey:
        return _defaultHotKey(PhysicalKeyboardKey.escape);
      default:
        throw ArgumentError('Unknown hotkey setting key: $settingKey');
    }
  }

  Future<HotKey> _resolveHotKey(String settingKey, HotKey fallback) async {
    final stored = await _getSetting(settingKey);
    if (stored == null) return fallback;
    try {
      return HotKey.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('HotkeyService: failed to parse stored hotkey "$settingKey" - $e');
      return fallback;
    }
  }

  Future<void> init() async {
    await _registerAll();
  }

  Future<void> _registerAll() async {
    final toggle = await _resolveHotKey(
      SettingsKeys.toggleHotkey,
      defaultHotKeyFor(SettingsKeys.toggleHotkey),
    );
    final accept = await _resolveHotKey(
      SettingsKeys.acceptHotkey,
      defaultHotKeyFor(SettingsKeys.acceptHotkey),
    );
    final dismiss = await _resolveHotKey(
      SettingsKeys.dismissHotkey,
      defaultHotKeyFor(SettingsKeys.dismissHotkey),
    );

    await _registrar.register(toggle, onPressed: () => _onToggle());
    await _registrar.register(accept, onPressed: () => _onAccept());
    await _registrar.register(dismiss, onPressed: () => _onDismiss());
  }

  /// Persists [hotKey] under [settingKey] and re-registers all three
  /// hotkeys so the change takes effect immediately.
  Future<void> saveHotkey(String settingKey, HotKey hotKey) async {
    await _setSetting(settingKey, jsonEncode(hotKey.toJson()));
    await _registrar.unregisterAll();
    await _registerAll();
  }

  void dispose() {
    _registrar.unregisterAll();
  }
}
