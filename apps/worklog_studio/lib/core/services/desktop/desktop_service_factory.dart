import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:worklog_studio/core/services/desktop/i_desktop_platform_service.dart';
import 'package:worklog_studio/core/services/desktop/macos_desktop_service.dart';
import 'package:worklog_studio/core/services/desktop/no_op_desktop_service.dart';
import 'package:worklog_studio/core/services/desktop/windows_desktop_service.dart';

/// Returns the correct [IDesktopPlatformService] for the current platform.
///
/// This is the **single place** in the entire codebase where a
/// `Platform.isMacOS / isWindows` branch is needed for desktop service
/// resolution. Every other call site uses the interface only.
IDesktopPlatformService createDesktopService() {
  if (kIsWeb) return NoOpDesktopService();
  if (Platform.isMacOS) return MacOSDesktopService();
  if (Platform.isWindows) return WindowsDesktopService();
  return NoOpDesktopService();
}
