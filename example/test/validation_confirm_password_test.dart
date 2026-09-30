import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/ui/validation_examples/validation_examples_page.dart';

/// Pumps the [ValidationExamplesContent] inside a full test harness.
Future<void> _pumpPage(WidgetTester tester) async {
  // Tall enough to see email, password, and confirm password without scrolling.
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: ValidationExamplesContent())),
  );
  await tester.pumpAndSettle();
}

/// Finds the [TextFormField] whose [InputDecoration] label matches [label].
///
/// Uses [find.widgetWithText] which searches for an exact-match [Text]
/// descendant — the floating label rendered by [InputDecorator].
Finder _field(String label) => find.widgetWithText(TextFormField, label);

// ──────────────────────────────────────────────────────────────────────────────

void main() {
  group('Confirm Password Validation', () {
    // ── Regression: original bug ──────────────────────────────────────────────

    testWidgets(
      'REGRESSION: confirm password used a null context lookup and always '
      'showed "Passwords do not match" even for identical passwords',
      (tester) async {
        await _pumpPage(tester);

        // Enter a valid password (meets all password rules)
        await tester.enterText(_field('Password'), 'Secret1A');
        await tester.pumpAndSettle();

        // Enter the SAME value in the confirm field
        await tester.enterText(_field('Confirm Password'), 'Secret1A');
        await tester.pumpAndSettle();

        // Must NOT show the mismatch error
        expect(
          find.text('Passwords do not match'),
          findsNothing,
          reason:
              'Confirm password validator must read the live password value '
              'via crossFieldValidator(FormixData). If this fails the validator '
              'is still accessing a null context (old bug).',
        );
      },
    );

    // ── Correct behaviour ─────────────────────────────────────────────────────

    testWidgets('shows no error when confirm password matches password', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.enterText(_field('Password'), 'Secret1A');
      await tester.pumpAndSettle();

      await tester.enterText(_field('Confirm Password'), 'Secret1A');
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsNothing);
      expect(find.text('Please confirm your password'), findsNothing);
    });

    testWidgets(
      'shows "Passwords do not match" when confirm password differs',
      (tester) async {
        await _pumpPage(tester);

        await tester.enterText(_field('Password'), 'Secret1A');
        await tester.pumpAndSettle();

        await tester.enterText(_field('Confirm Password'), 'WrongPass1');
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match'), findsOneWidget);
      },
    );

    testWidgets('shows required error when confirm password is left empty', (
      tester,
    ) async {
      await _pumpPage(tester);

      // Type something into password so confirmPassword's dependsOn fires
      await tester.enterText(_field('Password'), 'Secret1A');
      await tester.pumpAndSettle();

      // Touch the confirm field then blur it without typing
      await tester.tap(_field('Confirm Password'));
      await tester.pumpAndSettle();
      await tester.tap(_field('Password')); // blur confirm
      await tester.pumpAndSettle();

      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets(
      'clears "Passwords do not match" error after correcting confirm password',
      (tester) async {
        await _pumpPage(tester);

        await tester.enterText(_field('Password'), 'Secret1A');
        await tester.pumpAndSettle();

        // Enter wrong confirm password
        await tester.enterText(_field('Confirm Password'), 'WrongPass1');
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsOneWidget);

        // Correct it
        await tester.enterText(_field('Confirm Password'), 'Secret1A');
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsNothing);
      },
    );

    testWidgets(
      're-validates confirm password automatically when password changes '
      '(dependsOn: [validationPasswordId])',
      (tester) async {
        await _pumpPage(tester);

        // Type matching passwords — no error
        await tester.enterText(_field('Password'), 'Secret1A');
        await tester.pumpAndSettle();
        await tester.enterText(_field('Confirm Password'), 'Secret1A');
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsNothing);

        // Change the password — confirmPassword now mismatches (re-validated
        // automatically via dependsOn without touching the confirm field)
        await tester.enterText(_field('Password'), 'Changed1A');
        await tester.pumpAndSettle();

        expect(
          find.text('Passwords do not match'),
          findsOneWidget,
          reason:
              'dependsOn: [validationPasswordId] must cause confirmPassword to '
              're-validate whenever the password field changes.',
        );
      },
    );
  });
}
