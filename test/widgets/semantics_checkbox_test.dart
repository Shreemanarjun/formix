import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixCheckboxFormField reports invalid semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const fieldId = FormixFieldID<bool>('agree');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            autovalidateMode: FormixAutovalidateMode.always,
            fields: [
              FormixFieldConfig<bool>(
                id: fieldId,
                initialValue: false,
                validator: (val) => (val == true) ? null : 'Must agree',
              ),
            ],
            child: const FormixCheckboxFormField(
              fieldId: fieldId,
              title: Text('Agree to terms'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Find the switch/checkbox semantics
    final finder = find.byType(CheckboxListTile);
    expect(finder, findsOneWidget);

    // Check semantics data
    final semantics = tester.getSemantics(finder);
    final data = semantics.getSemanticsData();

    expect(data.validationResult, equals(SemanticsValidationResult.invalid));

    handle.dispose();
  });
}
