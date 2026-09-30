import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Runtime Field Type Changes', () {
    testWidgets(
      'Changing field type at runtime works correctly',
      (tester) async {
        final formKey = GlobalKey<FormixState>();

        // Start with a String field
        bool useStringField = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      Formix(
                        key: formKey,
                        fields: useStringField
                            ? [
                                FormixFieldConfig<String>(
                                  id: const FormixFieldID<String>('dynamicField'),
                                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ]
                            : [
                                FormixFieldConfig<DateTime?>(
                                  id: const FormixFieldID<DateTime?>('dynamicField'),
                                  validator: (value) => value == null ? 'Required' : null,
                                ),
                              ],
                        child: useStringField
                            ? const FormixTextFormField(
                                fieldId: FormixFieldID<String>('dynamicField'),
                                decoration: InputDecoration(labelText: 'String Field'),
                              )
                            : FormixRawFormField<DateTime?>(
                                fieldId: const FormixFieldID<DateTime?>('dynamicField'),
                                builder: (context, state) {
                                  return Column(
                                    children: [
                                      Text('Date: ${state.value}'),
                                      if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                                    ],
                                  );
                                },
                              ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            useStringField = !useStringField;
                          });
                        },
                        child: const Text('Toggle Field Type'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify string field is shown
        expect(find.byType(FormixTextFormField), findsOneWidget);

        // Toggle to DateTime field
        await tester.tap(find.text('Toggle Field Type'));
        await tester.pumpAndSettle();

        // Verify DateTime field is shown
        expect(find.text('Date: null'), findsOneWidget);
        expect(find.byType(FormixTextFormField), findsNothing);

        // Toggle back to String field
        await tester.tap(find.text('Toggle Field Type'));
        await tester.pumpAndSettle();

        // Verify string field is shown again
        expect(find.byType(FormixTextFormField), findsOneWidget);
      },
    );

    testWidgets(
      'Changing field ID type at runtime with different field IDs',
      (tester) async {
        final formKey = GlobalKey<FormixState>();

        // Use different field IDs for different types
        bool useStringField = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      Formix(
                        key: formKey,
                        fields: useStringField
                            ? [
                                FormixFieldConfig<String>(
                                  id: const FormixFieldID<String>('stringField'),
                                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                ),
                              ]
                            : [
                                FormixFieldConfig<DateTime?>(
                                  id: const FormixFieldID<DateTime?>('dateField'),
                                  validator: (value) => value == null ? 'Required' : null,
                                ),
                              ],
                        child: useStringField
                            ? const FormixTextFormField(
                                fieldId: FormixFieldID<String>('stringField'),
                                decoration: InputDecoration(labelText: 'String Field'),
                              )
                            : FormixRawFormField<DateTime?>(
                                fieldId: const FormixFieldID<DateTime?>('dateField'),
                                builder: (context, state) {
                                  return Column(
                                    children: [
                                      Text('Date: ${state.value}'),
                                      if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                                    ],
                                  );
                                },
                              ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            useStringField = !useStringField;
                          });
                        },
                        child: const Text('Toggle Field Type'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify string field is shown
        expect(find.byType(FormixTextFormField), findsOneWidget);

        final controller = formKey.currentState!.controller;

        // Set a value in the string field
        controller.setValue(const FormixFieldID<String>('stringField'), 'test value');
        await tester.pumpAndSettle();

        // Toggle to DateTime field
        await tester.tap(find.text('Toggle Field Type'));
        await tester.pumpAndSettle();

        // Verify DateTime field is shown
        expect(find.text('Date: null'), findsOneWidget);
        expect(find.byType(FormixTextFormField), findsNothing);

        // Set a value in the date field
        controller.setValue(
          const FormixFieldID<DateTime?>('dateField'),
          DateTime(2026, 2, 8),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Date: 2026-02-08'), findsOneWidget);

        // Toggle back to String field
        await tester.tap(find.text('Toggle Field Type'));
        await tester.pumpAndSettle();

        // Verify string field is shown again with preserved value
        expect(find.byType(FormixTextFormField), findsOneWidget);

        // The string field should still have its value
        final stringValue = controller.getValue(const FormixFieldID<String>('stringField'));
        expect(stringValue, 'test value');
      },
    );
  });
}
