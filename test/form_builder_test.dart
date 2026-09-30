import 'package:formix/formix.dart';
import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';

// A custom widget extending FormixWidget
class CustomStatusDisplay extends FormixWidget {
  const CustomStatusDisplay({super.key});

  @override
  Widget buildForm(BuildContext context, FormixScope scope) {
    return Column(
      children: [
        Text('State: ${scope.watchIsFormDirty ? "Dirty" : "Clean"}'),
        Text('Valid: ${scope.watchIsValid}'),
      ],
    );
  }
}

void main() {
  testWidgets('FormixBuilder provides scope with reactive watchValue', (
    tester,
  ) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': 'initial'},
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                final value = scope.watchValue(field1);
                return Column(
                  children: [
                    Text('Value: $value'),
                    ElevatedButton(
                      onPressed: () => scope.setValue(field1, 'changed'),
                      child: const Text('Change'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Value: initial'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pump();

    expect(find.text('Value: changed'), findsOneWidget);
  });

  testWidgets('FormixWidget extension provides scope with reactive getters', (
    tester,
  ) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: {'field1': 'initial'},
            fields: [FormixFieldConfig(id: field1)],
            child: CustomStatusDisplay(),
          ),
        ),
      ),
    );

    expect(find.text('State: Clean'), findsOneWidget);
    expect(find.text('Valid: true'), findsOneWidget);

    // Trigger a change
    final controller = Formix.of(
      tester.element(find.byType(CustomStatusDisplay)),
    );
    controller.setValue(field1, 'dirty');

    await tester.pump();

    expect(find.text('State: Dirty'), findsOneWidget);
  });

  testWidgets('FormixScope.submit helper works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');
    bool submitted = false;
    Map<String, dynamic>? submittedValues;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            fields: [
              FormixFieldConfig(
                id: field1,
                validator: (v) => (v?.isEmpty ?? true) ? 'Error' : null,
              ),
            ],
            child: FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () => scope.submit(
                    onValid: (values) async {
                      submitted = true;
                      submittedValues = values;
                    },
                  ),
                  child: Text(
                    scope.watchIsSubmitting ? 'Submitting' : 'Submit',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initial click should fail validation
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(submitted, isFalse);

    // Set valid value
    final controller = Formix.of(tester.element(find.text('Submit')));
    controller.setValue(field1, 'valid');
    await tester.pump();

    // Click again
    await tester.tap(find.text('Submit'));
    // We don't pump yet to check submitting state if it was async,
    // but here it's immediate async.
    await tester.pump();

    expect(submitted, isTrue);
    expect(submittedValues?[field1.key], 'valid');
  });

  testWidgets('FormixScope.watchValidation works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': ''}, // Start with empty string
            fields: [
              FormixFieldConfig(
                id: field1,
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
            ],
            child: FormixBuilder(
              builder: (context, scope) {
                final validation = scope.watchValidation(field1);
                return Text('Validation: ${validation.isValid}');
              },
            ),
          ),
        ),
      ),
    );

    // Initially should be invalid (empty string fails validation)
    expect(find.text('Validation: false'), findsOneWidget);

    // Set valid value
    final controller = Formix.of(
      tester.element(find.text('Validation: false')),
    );
    controller.setValue(field1, 'valid');
    await tester.pump();

    expect(find.text('Validation: true'), findsOneWidget);
  });

  testWidgets('FormixScope.watchIsDirty works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': 'initial'},
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                final isDirty = scope.watchIsDirty(field1);
                return Text('Dirty: $isDirty');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Dirty: false'), findsOneWidget);

    // Change value
    final controller = Formix.of(tester.element(find.text('Dirty: false')));
    controller.setValue(field1, 'changed');
    await tester.pump();

    expect(find.text('Dirty: true'), findsOneWidget);
  });

  testWidgets('FormixScope.watchIsTouched works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                final isTouched = scope.watchIsTouched(field1);
                return Text('Touched: $isTouched');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Touched: false'), findsOneWidget);

    // Mark as touched
    final controller = Formix.of(tester.element(find.text('Touched: false')));
    controller.markAsTouched(field1);
    await tester.pump();

    expect(find.text('Touched: true'), findsOneWidget);
  });

  testWidgets('FormixScope.watchIsFormDirty works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': 'initial'},
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                final isFormDirty = scope.watchIsFormDirty;
                return Text('Form Dirty: $isFormDirty');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Form Dirty: false'), findsOneWidget);

    // Change value
    final controller = Formix.of(
      tester.element(find.text('Form Dirty: false')),
    );
    controller.setValue(field1, 'changed');
    await tester.pump();

    expect(find.text('Form Dirty: true'), findsOneWidget);
  });

  testWidgets('FormixScope.watchIsSubmitting works correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            child: FormixBuilder(
              builder: (context, scope) {
                final isSubmitting = scope.watchIsSubmitting;
                return Text('Submitting: $isSubmitting');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Submitting: false'), findsOneWidget);

    // Set submitting
    final controller = Formix.of(
      tester.element(find.text('Submitting: false')),
    );
    controller.setSubmitting(true);
    await tester.pump();

    expect(find.text('Submitting: true'), findsOneWidget);
  });

  testWidgets('FormixScope.watchState works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': 'initial'},
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                final state = scope.watchState;
                return Text('State Values: ${state.values.length}');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('State Values: 1'), findsOneWidget);
  });

  testWidgets('FormixScope.markAsTouched works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () => scope.markAsTouched(field1),
                  child: const Text('Mark Touched'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initially not touched
    final controller = Formix.of(tester.element(find.text('Mark Touched')));
    expect(controller.isFieldTouched(field1), false);

    // Mark as touched
    await tester.tap(find.text('Mark Touched'));
    await tester.pump();

    expect(controller.isFieldTouched(field1), true);
  });

  testWidgets('FormixScope.validate works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');
    bool? validationResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            fields: [
              FormixFieldConfig(
                id: field1,
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
            ],
            child: FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () {
                    validationResult = scope.validate();
                  },
                  child: const Text('Validate'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Initially should be invalid (empty value fails validation)
    await tester.tap(find.text('Validate'));
    await tester.pump();
    expect(validationResult, false);

    // Set valid value
    final controller = Formix.of(tester.element(find.text('Validate')));
    controller.setValue(field1, 'valid');
    await tester.pump();

    // Validate again
    await tester.tap(find.text('Validate'));
    await tester.pump();
    expect(validationResult, true);
  });

  testWidgets('FormixScope.reset works correctly', (tester) async {
    const field1 = FormixFieldID<String>('field1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            initialValue: const {'field1': 'initial'},
            fields: const [FormixFieldConfig(id: field1)],
            child: FormixBuilder(
              builder: (context, scope) {
                return Column(
                  children: [
                    Text('Value: ${scope.watchValue(field1)}'),
                    ElevatedButton(
                      onPressed: () => scope.reset(),
                      child: const Text('Reset'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Value: initial'), findsOneWidget);

    // Change value
    final controller = Formix.of(tester.element(find.text('Value: initial')));
    controller.setValue(field1, 'changed');
    await tester.pump();

    expect(find.text('Value: changed'), findsOneWidget);

    // Reset
    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(find.text('Value: initial'), findsOneWidget);
  });

  testWidgets('FormixScope.submit with onError callback works', (tester) async {
    const field1 = FormixFieldID<String>('field1');
    bool errorCalled = false;
    Map<String, ValidationResult>? errorResults;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Formix(
            fields: [
              FormixFieldConfig(
                id: field1,
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
            ],
            child: FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () => scope.submit(
                    onValid: (values) async {
                      // Should not be called
                    },
                    onError: (errors) {
                      errorCalled = true;
                      errorResults = errors;
                    },
                  ),
                  child: const Text('Submit'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Submit with invalid form
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(errorCalled, true);
    expect(errorResults, isNotNull);
    expect(errorResults![field1.key]!.isValid, false);
  });

  testWidgets('FormixBuilder throws error when not inside Formix', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormixBuilder(
            builder: (context, scope) => const Text('Should not render'),
          ),
        ),
      ),
    );

    expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
  });

  testWidgets('FormixWidget throws error when not inside Formix', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CustomStatusDisplay())),
    );

    expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
  });
}
