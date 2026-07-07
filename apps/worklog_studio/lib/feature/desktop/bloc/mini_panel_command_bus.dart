import 'dart:async';

import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';

/// Standalone broadcast stream for one-shot UI commands sent from the
/// leader window to the mini panel. Kept separate from [MiniTrackerCubit]
/// so the cubit remains a pure state container.
class MiniPanelCommandBus {
  final _controller = StreamController<MiniPanelCommand>.broadcast();

  Stream<MiniPanelCommand> get stream => _controller.stream;

  void emit(MiniPanelCommand command) {
    _controller.add(command);
  }

  void dispose() {
    _controller.close();
  }
}
