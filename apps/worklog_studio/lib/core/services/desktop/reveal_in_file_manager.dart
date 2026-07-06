import 'dart:io';

import 'package:flutter/foundation.dart';

/// Opens [path] in the OS file manager (Explorer on Windows, Finder on
/// macOS, the default file manager on Linux via `xdg-open`).
///
/// Best-effort convenience action — failures are swallowed since this is
/// never part of a critical flow, just a UI shortcut.
Future<void> revealInFileManager(String path) async {
  if (kIsWeb) return;
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  } catch (_) {
    // Non-critical: the user can still navigate there manually.
  }
}

/// Opens [url] in the default OS browser.
///
/// Best-effort convenience — failures are swallowed since this is never
/// part of a critical flow.
Future<void> openUrl(String url) async {
  if (kIsWeb) return;
  try {
    if (Platform.isWindows) {
      await Process.run('explorer.exe', [url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  } catch (_) {}
}
