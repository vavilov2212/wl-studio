import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:worklog_studio/core/services/idle_monitor/windows_idle_monitor.dart';

WindowsIdleMonitor createWindowsIdleMonitor() {
  return WindowsIdleMonitor(
    getTickCount: win32.GetTickCount,
    getLastInputTick: () {
      final info = calloc<win32.LASTINPUTINFO>();
      info.ref.cbSize = sizeOf<win32.LASTINPUTINFO>();
      win32.GetLastInputInfo(info);
      final tick = info.ref.dwTime;
      calloc.free(info);
      return tick;
    },
  );
}
