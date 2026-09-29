import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Formatting and Masking Tests', () {
    const cardNumberField = FormixFieldID<String>('cardNumber');

    testWidgets('Input formatters are applied', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: cardNumberField,
                  label: 'Card Number',
                  initialValue: '',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                  ],
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const Column(
                    children: [FormixTextFormField(fieldId: cardNumberField)],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Enter digits
      await tester.enterText(find.byType(TextField), '1234567890123456');
      await tester.pump();
      expect(controller.getValue(cardNumberField), '1234567890123456');

      // Enter alphanumeric (formatting should prevent letters)
      await tester.enterText(find.byType(TextField), '1234abcd5678');
      await tester.pump();
      // Only digits should persist and fit within limit
      expect(controller.getValue(cardNumberField), '12345678');

      // Test length limit
      await tester.enterText(find.byType(TextField), '11112222333344445555');
      await tester.pump();
      expect(controller.getValue(cardNumberField), '1111222233334444');
    });

    testWidgets('Input formatters from widget merge with config', (
      tester,
    ) async {
      const phoneField = FormixFieldID<String>('phone');
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<String>(
                  id: phoneField,
                  initialValue: '',
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return FormixTextFormField(
                    fieldId: phoneField,
                    inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Should apply both digitsOnly (from config) and lengthLimit (from widget)
      await tester.enterText(find.byType(TextField), '12345abcde67890EXTRA');
      await tester.pump();

      // Digits only -> remove abcde
      // Length 10 -> truncates
      expect(controller.getValue(phoneField), '1234567890');
    });
  });
}
