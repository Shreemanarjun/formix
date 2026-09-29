import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  testWidgets('FormixDropdownFormField reports invalid semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const fieldId = FormixFieldID<String>('role');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            autovalidateMode: FormixAutovalidateMode.always,
            fields: [
              FormixFieldConfig<String>(
                id: fieldId,
                initialValue: '',
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
            ],
            child: const FormixDropdownFormField<String>(
              fieldId: fieldId,
              items: [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'user', child: Text('User')),
              ],
              decoration: InputDecoration(labelText: 'Role'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Find the dropdown semantics.
    // DropdownButton creates a button.
    final finder = find.byType(DropdownButton<String>);
    expect(finder, findsOneWidget);

    // We often need to find the specific semantic node that represents the interactive element (the button).
    // DropdownButton usually implements Semantics.
    final semantics = tester.getSemantics(finder);
    final data = semantics.getSemanticsData();

    expect(data.validationResult, equals(SemanticsValidationResult.invalid));

    handle.dispose();
  });
}
