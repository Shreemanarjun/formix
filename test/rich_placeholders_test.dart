import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Rich Error Placeholders Tests', () {
    const ageField = FormixFieldID<int>('age');

    testWidgets('Placeholders {label} and {min} are resolved', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<int>.chain(
                  id: ageField,
                  label: 'User Age',
                  rules: FormixValidators.number<int>().min(18),
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // Trigger validation with invalid value
      controller.setValue(ageField, 10);
      await tester.pump();

      final validation = controller.getValidation(ageField);
      // Expected: "User Age must be at least 18"
      expect(validation.errorMessage, contains('User Age'));
      expect(validation.errorMessage, contains('18'));
      expect(validation.errorMessage, 'User Age must be at least 18');
    });

    testWidgets('Custom placeholders work', (tester) async {
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig<int>(
                  id: ageField,
                  label: 'Age',
                  validator: (v) => (v ?? 0) < 18 ? 'Too young! {value} < 18' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = Formix.controllerOf(context)!;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      controller.setValue(ageField, 15);
      await tester.pump();

      final validation = controller.getValidation(ageField);
      expect(validation.errorMessage, 'Too young! 15 < 18');
    });
  });
}
