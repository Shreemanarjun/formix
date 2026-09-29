import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/multi_step_form/multi_step_form_page.dart';

void main() {
  testWidgets('MultiStepFormPage Golden Test - Initial State', (tester) async {
    // Set a consistent surface size for golden tests
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MultiStepFormPage(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial layout of Step 1
    await expectLater(
      find.byType(MultiStepFormPage),
      matchesGoldenFile('goldens/multi_step_form_step1.png'),
    );
  });

  testWidgets('MultiStepFormPage Golden Test - Step 2', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MultiStepFormPage(),
      ),
    );

    await tester.pumpAndSettle();

    // Fill Step 1 to proceed
    await tester.enterText(
      find.widgetWithText(TextField, 'Full Name').first,
      'John Doe',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email').first,
      'john@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone').first,
      '1234567890',
    );
    await tester.pumpAndSettle();

    // Go to Step 2
    await tester.tap(find.byKey(const Key('continue_button')).first);
    await tester.pumpAndSettle();

    // Verify layout of Step 2
    await expectLater(
      find.byType(MultiStepFormPage),
      matchesGoldenFile('goldens/multi_step_form_step2.png'),
    );
  });
}
