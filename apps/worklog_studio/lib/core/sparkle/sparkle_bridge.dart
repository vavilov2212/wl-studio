import 'dart:io';

import 'package:flutter/services.dart';

class SparkleBridge {
  static const _channel = MethodChannel('worklog_studio/updater');

  static Future<void> checkForUpdates() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    await _channel.invokeMethod('checkForUpdates');
  }

  static Future<void> checkSilently() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    await _channel.invokeMethod('checkSilently');
  }

  static Future<String> getVersion() async {
    if (!Platform.isWindows && !Platform.isMacOS) return '';
    return await _channel.invokeMethod('getVersion');
  }
}
