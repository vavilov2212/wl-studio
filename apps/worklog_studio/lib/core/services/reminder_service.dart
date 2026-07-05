import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:worklog_studio/core/services/settings_keys.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';

/// Minimal cancelable-timer interface so [ReminderService] never depends on
/// the concrete, non-extensible `dart:async` `Timer` class directly - tests
/// substitute a recording fake instead of waiting on real time.
abstract interface class CancelableTimer {
  void cancel();
}

class _RealTimer implements CancelableTimer {
  final Timer _timer;
  _RealTimer(this._timer);

  @override
  void cancel() => _timer.cancel();
}

typedef PeriodicTimerFactory = CancelableTimer Function(
  Duration duration,
  void Function() onTick,
);
typedef OneShotTimerFactory = CancelableTimer Function(
  Duration duration,
  void Function() onFire,
);

CancelableTimer _defaultPeriodic(Duration duration, void Function() onTick) =>
    _RealTimer(Timer.periodic(duration, (_) => onTick()));

CancelableTimer _defaultOneShot(Duration duration, void Function() onFire) =>
    _RealTimer(Timer(duration, onFire));

/// Periodically nudges the user to confirm/update the active entry's
/// comment while a time entry is running, by re-opening the popover via
/// [onFire] and auto-dismissing it via [onAutoDismiss] after ~20 seconds if
/// left untouched.
class ReminderService {
  final TimeTrackerBloc _bloc;
  final Future<String?> Function(String key) _getSetting;
  final bool Function() _isPopoverOpen;
  final Future<void> Function() _onFire;
  final Future<void> Function() _onAutoDismiss;
  final PeriodicTimerFactory _periodicTimerFactory;
  final OneShotTimerFactory _oneShotTimerFactory;

  static const autoDismissDelay = Duration(seconds: 20);

  StreamSubscription<TimeTrackerBlocState>? _blocSub;
  CancelableTimer? _reminderTimer;
  CancelableTimer? _autoDismissTimer;
  bool _wasRunning = false;

  ReminderService({
    required TimeTrackerBloc bloc,
    required Future<String?> Function(String key) getSetting,
    required bool Function() isPopoverOpen,
    required Future<void> Function() onFire,
    required Future<void> Function() onAutoDismiss,
    PeriodicTimerFactory periodicTimerFactory = _defaultPeriodic,
    OneShotTimerFactory oneShotTimerFactory = _defaultOneShot,
  })  : _bloc = bloc,
        _getSetting = getSetting,
        _isPopoverOpen = isPopoverOpen,
        _onFire = onFire,
        _onAutoDismiss = onAutoDismiss,
        _periodicTimerFactory = periodicTimerFactory,
        _oneShotTimerFactory = oneShotTimerFactory;

  Future<void> init() async {
    _wasRunning = _bloc.state.isRunning;
    if (_wasRunning) await _startReminderTimer();
    _blocSub = _bloc.stream.listen(_onBlocState);
  }

  Future<void> _onBlocState(TimeTrackerBlocState state) async {
    if (state.isRunning && !_wasRunning) {
      _wasRunning = true;
      await _startReminderTimer();
    } else if (!state.isRunning && _wasRunning) {
      _wasRunning = false;
      _cancelTimers();
    }
  }

  Future<void> _startReminderTimer() async {
    _cancelTimers();
    final raw = await _getSetting(SettingsKeys.reminderIntervalMinutes);
    final minutes = raw != null ? int.tryParse(raw) : null;
    debugPrint('ReminderService: _startReminderTimer raw="$raw" minutes=$minutes');
    if (minutes == null || minutes <= 0) {
      debugPrint('ReminderService: not starting a timer (off or unset)');
      return;
    }
    debugPrint('ReminderService: starting periodic timer for $minutes minute(s)');
    _reminderTimer = _periodicTimerFactory(
      Duration(minutes: minutes),
      () => _fire(),
    );
  }

  /// Re-reads the configured interval and restarts the periodic timer with
  /// it, but only if a session is currently running. If a setting change
  /// happens while idle, the next session start already reads the fresh
  /// value via [_onBlocState], so there's nothing to do here.
  Future<void> reloadInterval() async {
    debugPrint('ReminderService: reloadInterval called, _wasRunning=$_wasRunning');
    if (_wasRunning) {
      await _startReminderTimer();
    }
  }

  void _cancelTimers() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  /// Cancels a pending auto-dismiss timer, if any - call this once the
  /// activity prompt this reminder opened has been explicitly acknowledged
  /// (brought into focus) or closed by the user, so a stale 20s timer never
  /// fires against a window the user has already dealt with. A harmless
  /// no-op when nothing is pending.
  void cancelAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  Future<void> _fire() async {
    if (_isPopoverOpen()) {
      // The user already has the popover open on their own - firing the
      // reminder on top of that would interrupt them and (depending on
      // what the leader's onFire does) risks visibly disrupting a window
      // they're actively looking at. The 20s auto-dismiss only makes sense
      // for a popover *this* reminder opened, so skip scheduling it too.
      debugPrint('ReminderService: popover already open - skipping reminder fire');
      return;
    }
    debugPrint('ReminderService: firing reminder now');
    await _onFire();
    _autoDismissTimer = _oneShotTimerFactory(autoDismissDelay, () {
      _onAutoDismiss();
    });
  }

  void dispose() {
    _blocSub?.cancel();
    _cancelTimers();
  }
}
