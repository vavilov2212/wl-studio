// Native window procedure for the Dart-driven GDI mini panel.
//
// The panel window is created and painted from Dart (native_mini_panel.dart),
// but its window procedure cannot be a Dart callback: window messages are
// dispatched by the platform message loop while the Dart isolate is not
// entered, and invoking a Dart NativeCallable there aborts the VM with
// "Cannot invoke native callback outside an isolate".
//
// So the synchronous message handling lives here, in C++, and communicates
// with the Dart side through exported accessors that Dart calls from its
// existing 50 ms poll tick (via DynamicLibrary.executable()):
//  - wheel scrolling accumulates into an atomic delta that Dart drains;
//  - the hand/arrow cursor choice is a flag Dart updates on hover changes;
//  - the OS close button hides the window and raises a flag so Dart can
//    stop polling.

#include <windows.h>

#include <atomic>

namespace {

std::atomic<int> g_wheel_delta{0};
std::atomic<int> g_cursor_hand{0};
std::atomic<int> g_close_requested{0};

}  // namespace

extern "C" {

__declspec(dllexport) LRESULT CALLBACK
MiniPanelWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  switch (msg) {
    case WM_MOUSEWHEEL:
      g_wheel_delta.fetch_add(static_cast<short>(HIWORD(wParam)),
                              std::memory_order_relaxed);
      return 0;
    case WM_SETCURSOR:
      if (LOWORD(lParam) == HTCLIENT &&
          g_cursor_hand.load(std::memory_order_relaxed) != 0) {
        SetCursor(LoadCursorW(nullptr, IDC_HAND));
        return TRUE;
      }
      break;  // arrow via the class cursor
    case WM_CLOSE:
      // Hide instead of destroy so Dart can reuse the window.
      ShowWindow(hwnd, SW_HIDE);
      g_close_requested.store(1, std::memory_order_relaxed);
      return 0;
    default:
      break;
  }
  return DefWindowProcW(hwnd, msg, wParam, lParam);
}

// Returns the accumulated wheel delta since the last call and resets it.
__declspec(dllexport) int MiniPanelTakeWheelDelta() {
  return g_wheel_delta.exchange(0, std::memory_order_relaxed);
}

// hand != 0 shows the hand cursor over the client area, 0 the arrow.
__declspec(dllexport) void MiniPanelSetCursorHand(int hand) {
  g_cursor_hand.store(hand, std::memory_order_relaxed);
}

// Returns 1 (and resets) if the OS close button hid the window.
__declspec(dllexport) int MiniPanelTakeCloseRequested() {
  return g_close_requested.exchange(0, std::memory_order_relaxed);
}

}  // extern "C"
