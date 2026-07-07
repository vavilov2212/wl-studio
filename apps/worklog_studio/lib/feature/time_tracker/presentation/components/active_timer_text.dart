import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio/feature/time_tracker/bloc/time_tracker_bloc.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class ActiveTimerText extends StatefulWidget {
  final TextStyle? style;

  const ActiveTimerText({super.key, this.style});

  @override
  State<ActiveTimerText> createState() => _ActiveTimerTextState();
}

class _ActiveTimerTextState extends State<ActiveTimerText> {
  Timer? _timer;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime startTime) {
    _startTime = startTime;
    _updateElapsed();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    if (mounted && _elapsed != Duration.zero) {
      setState(() {
        _elapsed = Duration.zero;
      });
    }
  }

  void _updateElapsed() {
    if (_startTime != null) {
      _elapsed = DateTime.now().difference(_startTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimeTrackerBloc, TimeTrackerBlocState>(
      listenWhen: (previous, current) =>
          previous.activeEntryOrNull?.startAt !=
          current.activeEntryOrNull?.startAt,
      listener: (context, state) {
        final startAt = state.activeEntryOrNull?.startAt;
        if (startAt != null) {
          _startTimer(startAt);
        } else {
          _stopTimer();
        }
      },
      child: BlocBuilder<TimeTrackerBloc, TimeTrackerBlocState>(
        buildWhen: (previous, current) =>
            previous.activeEntryOrNull?.startAt !=
            current.activeEntryOrNull?.startAt,
        builder: (context, state) {
          if (_timer == null && state.activeEntryOrNull?.startAt != null) {
            _startTimer(state.activeEntryOrNull!.startAt);
          } else if (_timer != null &&
              state.activeEntryOrNull?.startAt == null) {
            _stopTimer();
          }

          final theme = context.theme;
          return Text(
            DateFormatter.formatDurationHms(_elapsed),
            style:
                widget.style ??
                theme.commonTextStyles.body.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          );
        },
      ),
    );
  }
}
