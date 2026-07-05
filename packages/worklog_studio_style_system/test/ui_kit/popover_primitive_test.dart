import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

void main() {
  const contentKey = Key('popover-content');
  const triggerKey = Key('popover-trigger');

  Widget buildHarness({
    required Alignment triggerAlignment,
    required PopoverController controller,
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: [AppThemeExtension.light()]),
      home: Scaffold(
        body: Align(
          alignment: triggerAlignment,
          child: PopoverPrimitive(
            controller: controller,
            trigger: SizedBox(
              key: triggerKey,
              width: 24,
              height: 24,
              child: ColoredBox(color: Colors.blue),
            ),
            contentBuilder: (context) {
              return Container(
                key: contentKey,
                width: 300,
                height: 300,
                color: Colors.red,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'popover anchored bottom-right of the screen stays fully on screen',
    (tester) async {
      final controller = PopoverController();
      await tester.pumpWidget(
        buildHarness(
          triggerAlignment: Alignment.bottomRight,
          controller: controller,
        ),
      );

      controller.show();
      await tester.pumpAndSettle();

      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final topLeft = tester.getTopLeft(find.byKey(contentKey));
      final bottomRight = tester.getBottomRight(find.byKey(contentKey));

      expect(topLeft.dx, greaterThanOrEqualTo(0));
      expect(topLeft.dy, greaterThanOrEqualTo(0));
      expect(bottomRight.dx, lessThanOrEqualTo(screenSize.width));
      expect(bottomRight.dy, lessThanOrEqualTo(screenSize.height));
    },
  );

  testWidgets(
    'popover anchored top-left of the screen stays fully on screen',
    (tester) async {
      final controller = PopoverController();
      await tester.pumpWidget(
        buildHarness(
          triggerAlignment: Alignment.topLeft,
          controller: controller,
        ),
      );

      controller.show();
      await tester.pumpAndSettle();

      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final topLeft = tester.getTopLeft(find.byKey(contentKey));
      final bottomRight = tester.getBottomRight(find.byKey(contentKey));

      expect(topLeft.dx, greaterThanOrEqualTo(0));
      expect(topLeft.dy, greaterThanOrEqualTo(0));
      expect(bottomRight.dx, lessThanOrEqualTo(screenSize.width));
      expect(bottomRight.dy, lessThanOrEqualTo(screenSize.height));
    },
  );
}
