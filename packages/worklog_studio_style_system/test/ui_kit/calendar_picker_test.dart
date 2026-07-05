import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

void main() {
  Widget buildHarness(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: [AppThemeExtension.light()]),
      home: Scaffold(body: child),
    );
  }

  testWidgets('tapping a day in single-date mode reports the selected date', (
    tester,
  ) async {
    DateTime? selected;
    final anchor = DateTime(2026, 6, 15);

    await tester.pumpWidget(
      buildHarness(
        CalendarPicker(
          selectedDate: anchor,
          onDateSelected: (date) => selected = date,
        ),
      ),
    );

    await tester.tap(find.text('10').first);
    await tester.pump();

    expect(selected, DateTime(2026, 6, 10));
  });

  testWidgets('next/prev month buttons change the visible month label', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        CalendarPicker(
          selectedDate: DateTime(2026, 6, 15),
          onDateSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Jun 2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('Jul 2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(find.text('Jun 2026'), findsOneWidget);
  });

  testWidgets('two taps in range mode produce a normalized DateTimeRange', (
    tester,
  ) async {
    DateTimeRange? selectedRange;

    await tester.pumpWidget(
      buildHarness(
        CalendarPicker(
          selectedRange: null,
          onRangeSelected: (range) => selectedRange = range,
        ),
      ),
    );

    // Pick day 20 first, then day 10 — should normalize to start=10, end=20.
    await tester.tap(find.text('20').first);
    await tester.pump();
    await tester.tap(find.text('10').first);
    await tester.pump();

    expect(selectedRange, isNotNull);
    expect(selectedRange!.start.day, 10);
    expect(selectedRange!.end.day, 20);
  });
}
