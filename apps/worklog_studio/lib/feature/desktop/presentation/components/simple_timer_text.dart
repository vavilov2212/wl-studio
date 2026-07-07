import 'dart:async';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class SimpleTimerText extends StatefulWidget {
  final DateTime? startTime;
  final TextStyle? style;

  const SimpleTimerText({
    super.key,
    this.startTime,
    this.style,
  });

  @override
  State<SimpleTimerText> createState() => _SimpleTimerTextState();
}

class _SimpleTimerTextState extends State<SimpleTimerText> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.startTime != null) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(SimpleTimerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTime != oldWidget.startTime) {
      if (widget.startTime != null) {
        _startTimer();
      } else {
        _stopTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
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
    if (mounted) {
      setState(() {
        _elapsed = Duration.zero;
      });
    }
  }

  void _updateElapsed() {
    if (widget.startTime != null) {
      _elapsed = DateTime.now().difference(widget.startTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Text(
      DateFormatter.formatDurationHms(_elapsed),
      style: widget.style ??
          theme.commonTextStyles.body.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
