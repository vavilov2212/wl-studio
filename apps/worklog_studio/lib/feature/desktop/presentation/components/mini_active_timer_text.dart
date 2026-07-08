import 'package:flutter/material.dart';
import 'package:worklog_studio/domain/time_entry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniActiveTimerText extends StatefulWidget {
  final TimeEntry? entry;
  final TextStyle? style;

  const MiniActiveTimerText({super.key, required this.entry, this.style});

  @override
  State<MiniActiveTimerText> createState() => _MiniActiveTimerTextState();
}

class _MiniActiveTimerTextState extends State<MiniActiveTimerText> {
  late Stream<int> _timerStream;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _recalc();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  void _recalc() {
    if (widget.entry != null) {
      final now = DateTime.now();
      _seconds = now.difference(widget.entry!.startAt).inSeconds;
    } else {
      _seconds = 0;
    }
  }

  @override
  void didUpdateWidget(covariant MiniActiveTimerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recalc();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entry == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, snapshot) {
        _recalc();
        final duration = Duration(seconds: _seconds);
        String twoDigits(int n) => n.toString().padLeft(2, '0');
        final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
        final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
        final formatted =
            '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';

        return Text(
          formatted,
          style: widget.style ??
              context.theme.commonTextStyles.captionBold.copyWith(
                color: context.theme.colorsPalette.text.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        );
      },
    );
  }
}
