import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FormFieldSchema.validate branches', () {
    test('async validator error is captured', () async {
      final schema = TextFieldSchema(
        id: const FormixFieldID<String>('t'),
        initialValue: '',
        asyncValidator: (v) async => 'async says no',
      );
      final errors = await schema.validate('x', const {});
      expect(errors, contains('async says no'));
    });

    test('async validator throwing is wrapped in validationFailed', () async {
      final schema = TextFieldSchema(
        id: const FormixFieldID<String>('t'),
        initialValue: '',
        asyncValidator: (v) async => throw Exception('kaboom'),
      );
      final errors = await schema.validate('x', const {});
      expect(errors.any((e) => e.contains('kaboom')), isTrue);
    });

    test('required empty iterable is treated as empty', () async {
      const schema = SelectionFieldSchema<List<String>>(
        id: FormixFieldID<List<String>>('sel'),
        initialValue: <String>[],
        isRequired: true,
        options: [<String>[]],
      );
      final errors = await schema.validate(const <String>[], const {});
      // empty iterable + required -> required error
      expect(errors, isNotEmpty);
    });

    test('DateFieldSchema flags minDate/maxDate violations', () async {
      final schema = DateFieldSchema(
        id: const FormixFieldID<DateTime>('d'),
        initialValue: DateTime(2020),
        minDate: DateTime(2020, 1, 1),
        maxDate: DateTime(2020, 12, 31),
      );
      final tooEarly = await schema.validate(DateTime(2019), const {});
      expect(tooEarly, isNotEmpty);
      final tooLate = await schema.validate(DateTime(2021), const {});
      expect(tooLate, isNotEmpty);
      final ok = await schema.validate(DateTime(2020, 6, 1), const {});
      expect(ok, isEmpty);
      // null short-circuit path
      final nullVal = await schema.validate(null, const {});
      expect(nullVal, isEmpty);
    });

    test('NumberFieldSchema flags min and max', () async {
      const schema = NumberFieldSchema(
        id: FormixFieldID<num>('n'),
        initialValue: 0,
        min: 1,
        max: 10,
      );
      expect(await schema.validate(0, const {}), isNotEmpty);
      expect(await schema.validate(11, const {}), isNotEmpty);
      expect(await schema.validate(5, const {}), isEmpty);
    });

    test('SelectionFieldSchema flags value not in options', () async {
      const schema = SelectionFieldSchema<String>(
        id: FormixFieldID<String>('sel'),
        initialValue: 'a',
        options: ['a', 'b'],
      );
      expect(await schema.validate('c', const {}), isNotEmpty);
      expect(await schema.validate('a', const {}), isEmpty);
    });
  });

  group('FormSchema.submit', () {
    test('success with onSubmit handler', () async {
      var submitted = false;
      final schema = FormSchema(
        fields: [
          const TextFieldSchema(
            id: FormixFieldID<String>('t'),
            initialValue: '',
          ),
        ],
        onSubmit: (values) async => submitted = true,
      );
      final result = await schema.submit({'t': 'ok'});
      expect(result.success, isTrue);
      expect(submitted, isTrue);
    });

    test('success returns data when no onSubmit handler', () async {
      const schema = FormSchema(
        fields: [
          TextFieldSchema(id: FormixFieldID<String>('t'), initialValue: ''),
        ],
      );
      final result = await schema.submit({'t': 'ok'});
      expect(result.success, isTrue);
      expect(result.data, {'t': 'ok'});
    });

    test('validation failure short-circuits submit', () async {
      const schema = FormSchema(
        fields: [
          TextFieldSchema(
            id: FormixFieldID<String>('t'),
            initialValue: '',
            isRequired: true,
          ),
        ],
      );
      final result = await schema.submit({'t': ''});
      expect(result.success, isFalse);
      expect(result.validationResult, isNotNull);
    });

    test('onSubmit throwing returns failure', () async {
      final schema = FormSchema(
        fields: [
          const TextFieldSchema(id: FormixFieldID<String>('t'), initialValue: ''),
        ],
        onSubmit: (_) async => throw Exception('server error'),
      );
      final result = await schema.submit({'t': 'x'});
      expect(result.success, isFalse);
      expect(result.error, contains('server error'));
    });
  });

  group('SchemaBasedFormController', () {
    FormSchema buildSchema({bool required = true}) => FormSchema(
      fields: [
        TextFieldSchema(
          id: const FormixFieldID<String>('name'),
          initialValue: '',
          isRequired: required,
        ),
        ConditionalFieldSchema<String>(
          id: const FormixFieldID<String>('extra'),
          initialValue: '',
          visibilityCondition: (state) => state['name'] == 'show',
        ),
      ],
    );

    testWidgets('validateForm updates field notifiers and reflects errors', (tester) async {
      final controller = SchemaBasedFormController(schema: buildSchema());
      addTearDown(controller.dispose);

      // Need a widget context for focus/error handling in some paths.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      final result = await controller.validateForm();
      expect(result.isValid, isFalse);
      final notifier = controller.fieldValidationNotifier<dynamic>(const FormixFieldID<String>('name'));
      expect(notifier.value.isValid, isFalse);
    });

    testWidgets('submitForm failure focuses first error', (tester) async {
      final controller = SchemaBasedFormController(schema: buildSchema());
      addTearDown(controller.dispose);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      final result = await controller.submitForm();
      expect(result.success, isFalse);
    });

    test('submitForm success when valid', () async {
      var called = false;
      final schema = FormSchema(
        fields: [
          const TextFieldSchema(id: FormixFieldID<String>('name'), initialValue: ''),
        ],
        onSubmit: (_) async => called = true,
      );
      final controller = SchemaBasedFormController(schema: schema, initialValue: {'name': 'ok'});
      addTearDown(controller.dispose);
      final result = await controller.submitForm();
      expect(result.success, isTrue);
      expect(called, isTrue);
    });

    test('visibleFields, isFormDirty, isFieldModified, resetForm', () {
      final controller = SchemaBasedFormController(schema: buildSchema());
      addTearDown(controller.dispose);
      const name = FormixFieldID<String>('name');

      expect(controller.isFormDirty, isFalse);
      // conditional field 'extra' hidden until name == 'show'
      expect(controller.visibleFields.map((f) => f.id.key), isNot(contains('extra')));

      controller.setValue(name, 'show');
      expect(controller.isFieldModified(name), isTrue);
      expect(controller.isFormDirty, isTrue);
      expect(controller.visibleFields.map((f) => f.id.key), contains('extra'));

      controller.resetForm();
      expect(controller.isFormDirty, isFalse);
    });
  });

  group('FormixData (form_state)', () {
    FormixData valid() => FormixData.withCalculatedCounts(
      values: {'a': 1, 'user.name': 'bob'},
      validations: {
        'a': ValidationResult.valid,
        'user.name': const ValidationResult(
          isValid: false,
          errorMessage: 'bad name',
        ),
      },
      dirtyStates: {'a': true, 'user.name': false},
      touchedStates: {'a': false},
    );

    test('errors and errorMessages expose failing fields', () {
      final s = valid();
      expect(s.errors, {'user.name': 'bad name'});
      expect(s.errorMessages, ['bad name']);
    });

    test('toNestedMap builds nested maps from dot keys', () {
      final s = valid();
      final nested = s.toNestedMap();
      expect(nested['a'], 1);
      expect((nested['user'] as Map)['name'], 'bob');
    });

    test('isGroupValid / isGroupDirty operate on prefixes', () {
      final s = valid();
      expect(s.isGroupValid('user'), isFalse);
      expect(s.isGroupValid('missing'), isTrue); // no members -> every() true
      expect(s.isGroupDirty('user'), isFalse);
    });

    test('requireValue returns value or throws for null/missing', () {
      final s = valid();
      expect(s.requireValue(const FormixFieldID<int>('a')), 1);
      expect(
        () => s.requireValue(const FormixFieldID<String>('nope')),
        throwsStateError,
      );
    });

    test('hashCode is stable and equal states share it', () {
      final a = valid();
      final b = valid();
      expect(a.hashCode, b.hashCode);
      expect(a, b);
    });

    test('equality fast path detects differing scalar counts', () {
      final a = valid();
      final b = a.copyWith(isSubmitting: true);
      expect(a == b, isFalse);
    });

    test('equality identity fast path when same collections reused', () {
      final a = valid();
      // copyWith with no map changes reuses the same map references.
      final b = a.copyWith(currentStep: a.currentStep);
      expect(a, b);
    });
  });
}
