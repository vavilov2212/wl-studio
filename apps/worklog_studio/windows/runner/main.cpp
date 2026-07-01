#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <DbgHelp.h>
#include <ShlObj.h>
#include <strsafe.h>

#pragma comment(lib, "DbgHelp.lib")

#include "flutter_window.h"
#include "utils.h"

// Writes a minidump + plain-text sidecar to
// %LOCALAPPDATA%\WorklogStudio\crashes\ on any unhandled native exception.
// The .dmp can be opened in WinDbg or Visual Studio for a full native stack
// trace. The .txt sidecar records the timestamp and exception code so the
// folder is human-scannable without a debugger.
static LONG WINAPI WriteCrashDump(EXCEPTION_POINTERS* ei) {
  WCHAR appData[MAX_PATH];
  if (FAILED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, appData))) {
    return EXCEPTION_EXECUTE_HANDLER;
  }

  WCHAR crashDir[MAX_PATH];
  StringCchPrintfW(crashDir, MAX_PATH, L"%s\\WorklogStudio\\crashes", appData);
  CreateDirectoryW(crashDir, NULL);

  SYSTEMTIME st;
  GetLocalTime(&st);

  // crash_YYYYMMDD_HHMMSS.dmp
  WCHAR dmpPath[MAX_PATH];
  StringCchPrintfW(dmpPath, MAX_PATH,
      L"%s\\crash_%04d%02d%02d_%02d%02d%02d.dmp",
      crashDir, st.wYear, st.wMonth, st.wDay,
      st.wHour, st.wMinute, st.wSecond);

  HANDLE hDmp = CreateFileW(dmpPath, GENERIC_WRITE, 0, NULL,
      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (hDmp != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION mei{};
    mei.ThreadId          = GetCurrentThreadId();
    mei.ExceptionPointers = ei;
    mei.ClientPointers    = FALSE;
    MiniDumpWriteDump(
        GetCurrentProcess(), GetCurrentProcessId(), hDmp,
        static_cast<MINIDUMP_TYPE>(
            MiniDumpWithDataSegs |
            MiniDumpWithHandleData |
            MiniDumpWithThreadInfo),
        &mei, NULL, NULL);
    CloseHandle(hDmp);
  }

  // Plain-text sidecar - readable without a debugger
  WCHAR txtPath[MAX_PATH];
  StringCchPrintfW(txtPath, MAX_PATH,
      L"%s\\crash_%04d%02d%02d_%02d%02d%02d.txt",
      crashDir, st.wYear, st.wMonth, st.wDay,
      st.wHour, st.wMinute, st.wSecond);

  HANDLE hTxt = CreateFileW(txtPath, GENERIC_WRITE, 0, NULL,
      CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (hTxt != INVALID_HANDLE_VALUE) {
    CHAR buf[512];
    DWORD written;
    StringCchPrintfA(buf, 512,
        "Crash at %04d-%02d-%02d %02d:%02d:%02d\r\n"
        "Exception code:    0x%08lX\r\n"
        "Exception address: 0x%p\r\n",
        st.wYear, st.wMonth, st.wDay,
        st.wHour, st.wMinute, st.wSecond,
        ei->ExceptionRecord->ExceptionCode,
        ei->ExceptionRecord->ExceptionAddress);
    WriteFile(hTxt, buf, static_cast<DWORD>(strlen(buf)), &written, NULL);
    CloseHandle(hTxt);
  }

  return EXCEPTION_EXECUTE_HANDLER;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Register before anything else so crashes during init are also captured.
  SetUnhandledExceptionFilter(WriteCrashDump);

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"worklog_studio", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
