import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio_style_system/ui_kit/src/select/select_content.dart';

void main() {
  Widget buildHarness({
    required List<SelectOption<String>> options,
    required ValueChanged<String> onSelect,
    VoidCallback? close,
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: [AppThemeExtension.light()]),
      home: Scaffold(
        body: SelectContent<String>(
          searchable: false,
          searchController: TextEditingController(),
          options: options,
          selectedValue: null,
          onSelect: onSelect,
          searchQuery: '',
          close: close ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'tapping the row label selects the option',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        buildHarness(
          options: const [SelectOption(value: 'a', label: 'Option A')],
          onSelect: (value) => selected = value,
        ),
      );

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(selected, 'a');
    },
  );

  testWidgets(
    'tapping the action icon calls onAction and close, but does not select',
    (tester) async {
      String? selected;
      var actionCalled = false;
      var closeCalled = false;

      await tester.pumpWidget(
        buildHarness(
          options: [
            SelectOption<String>(
              value: 'a',
              label: 'Option A',
              onAction: () => actionCalled = true,
              actionIcon: Icons.open_in_new,
            ),
          ],
          onSelect: (value) => selected = value,
          close: () => closeCalled = true,
        ),
      );

      // Action icon only becomes tappable while the row is hovered.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Option A')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Option A')));
      await tester.pump();

      final actionIconFinder = find.byIcon(Icons.open_in_new);
      expect(actionIconFinder, findsOneWidget);

      await tester.tap(actionIconFinder);
      await tester.pump();

      expect(actionCalled, isTrue);
      expect(closeCalled, isTrue);
      expect(selected, isNull);

      await gesture.removePointer();
    },
  );

  testWidgets(
    'action icon is not rendered when onAction is null',
    (tester) async {
      await tester.pumpWidget(
        buildHarness(
          options: const [SelectOption(value: 'a', label: 'Option A')],
          onSelect: (_) {},
        ),
      );

      expect(find.byIcon(Icons.open_in_new), findsNothing);
    },
  );
}
