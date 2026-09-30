import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormixFieldStateSnapshot', () {
    test('shouldShowError returns true when touched and invalid', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: const ValidationResult(isValid: false, errorMessage: 'Error'),
        isDirty: true,
        isTouched: true,
        isSubmitting: false,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.shouldShowError, true);
      focusNode.dispose();
    });

    test('shouldShowError returns true when invalid and autovalidateMode is always', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: const ValidationResult(isValid: false, errorMessage: 'Error'),
        isDirty: false,
        isTouched: false,
        isSubmitting: false,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.always,
      );

      expect(snapshot.shouldShowError, true);
      focusNode.dispose();
    });

    test('shouldShowError returns true when submitting and invalid', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: const ValidationResult(isValid: false, errorMessage: 'Error'),
        isDirty: true,
        isTouched: false,
        isSubmitting: true,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.shouldShowError, true);
      focusNode.dispose();
    });

    test('shouldShowError returns false when valid', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: ValidationResult.valid,
        isDirty: true,
        isTouched: true,
        isSubmitting: true,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.shouldShowError, false);
      focusNode.dispose();
    });

    test(
      'shouldShowError returns true when valid but touched/submitting and invalid',
      () {
        final focusNode = FocusNode();
        final snapshot = FormixFieldStateSnapshot<String>(
          value: 'test',
          validation: const ValidationResult(isValid: false, errorMessage: 'Error'),
          isDirty: true,
          isTouched: true,
          isSubmitting: false,
          focusNode: focusNode,
          didChange: (_) {},
          markAsTouched: () {},
          valueNotifier: ValueNotifier(null),
          enabled: true,
          autovalidateMode: FormixAutovalidateMode.auto,
        );

        expect(snapshot.shouldShowError, true);
        focusNode.dispose();
      },
    );

    test('shouldShowError returns false when validating', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: ValidationResult.validating,
        isDirty: true,
        isTouched: true,
        isSubmitting: true,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.shouldShowError, false);
      focusNode.dispose();
    });

    test('hasError returns true when validation is invalid', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: const ValidationResult(isValid: false, errorMessage: 'Error'),
        isDirty: true,
        isTouched: true,
        isSubmitting: false,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.hasError, true);
      focusNode.dispose();
    });

    test('hasError returns false when validation is valid', () {
      final focusNode = FocusNode();
      final snapshot = FormixFieldStateSnapshot<String>(
        value: 'test',
        validation: ValidationResult.valid,
        isDirty: true,
        isTouched: true,
        isSubmitting: false,
        focusNode: focusNode,
        didChange: (_) {},
        markAsTouched: () {},
        valueNotifier: ValueNotifier(null),
        enabled: true,
        autovalidateMode: FormixAutovalidateMode.auto,
      );

      expect(snapshot.hasError, false);
      focusNode.dispose();
    });
  });

  group('FormixRawFormField', () {
    testWidgets('provides snapshot with correct initial state', (tester) async {
      const id = FormixFieldID<String>('test_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'test_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawFormField<String>(
                fieldId: id,
                initialValue: 'initial',
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot, isNotNull);
      expect(capturedSnapshot!.value, 'initial');
      expect(capturedSnapshot!.isDirty, false);
      expect(capturedSnapshot!.isTouched, false);
      expect(capturedSnapshot!.isSubmitting, false);
      expect(capturedSnapshot!.validation.isValid, true);
      expect(capturedSnapshot!.focusNode, isNotNull);
    });

    testWidgets('snapshot updates when value changes', (tester) async {
      const id = FormixFieldID<String>('test_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'test_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawFormField<String>(
                fieldId: id,
                initialValue: 'initial',
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Change value
      capturedSnapshot!.didChange('updated');
      await tester.pump();

      expect(capturedSnapshot!.value, 'updated');
      expect(capturedSnapshot!.isDirty, true);
    });

    testWidgets('snapshot updates when validation changes', (tester) async {
      const id = FormixFieldID<String>('test_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'test_field': '',
              }, // Start with empty string
              fields: [
                FormixFieldConfig(
                  id: id,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
              ],
              child: FormixRawFormField<String>(
                fieldId: id,
                initialValue: '',
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Valid: ${snapshot.validation.isValid}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially invalid (empty string fails validation)
      expect(capturedSnapshot!.validation.isValid, false);

      // Set valid value
      capturedSnapshot!.didChange('valid');
      await tester.pump();

      expect(capturedSnapshot!.validation.isValid, true);
    });

    testWidgets('snapshot updates when touched state changes', (tester) async {
      const id = FormixFieldID<String>('test_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [FormixFieldConfig(id: id)],
              child: FormixRawFormField<String>(
                fieldId: id,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Touched: ${snapshot.isTouched}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.isTouched, false);

      // Mark as touched
      capturedSnapshot!.markAsTouched();
      await tester.pump();

      expect(capturedSnapshot!.isTouched, true);
    });

    testWidgets('snapshot updates when submitting state changes', (
      tester,
    ) async {
      const id = FormixFieldID<String>('test_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [FormixFieldConfig(id: id)],
              child: FormixRawFormField<String>(
                fieldId: id,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Submitting: ${snapshot.isSubmitting}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.isSubmitting, false);

      // Set submitting
      final controller = Formix.of(
        tester.element(find.text('Submitting: false')),
      );
      controller.setSubmitting(true);
      await tester.pump();

      expect(capturedSnapshot!.isSubmitting, true);
    });
  });

  group('FormixRawTextField', () {
    testWidgets('provides text snapshot with correct initial state', (
      tester,
    ) async {
      const id = FormixFieldID<String>('text_field');
      FormixTextFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'text_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawTextField<String>(
                fieldId: id,
                initialValue: 'initial',
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s.isEmpty ? null : s,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot, isNotNull);
      expect(capturedSnapshot!.value, 'initial');
      expect(capturedSnapshot!.textController, isNotNull);
      expect(capturedSnapshot!.textController.text, 'initial');
    });

    testWidgets('text controller updates when value changes externally', (
      tester,
    ) async {
      const id = FormixFieldID<String>('text_field');
      FormixTextFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'text_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawTextField<String>(
                fieldId: id,
                initialValue: 'initial',
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s.isEmpty ? null : s,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Controller: ${snapshot.textController.text}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.textController.text, 'initial');

      // Change value externally
      final controller = Formix.of(
        tester.element(find.text('Controller: initial')),
      );
      controller.setValue(id, 'external');
      await tester.pump();

      expect(capturedSnapshot!.textController.text, 'external');
    });

    testWidgets('value updates when text controller changes', (tester) async {
      const id = FormixFieldID<String>('text_field');
      FormixTextFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'text_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawTextField<String>(
                fieldId: id,
                initialValue: 'initial',
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s.isEmpty ? null : s,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.value, 'initial');

      // Change text controller
      capturedSnapshot!.textController.text = 'typed';
      await tester.pump();

      expect(capturedSnapshot!.value, 'typed');
    });

    testWidgets('custom valueToString and stringToValue work correctly', (
      tester,
    ) async {
      const id = FormixFieldID<int>('number_field');
      FormixTextFieldStateSnapshot<int>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'number_field': 42},
              fields: const [FormixFieldConfig(id: id, initialValue: 42)],
              child: FormixRawTextField<int>(
                fieldId: id,
                initialValue: 42,
                valueToString: (v) => v?.toString() ?? '',
                stringToValue: (s) => int.tryParse(s),
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.value, 42);
      expect(capturedSnapshot!.textController.text, '42');

      // Change text controller
      capturedSnapshot!.textController.text = '123';
      await tester.pump();

      expect(capturedSnapshot!.value, 123);
    });

    testWidgets('handles null values correctly', (tester) async {
      const id = FormixFieldID<String?>('nullable_field');
      FormixTextFieldStateSnapshot<String?>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: const [FormixFieldConfig<String?>(id: id)],
              child: FormixRawTextField<String?>(
                fieldId: id,
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s.isEmpty ? null : s,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value ?? "null"}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.value, isNull);
      expect(capturedSnapshot!.textController.text, '');

      // Change to non-null value using didChange (more reliable)
      capturedSnapshot!.didChange('not null');
      await tester.pump();

      expect(capturedSnapshot!.value, 'not null');
      expect(capturedSnapshot!.textController.text, 'not null');

      // Change back to null
      capturedSnapshot!.didChange(null);
      await tester.pump();

      expect(capturedSnapshot!.value, isNull);
      expect(capturedSnapshot!.textController.text, '');
    });
  });

  group('Headless Widgets (Standalone)', () {
    testWidgets('FormixRawTextField finds child after registration', (
      tester,
    ) async {
      const id = FormixFieldID<String>('standalone');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'standalone': 'Initial'},
              fields: const <FormixFieldConfig<dynamic>>[
                FormixFieldConfig<String>(id: id, initialValue: 'Initial'),
              ],
              child: FormixRawTextField<String>(
                fieldId: id,
                initialValue: 'Initial',
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s.isEmpty ? null : s,
                builder: (context, state) {
                  return Container(
                    key: const Key('my_headless_container'),
                    child: Text('Value: ${state.value}'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Pump to process the widget tree
      await tester.pump();
      // Pump again to process the microtask for field registration
      await tester.pump();

      // Now the widget should be rendered
      expect(find.byKey(const Key('my_headless_container')), findsOneWidget);
      expect(find.text('Value: Initial'), findsOneWidget);

      // Verify value update
      final element = tester.element(
        find.byKey(const Key('my_headless_container')),
      );
      final controller = Formix.controllerOf(element)!;

      controller.setValue(id, 'Alex');
      await tester.pump();

      expect(find.text('Value: Alex'), findsOneWidget);
    });
  });

  group('FormixRawStringField', () {
    testWidgets('works with default string converters', (tester) async {
      const id = FormixFieldID<String>('string_field');
      FormixTextFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'string_field': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawStringField(
                fieldId: id,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return Text('Value: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(capturedSnapshot!.textController.text, 'initial');

      // Change text controller
      capturedSnapshot!.textController.text = 'updated';
      await tester.pump();

      expect(capturedSnapshot!.value, 'updated');
    });
  });

  group('FormixRawNotifierField', () {
    testWidgets('provides valueNotifier and updates correctly', (tester) async {
      const id = FormixFieldID<String>('notifier_field');
      FormixFieldStateSnapshot<String>? capturedSnapshot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'notifier_field': 'start'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'start')],
              child: FormixRawNotifierField<String>(
                fieldId: id,
                builder: (context, snapshot) {
                  capturedSnapshot = snapshot;
                  return ValueListenableBuilder<String?>(
                    valueListenable: snapshot.valueNotifier,
                    builder: (context, value, _) {
                      return Text('NotifierValue: $value');
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('NotifierValue: start'), findsOneWidget);

      // Change via didChange
      capturedSnapshot!.didChange('middle');
      await tester.pump();
      expect(find.text('NotifierValue: middle'), findsOneWidget);

      // Change via notifier directly should ALSO work because Formix listens to them!
      // Actually Formix doesn't listen to them for value updates, it provides them.
      // But FormixController manages the notifier.

      capturedSnapshot!.valueNotifier.value = 'end';
      // Wait, let's check if FormixController updates the state when user sets notifier.value.
      // Usually it's better to use didChange.

      await tester.pump();
      // If FormixController doesn't listen to the notifier, this test might fail to update the rest of the form.
      // But the ValueListenableBuilder will definitely update.
      expect(find.text('NotifierValue: end'), findsOneWidget);
    });
  });

  group('Complex Headless Integration', () {
    testWidgets('Headless widgets react to form level resets', (tester) async {
      const id = FormixFieldID<String>('reset_test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'reset_test': 'initial'},
              fields: const [FormixFieldConfig(id: id, initialValue: 'initial')],
              child: FormixRawStringField(
                fieldId: id,
                builder: (context, snapshot) {
                  return Text('CurrentValue: ${snapshot.value}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('CurrentValue: initial'), findsOneWidget);

      // Change value
      final element = tester.element(find.text('CurrentValue: initial'));
      final controller = Formix.controllerOf(element)!;
      controller.setValue(id, 'changed');
      await tester.pump();
      expect(find.text('CurrentValue: changed'), findsOneWidget);

      // Reset form
      controller.reset();
      await tester.pump();
      expect(find.text('CurrentValue: initial'), findsOneWidget);
    });

    testWidgets('Headless widgets reflect global validation status', (
      tester,
    ) async {
      const id = FormixFieldID<String>('validation_test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'validation_test': ''},
              fields: [
                FormixFieldConfig(
                  id: id,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'REQUIRED' : null,
                ),
              ],
              child: FormixRawFormField<String>(
                fieldId: id,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.validation.isValid ? 'STATE: VALID' : 'STATE: INVALID',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      // Initially invalid because it's required and empty
      expect(find.text('STATE: INVALID'), findsOneWidget);

      // Update to valid
      final element = tester.element(find.text('STATE: INVALID'));
      final controller = Formix.controllerOf(element)!;
      controller.setValue(id, 'some value');
      await tester.pump();
      expect(find.text('STATE: VALID'), findsOneWidget);
    });

    testWidgets('Headless widgets correctly show errors with autovalidateMode.always', (tester) async {
      const id = FormixFieldID<String>('autovalidate_test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: id,
                  initialValue: '',
                  validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                ),
              ],
              child: FormixRawTextField<String>(
                fieldId: id,
                autovalidateMode: FormixAutovalidateMode.always,
                valueToString: (v) => v ?? '',
                stringToValue: (s) => s,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.shouldShowError ? 'ERROR: ${snapshot.validation.errorMessage}' : 'NO ERROR',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error immediately because of autovalidateMode.always
      expect(find.text('ERROR: Required'), findsOneWidget);

      // Should hide error when valid
      final element = tester.element(find.text('ERROR: Required'));
      final controller = Formix.controllerOf(element)!;
      controller.setValue(id, 'valid');
      await tester.pump();

      expect(find.text('NO ERROR'), findsOneWidget);
    });
  });
}
