// This file is kept for backwards-compatibility so that existing import paths
// (`package:worklog_studio/core/services/desktop/desktop_service.dart`) continue
// to resolve without changes across the codebase.
//
// The concrete platform logic has been split into:
//   • macos_desktop_service.dart   — macOS popover + IPC
//   • windows_desktop_service.dart — Windows tray + window_manager
//   • no_op_desktop_service.dart   — stub for web / other platforms
//
// New code should import [IDesktopPlatformService] and obtain an instance via
// [DesktopServiceRegistry.instance] rather than constructing DesktopService()
// directly.

export 'i_desktop_platform_service.dart';
export 'desktop_service_registry.dart';
