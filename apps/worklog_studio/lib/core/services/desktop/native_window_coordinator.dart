class NativeWindowCoordinator {
  NativeWindowCoordinator._();

  static final NativeWindowCoordinator instance = NativeWindowCoordinator._();

  // Test-only constructor that returns a fresh (non-singleton) instance.
  factory NativeWindowCoordinator.forTesting() => NativeWindowCoordinator._();

  bool _idleResolutionVisible = false;
  bool _activityWindowVisible = false;
  void Function()? _activityWindowHider;

  // Called by WindowsDesktopService during init to wire up the hide callback.
  void setActivityWindowHider(void Function() hider) {
    _activityWindowHider = hider;
  }

  // WindowsDesktopService calls this whenever NativeActivityWindow visibility changes.
  void setActivityWindowVisible(bool visible) {
    _activityWindowVisible = visible;
  }

  // Called by IdleResolutionWindow before showing itself.
  void idleResolutionWillShow() {
    if (_activityWindowVisible) {
      _activityWindowHider?.call();
    }
    _idleResolutionVisible = true;
  }

  // Called by IdleResolutionWindow after it hides itself.
  void idleResolutionDidHide() {
    _idleResolutionVisible = false;
  }

  // NativeActivityWindow checks this before showing itself.
  bool canActivityWindowShow() => !_idleResolutionVisible;
}
