import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:l/l.dart';

/// Appends a timestamped crash entry to the persistent log file and also
/// routes it through the existing [l] logger for debug-mode visibility.
/// Swallows any I/O exception so a logging failure can never itself crash
/// the app. On web the file write is skipped - only [l.e] runs.
///
/// [overrideLogPath] is a test seam - pass a temp-directory path in tests
/// to avoid touching LOCALAPPDATA.
Future<void> logCrash(
  Object error,
  StackTrace stack, {
  String? overrideLogPath,
}) async {
  l.e('Uncaught error: $error', stack);
  if (kIsWeb) return;
  try {
    final path = overrideLogPath ?? _defaultLogPath();
    if (path == null) return;
    final file = File(path);
    await file.parent.create(recursive: true);
    final entry =
        '[${DateTime.now().toIso8601String()}]\n$error\n$stack\n---\n';
    await file.writeAsString(entry, mode: FileMode.append);
  } catch (_) {}
}

String? _defaultLogPath() {
  final appData = Platform.environment['LOCALAPPDATA'];
  if (appData == null) return null;
  return '$appData\\WorklogStudio\\crash.log';
}
