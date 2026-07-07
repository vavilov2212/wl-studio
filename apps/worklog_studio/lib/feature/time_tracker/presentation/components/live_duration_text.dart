import 'dart:async';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/utils/date_formatter.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Text(
      DateFormatter.formatDurationHms(widget.durationBuilder(_now)),
      style: widget.style ??
          theme.commonTextStyles.body.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}
