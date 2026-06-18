import 'dart:async';
import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class LiveDurationText extends StatefulWidget {
  final Duration Function(DateTime now) durationBuilder;
  final TextStyle? style;

  const LiveDurationText({
    super.key,
    required this.durationBuilder,
    this.style,
  });

  @override
  State<LiveDurationText> createState() => _LiveDurationTextState();
}

class _LiveDurationTextState extends State<LiveDurationText> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Text(
      _formatDuration(widget.durationBuilder(_now)),
      style: widget.style ??
          theme.commonTextStyles.body.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
