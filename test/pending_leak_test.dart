import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Pending Count Leak Tests', () {
    const field1 = FormixFieldID<String>('field1');

    test('validate() should not leak pendingCount when transitioning from validating to valid', () async {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field1,
            initialValue: '',
            asyncValidator: (value) async {
              await Future.delayed(const Duration(milliseconds: 100));
              return null;
            },
          ),
        ],
      );

      // Initial state: it might be validating if autovalidateMode is always
      expect(controller.state.pendingCount, 0, reason: 'Initially 0 because async validation hasn\'t started yet');

      // Set value to trigger async validation
      controller.setValue(field1, 'John');
      expect(controller.state.pendingCount, 1, reason: 'Should be 1 because async validation started');

      // Now call validate() (sync).
      // It should run the sync validator (returns valid),
      // then identify that it has an async validator,
      // so it STAYS validating.
      controller.validate();
      expect(controller.state.pendingCount, 1, reason: 'Should stay 1');

      // Now imagine we remove the async validator or call validate in a way that it becomes valid
      // For this test, let's just use a field WITHOUT async validator and see if it clears.

      final controller2 = FormixController(
        fields: [
          const FormixField<String>(
            id: field1,
            initialValue: '',
          ),
        ],
      );

      // Manually set it to validating to simulate a leak or previous state
      controller2.setFieldValidating(field1, isValidating: true);
      expect(controller2.state.pendingCount, 1);

      // Now call validate(). Since it has NO async validator, it should become VALID.
      // And pendingCount should become 0.
      controller2.validate();
      expect(controller2.state.pendingCount, 0, reason: 'pendingCount should be cleared by validate() if field is now just valid');
    });

    test('setValue() should not leak pendingCount when field becomes invalid while validating', () async {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field1,
            initialValue: '',
            validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
            asyncValidator: (value) async => null,
          ),
        ],
      );

      controller.setValue(field1, 'John');
      expect(controller.state.pendingCount, 1);
      expect(controller.state.errorCount, 0);

      // Now set it to empty value. The sync validator will fail (Required).
      // It should NO LONGER be validating.
      controller.setValue(field1, '');
      expect(controller.state.errorCount, 1);
      expect(controller.state.pendingCount, 0, reason: 'pendingCount should decrease because it is now invalid (not validating)');
    });
  });
}
