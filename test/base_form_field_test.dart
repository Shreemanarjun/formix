import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Test implementations of the abstract classes
class TestFormFieldWidget extends FormixFieldWidget<String> {
  const TestFormFieldWidget({
    super.key,
    required super.fieldId,
    super.controller,
    super.validator,
    super.initialValue,
    super.onSaved,
    super.onReset,
    super.enabled,
    super.forceErrorText,
    super.errorBuilder,
    super.autovalidateMode,
    super.restorationId,
  });

  @override
  TestFormFieldWidgetState createState() => TestFormFieldWidgetState();
}

class TestFormFieldWidgetState extends FormixFieldWidgetState<String> {
  int buildCount = 0;
  String? lastChangedValue;

  @override
  void onFieldChanged(String? value) {
    lastChangedValue = value;
    super.onFieldChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Text('Test Field: ${value ?? "null"}');
  }
}

class TestTextFormFieldWidget extends FormixTextFormFieldWidget {
  const TestTextFormFieldWidget({
    super.key,
    required super.fieldId,
    super.controller,
    super.validator,
    super.initialValue,
    super.decoration,
    super.keyboardType,
    super.maxLines,
    super.obscureText,
    super.enabled,
  });

  @override
  TestTextFormFieldWidgetState createState() => TestTextFormFieldWidgetState();
}

class TestTextFormFieldWidgetState extends FormixTextFormFieldWidgetState {
  @override
  Widget build(BuildContext context) {
    // Use the parent build method but wrap it for testing
    return Container(
      key: const Key('test_text_field'),
      child: super.build(context),
    );
  }
}

class TestNumberFormFieldWidget extends FormixNumberFormFieldWidget {
  const TestNumberFormFieldWidget({
    super.key,
    required super.fieldId,
    super.controller,
    super.validator,
    super.initialValue,
    super.decoration,
    super.enabled,
  });

  @override
  TestNumberFormFieldWidgetState createState() => TestNumberFormFieldWidgetState();
}

class TestNumberFormFieldWidgetState extends FormixNumberFormFieldWidgetState {
  @override
  Widget build(BuildContext context) {
    // Use the parent build method but wrap it for testing
    return Container(
      key: const Key('test_number_field'),
      child: super.build(context),
    );
  }
}

