import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Type Safety Edge Cases', () {
    test('isTypeValid correctly handles non-nullable types explicitly', () {
      const stringId = FormixFieldID<String>('name');
      const nullableStringId = FormixFieldID<String?>('name_opt');

      expect(stringId.isTypeValid('hello'), true);
      expect(stringId.isTypeValid(null), false); // REVERTED behavior: null is NOT String

      expect(nullableStringId.isTypeValid('hello'), true);
      expect(nullableStringId.isTypeValid(null), true); // null IS String?
    });

    test('setValue enforces strict nullability for non-nullable IDs', () {
      const param = FormixParameter(
        formId: 'test_form',
        namespace: 'test',
        fields: [
          FormixFieldConfig<String>(id: FormixFieldID<String>('name')),
        ],
      );
      final controller = FormixController.fromParameter(param);
      addTearDown(controller.dispose);

      // Should succeed with valid String
      controller.setValue(const FormixFieldID<String>('name'), 'John');
      expect(controller.getValue(const FormixFieldID<String>('name')), 'John');

      // Should throw or fail depending on how strict mode works in the version
      // FormixController.setValue calls _batchUpdate(strict: true)

      expect(
        () => controller.setValue(const FormixFieldID<String>('name'), null as dynamic),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('setValue allows null for nullable IDs', () {
      const param = FormixParameter(
        formId: 'test_form',
        namespace: 'test',
        fields: [
          FormixFieldConfig<String?>(id: FormixFieldID<String?>('name')),
        ],
      );
      final controller = FormixController.fromParameter(param);
      addTearDown(controller.dispose);

      controller.setValue(const FormixFieldID<String?>('name'), 'John');
      expect(controller.getValue(const FormixFieldID<String?>('name')), 'John');

      // Should succeed with null
      controller.setValue(const FormixFieldID<String?>('name'), null);
      expect(controller.getValue(const FormixFieldID<String?>('name')), isNull);
    });

    test('re-registering field with different type preserves value but might cause inconsistencies', () {
      const nameStrId = FormixFieldID<String>('name');
      const nameIntId = FormixFieldID<int>('name');

      const param = FormixParameter(
        formId: 'test_form',
        namespace: 'test',
        fields: [
          FormixFieldConfig<String>(id: nameStrId),
        ],
      );
      final controller = FormixController.fromParameter(param);
      addTearDown(controller.dispose);

      controller.setValue(nameStrId, 'John');
      expect(controller.getValue(nameStrId), 'John');

      // Re-register as int
      controller.registerFields([
        const FormixFieldConfig<int>(id: nameIntId).toField(),
      ]);

      // The physical value 'John' remains in the state map, but getValue<int>
      // returns null because 'John' is not a valid int!
      // This is expected: the type system protects the consumer.
      expect(controller.getValue(nameIntId), isNull);
      expect(controller.state.values[nameIntId.key], 'John');

      // But we can update the value with a valid int
      controller.setValue(nameIntId, 123);
      expect(controller.getValue(nameIntId), 123);

      // Now set a String - should FAIL because now it's an int field!
      expect(
        () => controller.setValue(nameIntId, 'Back to string' as dynamic),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('num vs int vs double compatibility', () {
      const numId = FormixFieldID<num>('num');
      const intId = FormixFieldID<int>('int');
      const doubleId = FormixFieldID<double>('double');

      expect(numId.isTypeValid(1), true);
      expect(numId.isTypeValid(1.5), true);

      expect(intId.isTypeValid(1), true);
      expect(intId.isTypeValid(1.5), false);

      expect(doubleId.isTypeValid(1.5), true);
      // In Dart VM, 1 is NOT double. (Though in web/compiled it might be).
      // Standard Dart: 1 is int, not double.
      expect(doubleId.isTypeValid(1), false);
    });
  });
}
