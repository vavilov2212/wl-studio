import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/feature/desktop/popover_positioning.dart';

void main() {
  group('computePopoverFrame', () {
    test('anchors the popover above and right-aligned to the tray icon', () {
      const trayBounds = Rect.fromLTWH(1850, 1040, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
      );

      // Right edge aligns with the tray icon's horizontal center.
      expect(frame.right, trayBounds.center.dx);
      // Width/height match the requested popover size exactly.
      expect(frame.width, popoverSize.width);
      expect(frame.height, popoverSize.height);
      // Bottom edge sits a small gap above the tray icon's top edge.
      expect(frame.bottom, trayBounds.top - 8);
    });

    test('honors a custom gap', () {
      const trayBounds = Rect.fromLTWH(100, 900, 32, 32);
      const popoverSize = Size(360, 520);

      final frame = computePopoverFrame(
        trayBounds: trayBounds,
        popoverSize: popoverSize,
        gap: 20,
      );

      expect(frame.bottom, trayBounds.top - 20);
    });
  });

  group('clampFrameToScreen', () {
    const screenSize = Size(1920, 1080);

    test('leaves a frame that already fits on screen unchanged', () {
      const frame = Rect.fromLTWH(1001, 267, 360, 520);

      final clamped = clampFrameToScreen(frame, screenSize);

      expect(clamped, frame);
    });

    test('pulls a frame overflowing the left edge back on screen', () {
      // e.g. a tray-bounds query that reports a small/wrong x position -
      // the exact failure mode this guards against, regardless of why the
      // upstream tray bounds were wrong.
      const frame = Rect.fromLTWH(-323, 403, 360, 520);

      final clamped = clampFrameToScreen(frame, screenSize);

      expect(clamped.left, 0);
      expect(clamped.width, 360);
      expect(clamped.height, 520);
    });

    test('pulls a frame overflowing the right edge back on screen', () {
      const frame = Rect.fromLTWH(1900, 403, 360, 520);

      final clamped = clampFrameToScreen(frame, screenSize);

      expect(clamped.right, screenSize.width);
    });

    test('pulls a frame overflowing the top edge back on screen', () {
      const frame = Rect.fromLTWH(1001, -50, 360, 520);

      final clamped = clampFrameToScreen(frame, screenSize);

      expect(clamped.top, 0);
    });

    test('pulls a frame overflowing the bottom edge back on screen', () {
      const frame = Rect.fromLTWH(1001, 1000, 360, 520);

      final clamped = clampFrameToScreen(frame, screenSize);

      expect(clamped.bottom, screenSize.height);
    });
  });

  group('computeActivityPromptFrame', () {
    test('centers horizontally and sits a fixed distance from the top', () {
      const screenSize = Size(1920, 1080);
      const promptSize = Size(420, 100);

      final frame = computeActivityPromptFrame(
        screenSize: screenSize,
        promptSize: promptSize,
      );

      expect(frame.left, (screenSize.width - promptSize.width) / 2);
      expect(frame.top, 96);
      expect(frame.width, promptSize.width);
      expect(frame.height, promptSize.height);
    });

    test('honors a custom top margin', () {
      const screenSize = Size(1920, 1080);
      const promptSize = Size(420, 100);

      final frame = computeActivityPromptFrame(
        screenSize: screenSize,
        promptSize: promptSize,
        topMargin: 40,
      );

      expect(frame.top, 40);
    });
  });
}
