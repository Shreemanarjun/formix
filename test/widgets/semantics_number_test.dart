import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixNumberFormField reports invalid semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const fieldId = FormixFieldID<int>('age');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            autovalidateMode: FormixAutovalidateMode.always,
            fields: [
              FormixFieldConfig<int>(
                id: fieldId,
                // Use non-null invalid value to trigger validation in Formix
                initialValue: -1,
                validator: (val) => (val == null || val < 0) ? 'Must be positive' : null,
              ),
            ],
            child: const FormixNumberFormField<int>(
              fieldId: fieldId,
              decoration: InputDecoration(labelText: 'Age'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify error text is visible
    expect(find.text('Must be positive'), findsOneWidget);

    // Find InputDecorator, which often holds the decoration semantics including error
    final finder = find.descendant(
      of: find.byType(FormixNumberFormField<int>),
      matching: find.byType(InputDecorator),
    );
    expect(finder, findsOneWidget);

    final semantics = tester.getSemantics(finder);
    final data = semantics.getSemanticsData();

    if (data.validationResult != SemanticsValidationResult.invalid) {}

    expect(data.validationResult, equals(SemanticsValidationResult.invalid));

    handle.dispose();
  });
}
