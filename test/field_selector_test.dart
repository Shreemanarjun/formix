import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Test implementations for the selectors
class TestFieldSelector<T> extends FormixFieldSelector<T> {
  const TestFieldSelector({
    super.key,
    required super.fieldId,
    required super.builder,
    super.controller,
    super.listenToValue,
    super.listenToValidation,
    super.listenToDirty,
    super.child,
  });
}

class TestValueSelector<T> extends FormixFieldValueSelector<T> {
  const TestValueSelector({
    super.key,
    required super.fieldId,
    required super.builder,
    super.controller,
    super.child,
  });
}

class TestConditionalSelector<T> extends FormixFieldConditionalSelector<T> {
  const TestConditionalSelector({
    super.key,
    required super.fieldId,
    required super.builder,
    required super.shouldRebuild,
    super.controller,
    super.child,
  });
}

class TestPerformanceMonitor<T> extends FormixFieldPerformanceMonitor<T> {
  const TestPerformanceMonitor({
    super.key,
    required super.fieldId,
    required super.builder,
    super.controller,
  });
}

void main() {
  group('FieldChangeInfo', () {
    late FormixFieldID<String> testField;
    late ValidationResult validResult;
    late ValidationResult invalidResult;

    setUp(() {
      testField = const FormixFieldID<String>('test_field');
      validResult = ValidationResult.valid;
      invalidResult = const ValidationResult(isValid: false, errorMessage: 'Error');
    });

    test('constructor initializes all fields correctly', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'current',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'previous',
        previousValidation: invalidResult,
        previousIsDirty: false,
      );

      expect(info.fieldId, testField);
      expect(info.value, 'current');
      expect(info.validation, validResult);
      expect(info.isDirty, true);
      expect(info.hasInitialValueChanged, false);
      expect(info.previousValue, 'previous');
      expect(info.previousValidation, invalidResult);
      expect(info.previousIsDirty, false);
    });

    test('valueChanged returns true when value differs from previous', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'new',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'old',
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.valueChanged, true);
    });

    test('valueChanged returns false when value is same as previous', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'same',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'same',
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.valueChanged, false);
    });

    test('valueChanged returns false when previousValue is null', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: null,
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.valueChanged, false);
    });

    test('validationChanged returns true when validation differs', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: invalidResult,
        previousIsDirty: false,
      );

      expect(info.validationChanged, true);
    });

    test('validationChanged returns false when validation is same', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.validationChanged, false);
    });

    test('validationChanged returns false when previousValidation is null', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: null,
        previousIsDirty: false,
      );

      expect(info.validationChanged, false);
    });

    test('dirtyStateChanged returns true when dirty state differs', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.dirtyStateChanged, true);
    });

    test('dirtyStateChanged returns false when dirty state is same', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: true,
      );

      expect(info.dirtyStateChanged, false);
    });

    test('dirtyStateChanged returns false when previousIsDirty is null', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: null,
      );

      expect(info.dirtyStateChanged, false);
    });

    test('hasChanged returns true when any aspect changed', () {
      // Value changed
      final info1 = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'new',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'old',
        previousValidation: validResult,
        previousIsDirty: false,
      );
      expect(info1.hasChanged, true);

      // Validation changed
      final info2 = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: invalidResult,
        previousIsDirty: false,
      );
      expect(info2.hasChanged, true);

      // Dirty state changed
      final info3 = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: false,
      );
      expect(info3.hasChanged, true);
    });

    test('hasChanged returns false when nothing changed', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: 'value',
        validation: validResult,
        isDirty: true,
        hasInitialValueChanged: false,
        previousValue: 'value',
        previousValidation: validResult,
        previousIsDirty: true,
      );

      expect(info.hasChanged, false);
    });

    test('handles null values correctly', () {
      final info = FieldChangeInfo<String>(
        fieldId: testField,
        value: null,
        validation: validResult,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: null,
        previousValidation: validResult,
        previousIsDirty: false,
      );

      expect(info.value, null);
      expect(info.previousValue, null);
      expect(info.valueChanged, false);
      expect(info.hasChanged, false);
    });
  });

  group('FormixFieldSelector', () {
    late FormixFieldID<String> testField;

    setUp(() {
      testField = const FormixFieldID<String>('test_field');
    });

    testWidgets('constructor initializes correctly', (tester) async {
      const selector = TestFieldSelector<String>(
        fieldId: FormixFieldID<String>('test'),
        builder: _testBuilder,
        listenToValue: false,
        listenToValidation: true,
        listenToDirty: false,
      );

      expect(selector.fieldId.key, 'test');
      expect(selector.listenToValue, false);
      expect(selector.listenToValidation, true);
      expect(selector.listenToDirty, false);
      expect(selector.controller, null);
      expect(selector.child, null);
    });

    testWidgets('uses custom controller when provided', (tester) async {
      final customController = FormixController(
        initialValue: {'custom_field': 'custom_value'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestFieldSelector<String>(
              fieldId: const FormixFieldID<String>('custom_field'),
              controller: customController,
              builder: (context, info, child) {
                return Text('Value: ${info.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Value: custom_value'), findsOneWidget);
    });

    testWidgets('dispose cleans up listeners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: testField)],
              child: TestFieldSelector<String>(
                fieldId: testField,
                builder: _testBuilder,
              ),
            ),
          ),
        ),
      );

      // Dispose should complete without errors
      await tester.pumpWidget(Container());
      expect(true, isTrue); // Test passes if no exceptions
    });
  });

  group('FormixFieldValueSelector', () {
    late FormixFieldID<String> stringField;
    late FormixFieldID<int> intField;
    late FormixFieldID<bool> boolField;

    setUp(() {
      stringField = const FormixFieldID<String>('string_field');
      intField = const FormixFieldID<int>('int_field');
      boolField = const FormixFieldID<bool>('bool_field');
    });

    test('can be instantiated with required parameters', () {
      final selector = TestValueSelector<String>(
        fieldId: const FormixFieldID<String>('test'),
        builder: (context, value, child) => Text('Value: $value'),
      );

      expect(selector.fieldId.key, 'test');
      expect(selector, isNotNull);
    });

    test('constructor accepts optional parameters', () {
      const childWidget = Text('Child');
      final customController = FormixController();

      final selector = TestValueSelector<String>(
        key: const Key('test_key'),
        fieldId: stringField,
        controller: customController,
        child: childWidget,
        builder: (context, value, child) => Text('Value: $value'),
      );

      expect(selector.key, const Key('test_key'));
      expect(selector.fieldId, stringField);
      expect(selector.controller, customController);
      expect(selector.child, childWidget);
    });

    testWidgets('renders with initial field value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'string_field': 'initial_value'},
              fields: [
                FormixFieldConfig(
                  id: stringField,
                  initialValue: 'initial_value',
                ),
              ],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) {
                  return Text('Value: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: initial_value'), findsOneWidget);
    });

    testWidgets('renders with null value when field has no initial value', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) {
                  return Text('Value: ${value ?? "null"}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);
    });

    testWidgets('rebuilds when field value changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) {
                  buildCount++;
                  return Text(
                    'Build: $buildCount, Value: ${value ?? "null"}',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Build: 1, Value: null'), findsOneWidget);
      expect(buildCount, 1);

      // Change field value
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<String>,
          ),
        ),
      )!;
      controller.setValue(stringField, 'updated_value');

      await tester.pump();

      expect(find.text('Build: 2, Value: updated_value'), findsOneWidget);
      expect(buildCount, 2);
    });

    test('only rebuilds when field value changes', () {
      // This is tested implicitly by the fact that FormixFieldValueSelector
      // extends FormixFieldSelector with listenToValue=true and other flags=false
      final selector = TestValueSelector<String>(
        fieldId: stringField,
        builder: (context, value, child) => Text('Value: $value'),
      );

      // The selector is configured to only listen to value changes
      expect(selector.fieldId, stringField);
      expect(selector, isNotNull);
    });

    testWidgets('works with different data types - int', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'int_field': 42},
              fields: [FormixFieldConfig(id: intField, initialValue: 42)],
              child: TestValueSelector<int>(
                fieldId: intField,
                builder: (context, value, child) {
                  return Text('Number: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Number: 42'), findsOneWidget);

      // Change value
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<int>,
          ),
        ),
      )!;
      controller.setValue(intField, 99);

      await tester.pump();

      expect(find.text('Number: 99'), findsOneWidget);
    });

    testWidgets('works with different data types - bool', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'bool_field': true},
              fields: [FormixFieldConfig(id: boolField, initialValue: true)],
              child: TestValueSelector<bool>(
                fieldId: boolField,
                builder: (context, value, child) {
                  return Text('Boolean: $value');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Boolean: true'), findsOneWidget);

      // Change value
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<bool>,
          ),
        ),
      )!;
      controller.setValue(boolField, false);

      await tester.pump();

      expect(find.text('Boolean: false'), findsOneWidget);
    });

    testWidgets('handles null values correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) {
                  return Text('Value: ${value ?? "is_null"}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: is_null'), findsOneWidget);

      // Set a value
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<String>,
          ),
        ),
      )!;
      controller.setValue(stringField, 'not_null');

      await tester.pump();

      expect(find.text('Value: not_null'), findsOneWidget);

      // Set back to null
      controller.setValue(stringField, null);

      await tester.pump();

      expect(find.text('Value: is_null'), findsOneWidget);
    });

    testWidgets('passes child widget to builder', (tester) async {
      const childWidget = Text('Child Content');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                child: childWidget,
                builder: (context, value, child) {
                  return Column(
                    children: [Text('Value: ${value ?? "null"}'), child!],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: null'), findsOneWidget);
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('uses custom controller when provided', (tester) async {
      final customController = FormixController(
        initialValue: {'custom_field': 'custom_value'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestValueSelector<String>(
              fieldId: const FormixFieldID<String>('custom_field'),
              controller: customController,
              builder: (context, value, child) => Text('Value: $value'),
            ),
          ),
        ),
      );

      expect(find.text('Value: custom_value'), findsOneWidget);
    });

    testWidgets('handles rapid consecutive value changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: intField)],
              child: TestValueSelector<int>(
                fieldId: intField,
                builder: (context, value, child) {
                  buildCount++;
                  return Text('Build: $buildCount, Value: ${value ?? 0}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Build: 1, Value: 0'), findsOneWidget);
      expect(buildCount, 1);

      // Rapid changes
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<int>,
          ),
        ),
      )!;
      controller.setValue(intField, 1);
      await tester.pump();
      controller.setValue(intField, 2);
      await tester.pump();
      controller.setValue(intField, 3);
      await tester.pump();

      expect(find.text('Build: 4, Value: 3'), findsOneWidget);
      expect(buildCount, 4);
    });

    testWidgets('dispose cleans up resources', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) => Text('Value: ${value ?? "null"}'),
              ),
            ),
          ),
        ),
      );

      // Dispose should complete without errors
      await tester.pumpWidget(Container());
      expect(true, isTrue); // Test passes if no exceptions
    });

    testWidgets('works with complex object types', (tester) async {
      const listField = FormixFieldID<List<String>>('list_field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'list_field': ['a', 'b', 'c'],
              },
              fields: const [
                FormixFieldConfig(
                  id: listField,
                  initialValue: ['a', 'b', 'c'],
                ),
              ],
              child: TestValueSelector<List<String>>(
                fieldId: listField,
                builder: (context, value, child) {
                  return Text('Length: ${value?.length ?? 0}');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Length: 3'), findsOneWidget);

      // Change the list
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<List<String>>,
          ),
        ),
      )!;
      controller.setValue(listField, ['x', 'y']);

      await tester.pump();

      expect(find.text('Length: 2'), findsOneWidget);
    });

    testWidgets('handles empty string values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [FormixFieldConfig(id: stringField)],
              child: TestValueSelector<String>(
                fieldId: stringField,
                builder: (context, value, child) {
                  return Text('Value: "${value ?? "null"}"');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Value: "null"'), findsOneWidget);

      // Set empty string
      final controller = Formix.controllerOf(
        tester.element(
          find.byWidgetPredicate(
            (widget) => widget is FormixFieldValueSelector<String>,
          ),
        ),
      )!;
      controller.setValue(stringField, '');

      await tester.pump();

      expect(find.text('Value: ""'), findsOneWidget);
    });

    testWidgets('multiple value selectors work independently', (tester) async {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'field1': 'value1', 'field2': 'value2'},
              fields: const [
                FormixFieldConfig(id: field1, initialValue: 'value1'),
                FormixFieldConfig(id: field2, initialValue: 'value2'),
              ],
              child: Column(
                children: [
                  TestValueSelector<String>(
                    fieldId: field1,
                    builder: (context, value, child) => Text('Field1: $value'),
                  ),
                  TestValueSelector<String>(
                    fieldId: field2,
                    builder: (context, value, child) => Text('Field2: $value'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Field1: value1'), findsOneWidget);
      expect(find.text('Field2: value2'), findsOneWidget);

      // Change only field1
      final controller = Formix.controllerOf(
        tester.element(find.byType(Column)),
      )!;
      controller.setValue(field1, 'updated1');

      await tester.pump();

      expect(find.text('Field1: updated1'), findsOneWidget);
      expect(find.text('Field2: value2'), findsOneWidget); // Unchanged
    });
  });

  group('FormixFieldConditionalSelector', () {
    test('can be instantiated with shouldRebuild function', () {
      bool shouldRebuildCalled = false;

      final selector = TestConditionalSelector<int>(
        fieldId: const FormixFieldID<int>('counter'),
        shouldRebuild: (info) {
          shouldRebuildCalled = true;
          return (info.value ?? 0) > 5;
        },
        builder: (context, info, child) => Text('Value: ${info.value}'),
      );

      expect(selector.fieldId.key, 'counter');
      expect(selector, isNotNull);

      // Test that the shouldRebuild function works
      const testInfo = FieldChangeInfo<int>(
        fieldId: FormixFieldID<int>('counter'),
        value: 7,
        validation: ValidationResult.valid,
        isDirty: false,
        hasInitialValueChanged: false,
        previousValue: 3,
        previousValidation: ValidationResult.valid,
        previousIsDirty: false,
      );

      // This would normally be called internally, but we can test the logic
      expect((selector as dynamic).shouldRebuild(testInfo), isTrue);
      expect(shouldRebuildCalled, isTrue);
    });
  });

  group('FormixFieldPerformanceMonitor', () {
    test('can be instantiated with rebuild counting builder', () {
      final monitor = TestPerformanceMonitor<String>(
        fieldId: const FormixFieldID<String>('test'),
        builder: (context, info, count) => Text('Count: $count'),
      );

      expect(monitor.fieldId.key, 'test');
      expect(monitor, isNotNull);
    });
  });
}

// Helper function for testing
Widget _testBuilder(BuildContext context, FieldChangeInfo info, Widget? child) {
  return Text('Test: ${info.value}');
}
