import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';
import 'package:worklog_studio_style_system/ui_kit/src/select/select_content.dart';
import 'package:worklog_studio_style_system/ui_kit/src/select/select_trigger.dart';

void main() {
  testWidgets(
    'popup width expands to minWidth when the trigger is narrower',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppThemeExtension.light()]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 80,
                child: Select<String>(
                  minWidth: 240,
                  placeholder: 'Pick',
                  options: const [SelectOption(value: 'a', label: 'Option A')],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SelectTrigger));
      await tester.pumpAndSettle();

      final contentSize = tester.getSize(find.byType(SelectContent<String>));
      expect(contentSize.width, 240);
    },
  );

  testWidgets(
    'popup matches trigger width when trigger already exceeds minWidth',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [AppThemeExtension.light()]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: Select<String>(
                  minWidth: 240,
                  placeholder: 'Pick',
                  options: const [SelectOption(value: 'a', label: 'Option A')],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SelectTrigger));
      await tester.pumpAndSettle();

      final contentSize = tester.getSize(find.byType(SelectContent<String>));
      expect(contentSize.width, 320);
    },
  );
}
