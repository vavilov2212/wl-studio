import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_registrar.dart';
import 'package:worklog_studio/core/services/desktop/hotkey_service.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';

class _FakeHotkeyRegistrar implements HotkeyRegistrar {
  final List<HotKey> registered = [];
  final Map<HotKey, void Function()> handlers = {};
  int unregisterAllCalls = 0;

  @override
  Future<void> register(HotKey hotKey, {required void Function() onPressed}) async {
    registered.add(hotKey);
    handlers[hotKey] = onPressed;
  }

  @override
  Future<void> unregisterAll() async {
    unregisterAllCalls++;
    registered.clear();
    handlers.clear();
  }
}

void main() {
  late _FakeHotkeyRegistrar registrar;
  late Map<String, String> store;
  late int toggleCalls;
  late int acceptCalls;
  late int dismissCalls;
  late HotkeyService service;

  setUp(() {
    registrar = _FakeHotkeyRegistrar();
    store = {};
    toggleCalls = 0;
    acceptCalls = 0;
    dismissCalls = 0;
    service = HotkeyService(
      registrar: registrar,
      getSetting: (key) async => store[key],
      setSetting: (key, value) async => store[key] = value,
      onToggle: () async => toggleCalls++,
      onAccept: () async => acceptCalls++,
      onDismiss: () async => dismissCalls++,
    );
  });

  group('HotkeyService.init', () {
    test('registers three default hotkeys when no settings are stored', () async {
      await service.init();

      expect(registrar.registered, hasLength(3));
    });

    test('the registered toggle hotkey invokes onToggle when pressed', () async {
      await service.init();

      final toggleHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyM,
      );
      registrar.handlers[toggleHotKey]!();

      expect(toggleCalls, 1);
      expect(acceptCalls, 0);
      expect(dismissCalls, 0);
    });

    test('the registered accept hotkey invokes onAccept when pressed', () async {
      await service.init();

      final acceptHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyA,
      );
      registrar.handlers[acceptHotKey]!();

      expect(acceptCalls, 1);
    });

    test('the registered dismiss hotkey invokes onDismiss when pressed', () async {
      await service.init();

      final dismissHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyX,
      );
      registrar.handlers[dismissHotKey]!();

      expect(dismissCalls, 1);
    });

    test('uses a stored custom toggle hotkey instead of the default', () async {
      final custom = HotKey(
        key: PhysicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      store[SettingsKeys.toggleHotkey] = jsonEncode(custom.toJson());

      await service.init();

      final toggleHotKey = registrar.registered.firstWhere(
        (h) => h.key == PhysicalKeyboardKey.keyT,
      );
      registrar.handlers[toggleHotKey]!();
      expect(toggleCalls, 1);
    });
  });

  group('HotkeyService.saveHotkey', () {
    test('persists the hotkey and re-registers all three hotkeys', () async {
      await service.init();
      registrar.registered.clear();

      final custom = HotKey(
        key: PhysicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      );
      await service.saveHotkey(SettingsKeys.toggleHotkey, custom);

      expect(store[SettingsKeys.toggleHotkey], jsonEncode(custom.toJson()));
      expect(registrar.registered, hasLength(3));
      expect(registrar.registered.any((h) => h.key == PhysicalKeyboardKey.keyT), isTrue);
    });
  });

  group('HotkeyService.dispose', () {
    test('unregisters everything', () async {
      await service.init();

      service.dispose();

      expect(registrar.unregisterAllCalls, 1);
    });
  });

  group('HotkeyService.defaultHotKeyFor', () {
    test('toggleHotkey defaults to Ctrl+Alt+M', () {
      final hotKey = HotkeyService.defaultHotKeyFor(SettingsKeys.toggleHotkey);

      expect(hotKey.key, PhysicalKeyboardKey.keyM);
      expect(hotKey.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test('acceptHotkey defaults to Ctrl+Alt+A', () {
      final hotKey = HotkeyService.defaultHotKeyFor(SettingsKeys.acceptHotkey);

      expect(hotKey.key, PhysicalKeyboardKey.keyA);
      expect(hotKey.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test('dismissHotkey defaults to Ctrl+Alt+X', () {
      final hotKey = HotkeyService.defaultHotKeyFor(SettingsKeys.dismissHotkey);

      expect(hotKey.key, PhysicalKeyboardKey.keyX);
      expect(hotKey.modifiers, [HotKeyModifier.control, HotKeyModifier.alt]);
    });

    test('throws for an unknown setting key', () {
      expect(
        () => HotkeyService.defaultHotKeyFor('not_a_real_key'),
        throwsArgumentError,
      );
    });
  });
}
