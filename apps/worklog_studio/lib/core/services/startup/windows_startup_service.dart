import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:worklog_studio/core/services/startup/startup_service.dart';

const _kValueName = 'WorklogStudio';

class WindowsStartupService implements StartupService {
  static const _kRunKey =
      r'Software\Microsoft\Windows\CurrentVersion\Run';

  @override
  Future<void> enable() async {
    final exePath = _getExePath();
    if (exePath == null) return;
    _writeRunValue(exePath);
  }

  @override
  Future<void> disable() async {
    _deleteRunValue();
  }

  @override
  Future<bool> isEnabled() async {
    return _readRunValue() != null;
  }

  String? _getExePath() {
    final buf = win32.wsalloc(win32.MAX_PATH);
    try {
      final len = win32.GetModuleFileName(0, buf, win32.MAX_PATH);
      if (len == 0) return null;
      return buf.toDartString();
    } finally {
      calloc.free(buf);
    }
  }

  void _writeRunValue(String exePath) {
    final quotedPath = '"$exePath"'; // wrap in double-quotes for paths with spaces
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_SET_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return;
      final name = _kValueName.toNativeUtf16();
      final value = quotedPath.toNativeUtf16();
      try {
        win32.RegSetValueEx(
          hKey.value,
          name,
          0,
          win32.REG_SZ,
          value.cast(),
          (quotedPath.length + 1) * 2,
        );
      } finally {
        calloc.free(name);
        calloc.free(value);
      }
      win32.RegCloseKey(hKey.value);
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }

  void _deleteRunValue() {
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_SET_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return;
      final name = _kValueName.toNativeUtf16();
      try {
        win32.RegDeleteValue(hKey.value, name);
      } finally {
        calloc.free(name);
      }
      win32.RegCloseKey(hKey.value);
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }

  String? _readRunValue() {
    final hKey = calloc<win32.HKEY>();
    final keyPath = _kRunKey.toNativeUtf16();
    try {
      final res = win32.RegOpenKeyEx(
        win32.HKEY_CURRENT_USER,
        keyPath,
        0,
        win32.KEY_QUERY_VALUE,
        hKey,
      );
      if (res != win32.ERROR_SUCCESS) return null;
      final name = _kValueName.toNativeUtf16();
      final size = calloc<win32.DWORD>()..value = win32.MAX_PATH * 2;
      final buf = win32.wsalloc(win32.MAX_PATH);
      try {
        final qRes = win32.RegQueryValueEx(
          hKey.value,
          name,
          nullptr,
          nullptr,
          buf.cast(),
          size,
        );
        win32.RegCloseKey(hKey.value);
        if (qRes != win32.ERROR_SUCCESS) return null;
        return buf.toDartString();
      } finally {
        calloc.free(name);
        calloc.free(size);
        calloc.free(buf);
      }
    } finally {
      calloc.free(hKey);
      calloc.free(keyPath);
    }
  }
}
