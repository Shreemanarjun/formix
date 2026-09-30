import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

// Mock persistence for testing
class MockPersistence implements FormixPersistence {
  @override
  Future<Map<String, dynamic>?> getSavedState(String formId) async => null;

  @override
  Future<void> saveFormState(String formId, Map<String, dynamic> data) async {}

  @override
  Future<void> clearSavedState(String formId) async {}
}

void main() {
  group('FormState', () {
    test('constructor creates correct initial state', () {
      final state = FormixData.withCalculatedCounts(
        values: {'field1': 'value1'},
        validations: {'field1': ValidationResult.valid},
        dirtyStates: {'field1': false},
        touchedStates: {'field1': false},
        isSubmitting: false,
      );

      expect(state.values, {'field1': 'value1'});
      expect(state.validations, {'field1': ValidationResult.valid});
      expect(state.dirtyStates, {'field1': false});
      expect(state.touchedStates, {'field1': false});
      expect(state.isSubmitting, false);
    });

    test('copyWith creates new instance with updated values', () {
      final original = FormixData.withCalculatedCounts(
        values: {'field1': 'value1'},
        validations: {'field1': ValidationResult.valid},
        dirtyStates: {'field1': false},
        touchedStates: {'field1': false},
        isSubmitting: false,
      );

      final copy = original.copyWith(
        values: {'field1': 'value2'},
        isSubmitting: true,
      );

      expect(copy.values, {'field1': 'value2'});
      expect(copy.isSubmitting, true);
      expect(copy.validations, original.validations); // Unchanged
    });

    test('isValid returns true when all validations pass', () {
      final state = FormixData.withCalculatedCounts(
        validations: {
          'field1': ValidationResult.valid,
          'field2': ValidationResult.valid,
        },
      );

      expect(state.isValid, true);
    });

    test('isValid returns false when any validation fails', () {
      final state = FormixData.withCalculatedCounts(
        validations: {
          'field1': ValidationResult.valid,
          'field2': const ValidationResult(isValid: false, errorMessage: 'Error'),
        },
      );

      expect(state.isValid, false);
    });

    test('isDirty returns true when any field is dirty', () {
      final state = FormixData.withCalculatedCounts(
        dirtyStates: {'field1': false, 'field2': true},
      );

      expect(state.isDirty, true);
    });

    test('isDirty returns false when no fields are dirty', () {
      final state = FormixData.withCalculatedCounts(
        dirtyStates: {'field1': false, 'field2': false},
      );

      expect(state.isDirty, false);
    });

    test('getValue returns typed value when type matches', () {
      final state = FormixData.withCalculatedCounts(values: {'field1': 'test'});

      expect(state.getValue<String>(const FormixFieldID<String>('field1')), 'test');
    });

    test('getValue returns null when type does not match', () {
      final state = FormixData.withCalculatedCounts(values: {'field1': 'test'});

      expect(state.getValue<int>(const FormixFieldID<int>('field1')), null);
    });

    test('requireValue throws when value is null', () {
      const state = FormixData();
      expect(
        () => state.requireValue(const FormixFieldID<String>('field1')),
        throwsA(isA<StateError>()),
      );
    });

    test('getValidation returns validation result for field', () {
      const validation = ValidationResult(
        isValid: false,
        errorMessage: 'Error',
      );
      final state = FormixData.withCalculatedCounts(
        validations: {'field1': validation},
      );

      expect(state.getValidation(const FormixFieldID<String>('field1')), validation);
    });

    test('getValidation returns valid result for unregistered field', () {
      const state = FormixData();

      expect(
        state.getValidation(const FormixFieldID<String>('field1')).isValid,
        true,
      );
    });

    test('isFieldDirty returns dirty state for field', () {
      final state = FormixData.withCalculatedCounts(
        dirtyStates: {'field1': true},
      );

      expect(state.isFieldDirty(const FormixFieldID<String>('field1')), true);
      expect(state.isFieldDirty(const FormixFieldID<String>('field2')), false);
    });

    test('isFieldTouched returns touched state for field', () {
      final state = FormixData.withCalculatedCounts(
        touchedStates: {'field1': true},
      );

      expect(state.isFieldTouched(const FormixFieldID<String>('field1')), true);
      expect(state.isFieldTouched(const FormixFieldID<String>('field2')), false);
    });
  });

  group('FormixFieldConfig', () {
    test('constructor creates config correctly', () {
      const id = FormixFieldID<String>('test');
      final config = FormixFieldConfig<String>(
        id: id,
        initialValue: 'initial',
        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
        label: 'Test Field',
        hint: 'Enter value',
        debounceDuration: const Duration(milliseconds: 500),
      );

      expect(config.id, id);
      expect(config.initialValue, 'initial');
      expect(config.label, 'Test Field');
      expect(config.hint, 'Enter value');
      expect(config.debounceDuration, const Duration(milliseconds: 500));
    });

    test('toField converts config to field correctly', () {
      const id = FormixFieldID<String>('test');
      final config = FormixFieldConfig<String>(
        id: id,
        initialValue: 'initial',
        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
        label: 'Test Field',
      );

      final field = config.toField();

      expect(field.id, id);
      expect(field.initialValue, 'initial');
      expect(field.label, 'Test Field');
      expect(field.validator, isNotNull);
    });

    test('equality works correctly', () {
      const id1 = FormixFieldID<String>('test');
      const id2 = FormixFieldID<String>('test');

      const config1 = FormixFieldConfig<String>(id: id1, initialValue: 'test');
      const config2 = FormixFieldConfig<String>(id: id2, initialValue: 'test');
      const config3 = FormixFieldConfig<String>(
        id: id1,
        initialValue: 'different',
      );

      expect(config1 == config2, true);
      expect(config1 == config3, false);
    });

    test('hashCode works correctly', () {
      const id = FormixFieldID<String>('test');
      const config1 = FormixFieldConfig<String>(id: id, initialValue: 'test');
      const config2 = FormixFieldConfig<String>(id: id, initialValue: 'test');

      expect(config1.hashCode, config2.hashCode);
    });
  });

  group('FormixController', () {
    late FormixFieldID<String> stringField;
    late FormixFieldID<int> intField;

    setUp(() {
      stringField = const FormixFieldID<String>('string_field');
      intField = const FormixFieldID<int>('int_field');
    });

    test('constructor initializes with correct state', () {
      final controller = FormixController(
        initialValue: {'field1': 'value1'},
        fields: [
          const FormixField<String>(
            id: FormixFieldID<String>('field1'),
            initialValue: 'value1',
          ),
        ],
      );

      expect(controller.state.values['field1'], 'value1');
      expect(controller.initialValue['field1'], 'value1');
      expect(
        controller.isFieldRegistered(const FormixFieldID<String>('field1')),
        true,
      );
    });

    test('getValue returns correct typed value', () {
      final controller = FormixController(initialValue: {'field1': 'test'});

      expect(controller.getValue(const FormixFieldID<String>('field1')), 'test');
    });

    test(
      'getValue returns initial value for unregistered fields (smart fallback)',
      () {
        final controller = FormixController(
          initialValue: {'field1': 'initial'},
        );
        expect(controller.getValue(const FormixFieldID<String>('field1')), 'initial');
      },
    );

    test('getValue returns null for unknown fields', () {
      final controller = FormixController();
      expect(controller.getValue(const FormixFieldID<String>('unknown')), null);
    });

    test('requireValue throws on null value', () {
      final controller = FormixController();
      expect(
        () => controller.requireValue(const FormixFieldID<String>('unknown')),
        throwsA(isA<StateError>()),
      );
    });

    test('setValue updates value and triggers validation', () {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: stringField,
            initialValue: '',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
        ],
      );

      controller.setValue(stringField, 'valid');

      expect(controller.getValue(stringField), 'valid');
      expect(controller.getValidation(stringField).isValid, true);
      expect(controller.isFieldDirty(stringField), true);
    });

    test('setValue throws on type mismatch', () {
      final controller = FormixController(initialValue: {'field1': 'string'});

      expect(
        () => controller.setValue(const FormixFieldID<int>('field1'), 123),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('registerField adds field definition and initializes state', () {
      final controller = FormixController();

      final field = FormixField<String>(
        id: stringField,
        initialValue: 'initial',
        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
      );

      controller.registerField(field);

      expect(controller.isFieldRegistered(stringField), true);
      expect(controller.getValue(stringField), 'initial');
      expect(controller.getValidation(stringField).isValid, true);
    });

    test('unregisterField removes field from state', () {
      final controller = FormixController(
        fields: [FormixField<String>(id: stringField, initialValue: 'test')],
      );

      expect(controller.isFieldRegistered(stringField), true);

      controller.unregisterField(stringField);

      expect(controller.isFieldRegistered(stringField), false);
      expect(controller.state.values.containsKey('string_field'), false);
    });

    test('markAsTouched updates touched state', () {
      final controller = FormixController(
        fields: [FormixField<String>(id: stringField, initialValue: 'initial')],
      );

      expect(controller.isFieldTouched(stringField), false);

      controller.markAsTouched(stringField);

      expect(controller.isFieldTouched(stringField), true);
    });

    test('setSubmitting updates submitting state', () {
      final controller = FormixController();

      expect(controller.isSubmitting, false);

      controller.setSubmitting(true);

      expect(controller.isSubmitting, true);
    });

    test('validate runs validation on all fields', () {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: stringField,
            initialValue: '',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
          FormixField<int>(
            id: intField,
            initialValue: 5,
            validator: (v) => (v ?? 0) < 10 ? 'Must be at least 10' : null,
          ),
        ],
      );

      final isValid = controller.validate();

      expect(isValid, false);
      expect(controller.getValidation(stringField).isValid, false);
      expect(controller.getValidation(intField).isValid, false);
    });

    test('reset restores initial values', () {
      final controller = FormixController(
        initialValue: {'field1': 'initial'},
        fields: [
          const FormixField<String>(
            id: FormixFieldID<String>('field1'),
            initialValue: 'initial',
          ),
        ],
      );

      controller.setValue(const FormixFieldID<String>('field1'), 'changed');
      expect(controller.getValue(const FormixFieldID<String>('field1')), 'changed');

      controller.reset();

      expect(controller.getValue(const FormixFieldID<String>('field1')), 'initial');
      expect(controller.isFieldDirty(const FormixFieldID<String>('field1')), false);
    });

    test('resetFields resets specific fields', () {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      final controller = FormixController(
        initialValue: {'field1': 'initial1', 'field2': 'initial2'},
        fields: [
          const FormixField<String>(id: field1, initialValue: 'initial1'),
          const FormixField<String>(id: field2, initialValue: 'initial2'),
        ],
      );

      controller.setValue(field1, 'changed1');
      controller.setValue(field2, 'changed2');

      controller.resetFields([field1]);

      expect(controller.getValue(field1), 'initial1');
      expect(controller.getValue(field2), 'changed2');
    });

    test('async validation works with debouncing', () async {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: stringField,
            initialValue: '',
            asyncValidator: (v) async {
              await Future.delayed(const Duration(milliseconds: 100));
              return (v?.isEmpty ?? true) ? 'Async required' : null;
            },
            debounceDuration: const Duration(milliseconds: 50),
          ),
        ],
      );

      controller.setValue(stringField, 'test');

      // Should initially be validating
      expect(controller.getValidation(stringField).isValidating, true);

      // Wait for async validation to complete
      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.getValidation(stringField).isValid, true);
    });
  });

  group('FormixController', () {
    test('extends FormixController correctly', () {
      final controller = FormixController(initialValue: {'field1': 'value1'});

      expect(controller.values, {'field1': 'value1'});
      expect(controller.isDirty, false);
      expect(controller.isSubmitting, false);
    });

    test('getFieldNotifier creates and caches notifiers', () {
      final controller = FormixController();
      const fieldId = FormixFieldID<String>('test');

      final notifier1 = controller.getFieldNotifier(fieldId);
      final notifier2 = controller.getFieldNotifier(fieldId);

      expect(notifier1, same(notifier2));
      expect(notifier1.value, null);
    });

    test('fieldValidationNotifier creates and caches notifiers', () {
      final controller = FormixController();
      const fieldId = FormixFieldID<String>('test');

      final notifier1 = controller.fieldValidationNotifier(fieldId);
      final notifier2 = controller.fieldValidationNotifier(fieldId);

      expect(notifier1, same(notifier2));
      expect(notifier1.value.isValid, true);
    });

    test('fieldDirtyNotifier creates and caches notifiers', () {
      final controller = FormixController();
      const fieldId = FormixFieldID<String>('test');

      final notifier1 = controller.fieldDirtyNotifier(fieldId);
      final notifier2 = controller.fieldDirtyNotifier(fieldId);

      expect(notifier1, same(notifier2));
      expect(notifier1.value, false);
    });

    test('fieldTouchedNotifier creates and caches notifiers', () {
      final controller = FormixController();
      const fieldId = FormixFieldID<String>('test');

      final notifier1 = controller.fieldTouchedNotifier(fieldId);
      final notifier2 = controller.fieldTouchedNotifier(fieldId);

      expect(notifier1, same(notifier2));
      expect(notifier1.value, false);
    });

    test('global notifiers are created lazily', () {
      final controller = FormixController();

      expect(controller.isDirtyNotifier.value, false);
      expect(controller.isValidNotifier.value, true);
      expect(controller.isSubmittingNotifier.value, false);
    });

    test('toMap returns unmodifiable copy of values', () {
      final controller = FormixController(initialValue: {'field1': 'value1'});

      final map = controller.toMap();
      expect(map, {'field1': 'value1'});

      // Should be unmodifiable
      expect(() => map['field1'] = 'modified', throwsUnsupportedError);
    });

    test('getChangedValues returns only dirty fields', () {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      final controller = FormixController(
        initialValue: {'field1': 'initial1', 'field2': 'initial2'},
        fields: [
          const FormixField<String>(id: field1, initialValue: 'initial1'),
          const FormixField<String>(id: field2, initialValue: 'initial2'),
        ],
      );

      controller.setValue(field1, 'changed1');

      final changed = controller.getChangedValues();
      expect(changed, {'field1': 'changed1'});
      expect(changed.containsKey('field2'), false);
    });

    test('updateFromMap updates registered fields', () {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      final controller = FormixController(
        fields: [
          const FormixField<String>(id: field1, initialValue: ''),
          const FormixField<String>(id: field2, initialValue: ''),
        ],
      );

      controller.updateFromMap({'field1': 'updated', 'field3': 'ignored'});

      expect(controller.getValue(field1), 'updated');
      expect(controller.getValue(field2), ''); // Unchanged
    });

    test('resetToValues updates initial values and resets', () {
      final controller = FormixController(initialValue: {'field1': 'old'});

      controller.resetToValues({'field1': 'new'});

      expect(controller.initialValue['field1'], 'new');
      expect(controller.getValue(const FormixFieldID<String>('field1')), 'new');
    });

    test('focus management registers focus nodes', () {
      final controller = FormixController();
      const fieldId = FormixFieldID<String>('test');
      final focusNode = FocusNode();

      controller.registerFocusNode(fieldId, focusNode);
      controller.focusField(fieldId);

      // In test environment, focus might not work, but registration should work
      expect(() => controller.focusField(fieldId), returnsNormally);

      focusNode.dispose();
    });

    test('focusFirstError works with registered nodes', () {
      const field1 = FormixFieldID<String>('field1');
      const field2 = FormixFieldID<String>('field2');

      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field1,
            initialValue: '',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
          FormixField<String>(
            id: field2,
            initialValue: '',
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
        ],
      );

      final focusNode1 = FocusNode();
      final focusNode2 = FocusNode();

      controller.registerFocusNode(field1, focusNode1);
      controller.registerFocusNode(field2, focusNode2);

      controller.validate();

      // Should not throw error
      expect(() => controller.focusFirstError(), returnsNormally);

      focusNode1.dispose();
      focusNode2.dispose();
    });

    test('dispose works without errors', () {
      final controller = FormixController();

      // Create some notifiers
      controller.getFieldNotifier(const FormixFieldID<String>('test'));
      controller.fieldValidationNotifier(const FormixFieldID<String>('test'));

      // Dispose should work without errors
      expect(() => controller.dispose(), returnsNormally);
    });
  });

  group('FormixParameter', () {
    test('constructor creates parameter correctly', () {
      final param = FormixParameter(
        initialValue: const {'field1': 'value1'},
        fields: const [FormixFieldConfig(id: FormixFieldID<String>('field1'))],
        persistence: MockPersistence(),
        formId: 'test_form',
      );

      expect(param.initialValue, {'field1': 'value1'});
      expect(param.fields.length, 1);
      expect(param.formId, 'test_form');
    });

    test('equality works correctly', () {
      const param1 = FormixParameter(
        initialValue: {'field1': 'value1'},
        fields: [FormixFieldConfig(id: FormixFieldID<String>('field1'))],
      );

      const param2 = FormixParameter(
        initialValue: {'field1': 'value1'},
        fields: [FormixFieldConfig(id: FormixFieldID<String>('field1'))],
      );

      const param3 = FormixParameter(initialValue: {'field1': 'value2'});

      expect(param1 == param2, true);
      expect(param1 == param3, false);
    });

    test('hashCode works correctly', () {
      const param1 = FormixParameter(initialValue: {'field1': 'value1'});
      const param2 = FormixParameter(initialValue: {'field1': 'value1'});

      expect(param1.hashCode, param2.hashCode);
    });
  });

  group('Controller construction', () {
    test('fromParameter creates controller correctly', () {
      const param = FormixParameter(
        initialValue: {'field1': 'value1'},
        fields: [FormixFieldConfig(id: FormixFieldID<String>('field1'))],
      );

      final controller = FormixController.fromParameter(param);
      addTearDown(controller.dispose);

      expect(controller.getValue(const FormixFieldID<String>('field1')), 'value1');
    });

    test('default controller is usable', () {
      final controller = FormixController();
      addTearDown(controller.dispose);

      expect(controller, isNotNull);
      expect(controller.values, isEmpty);
      expect(controller.isDirty, false);
      expect(controller.isSubmitting, false);
    });
  });
}