void main() {
  group('FormixFieldWidget', () {
    late FormixFieldID<String> testField;

    setUp(() {
      testField = const FormixFieldID<String>('test_field');
    });

    testWidgets('constructor initializes correctly', (tester) async {
      const widget = TestFormFieldWidget(
        fieldId: FormixFieldID<String>('test'),
      );

      expect(widget.fieldId.key, 'test');
      expect(widget.controller, isNull);
      expect(widget.validator, isNull);
      expect(widget.initialValue, isNull);
    });

    testWidgets('state initializes with focus node and mounted flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: testField, initialValue: 'initial'),
              ],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.focusNode, isNotNull);
      expect(state.mounted, isTrue);
      expect(state.controller, isNotNull);
    });

    testWidgets('didChangeDependencies registers field and sets up listeners', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: testField, initialValue: 'initial'),
              ],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.controller.isFieldRegistered(testField), isTrue);
      expect(state.value, 'initial');
    });

    testWidgets('field auto-registration works when not pre-registered', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: TestFormFieldWidget(
                fieldId: testField,
                initialValue: 'auto_registered',
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.controller.isFieldRegistered(testField), isTrue);
      expect(state.value, 'auto_registered');
    });

    testWidgets('uses custom controller when provided', (tester) async {
      final customController = FormixController(
        initialValue: {'custom_field': 'custom_value'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestFormFieldWidget(
              fieldId: const FormixFieldID<String>('custom_field'),
              controller: customController,
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.controller, same(customController));
      expect(state.value, 'custom_value');
    });

    testWidgets('falls back to Formix.controllerOf when no custom controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {'fallback_field': 'fallback_value'},
              fields: [
                FormixFieldConfig(
                  id: FormixFieldID<String>('fallback_field'),
                  initialValue: 'fallback_value',
                ),
              ],
              child: TestFormFieldWidget(
                fieldId: FormixFieldID<String>('fallback_field'),
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.value, 'fallback_value');
    });

    testWidgets('didChange updates field value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      state.didChange('updated_value');

      expect(state.controller.getValue(testField), 'updated_value');
      expect(state.value, 'updated_value');
    });

    testWidgets('setField is alias for didChange', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      state.setField('alias_value');

      expect(state.controller.getValue(testField), 'alias_value');
    });

    testWidgets('patchValue updates multiple fields', (tester) async {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: field1),
                FormixFieldConfig(id: field2),
              ],
              child: TestFormFieldWidget(fieldId: field1),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      state.patchValue({field1: 'value1', field2: 'value2'});

      expect(state.controller.getValue(field1), 'value1');
      expect(state.controller.getValue(field2), 'value2');
    });

    testWidgets('markAsTouched updates touched state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.isTouched, isFalse);

      state.markAsTouched();
      expect(state.isTouched, isTrue);
    });

    testWidgets(
      'onFieldChanged is called when field value changes externally',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                fields: [FormixFieldConfig(id: testField)],
                child: TestFormFieldWidget(fieldId: testField),
              ),
            ),
          ),
        );

        final state = tester.state<TestFormFieldWidgetState>(
          find.byType(TestFormFieldWidget),
        );
        state.controller.setValue(testField, 'external_change');

        expect(state.lastChangedValue, 'external_change');
      },
    );

    testWidgets('dispose cleans up resources', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(fieldId: testField),
            ),
          ),
        ),
      );

      tester.state<TestFormFieldWidgetState>(find.byType(TestFormFieldWidget));

      // Dispose should complete without errors
      await tester.pumpWidget(Container()); // Dispose the widget

      // Test passes if no exceptions are thrown during disposal
      expect(true, isTrue);
    });

    testWidgets('didUpdateWidget handles controller and fieldId changes', (
      tester,
    ) async {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {'field1': 'value1', 'field2': 'value2'},
              fields: [
                FormixFieldConfig(id: field1, initialValue: 'value1'),
                FormixFieldConfig(id: field2, initialValue: 'value2'),
              ],
              child: TestFormFieldWidget(fieldId: field1),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.value, 'value1');

      // Update widget with different field
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {'field1': 'value1', 'field2': 'value2'},
              fields: [
                FormixFieldConfig(id: field1, initialValue: 'value1'),
                FormixFieldConfig(id: field2, initialValue: 'value2'),
              ],
              child: TestFormFieldWidget(fieldId: field2),
            ),
          ),
        ),
      );

      expect(state.value, 'value2');
    });

    testWidgets('onSaved is called when state.save() is invoked', (
      tester,
    ) async {
      String? savedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: testField, initialValue: 'to_save'),
              ],
              child: TestFormFieldWidget(
                fieldId: testField,
                onSaved: (val) => savedValue = val,
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      state.save();
      expect(savedValue, 'to_save');
    });

    testWidgets('onReset is called when field is reset', (tester) async {
      bool resetCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(id: testField, initialValue: 'initial'),
              ],
              child: TestFormFieldWidget(
                fieldId: testField,
                onReset: () => resetCalled = true,
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      state.didChange('dirty');
      await tester.pump();

      state.resetField();
      await tester.pump();

      expect(resetCalled, true);
    });

    testWidgets('forceErrorText overrides validation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(
                fieldId: testField,
                forceErrorText: 'Forced Error',
              ),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.validation.isValid, false);
      expect(state.validation.errorMessage, 'Forced Error');
    });

    testWidgets('errorBuilder is used when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: testField,
                  validator: (_) => 'Validation Error',
                ),
              ],
              child: FormixRawFormField<String>(
                fieldId: testField,
                errorBuilder: (context, error) => Text('Custom Error: $error'),
                builder: (context, snapshot) {
                  if (snapshot.shouldShowError) {
                    return snapshot.errorBuilder!(
                      context,
                      snapshot.validation.errorMessage!,
                    );
                  }
                  return const Text('No Error');
                },
              ),
            ),
          ),
        ),
      );

      // Mark as touched to show error
      final state = tester.state<FormixFieldWidgetState<String>>(
        find.byType(FormixRawFormField<String>),
      );
      state.markAsTouched();
      await tester.pump();

      expect(find.text('Custom Error: Validation Error'), findsOneWidget);
    });

    testWidgets('enabled property is passed to state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFormFieldWidget(fieldId: testField, enabled: false),
            ),
          ),
        ),
      );

      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.enabled, false);
    });

    testWidgets('autovalidateMode overrides form validation mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              autovalidateMode: FormixAutovalidateMode.onUserInteraction,
              fields: [
                FormixFieldConfig(id: testField, validator: (_) => 'Error'),
              ],
              child: TestFormFieldWidget(
                fieldId: testField,
                validator: (_) => 'Error',
                autovalidateMode: FormixAutovalidateMode.always,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error immediately because of .always override
      final state = tester.state<TestFormFieldWidgetState>(
        find.byType(TestFormFieldWidget),
      );
      expect(state.validation.isValid, false);
      expect(state.validation.errorMessage, 'Error');
    });
  });

  group('FormixFieldTextMixin', () {
    // Test the mixin functionality through unit tests rather than widget tests
    // to avoid complex widget lifecycle issues
    test('valueToString converts values to strings', () {
      // Test through the concrete implementations
      final textState = TestTextFormFieldWidgetState();
      expect(textState.valueToString('hello'), 'hello');
      expect(textState.valueToString(null), '');

      final numberState = TestNumberFormFieldWidgetState();
      expect(numberState.valueToString(42), '42');
      expect(numberState.valueToString(null), '');
    });

    test('stringToValue converts strings back to values', () {
      final textState = TestTextFormFieldWidgetState();
      expect(textState.stringToValue('hello'), 'hello');
      expect(textState.stringToValue(''), '');

      final numberState = TestNumberFormFieldWidgetState();
      expect(numberState.stringToValue('42'), 42);
      expect(
        numberState.stringToValue('3.14'),
        null,
      ); // int.tryParse returns null for decimal
      expect(numberState.stringToValue('not_a_number'), null);
    });
  });
}
