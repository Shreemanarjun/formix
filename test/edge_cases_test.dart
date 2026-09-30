import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Edge Cases', () {
    test('Zombie Fields: Hidden fields block submission', () async {
      const fieldA = FormixFieldID<String>('a');

      // A is required
      final fields = [
        FormixFieldConfig<String>(
          id: fieldA,
          validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
        ),
      ];

      final param = FormixParameter(fields: fields);
      final controller = FormixController.fromParameter(param);
      addTearDown(controller.dispose);

      // Verify initial error (auto-validate might be off, triggers on submit)
      await controller.submit(onValid: (_) async {});

      expect(
        controller.currentState.isValid,
        isFalse,
        reason: 'Field A is required',
      );

      // Now "Hide" the field (Simulate widget removal).
      // Since there is no `unregisterField` API exposed or called by widgets automatically,
      // the field remains in the controller.

      // If user clears the value...
      controller.setValue(fieldA, '');
      expect(controller.currentState.isValid, isFalse);

      // Ideally, if the widget is gone, we might expect the form to ignore it?
      // But Formix is controller-driven. The state persists.
      // This confirms "Zombie Fields" logic.
    });

    test(
      'Submit Race Condition: submit() runs while async validation is pending',
      () async {
        const fieldA = FormixFieldID<String>('a');
        final completer = Completer<String?>();

        final fields = [
          FormixFieldConfig<String>(
            id: fieldA,
            initialValue: 'test',
            debounceDuration: Duration.zero, // Disable debounce to start immediately
            asyncValidator: (val) async {
              return await completer.future;
            },
          ),
        ];

        final param = FormixParameter(fields: fields);
        final controller = FormixController.fromParameter(param);
        addTearDown(controller.dispose);

        // Trigger async validation
        controller.setValue(fieldA, 'new value');

        // Verify state is "validating"
        expect(
          controller.currentState.validations[fieldA.key]?.isValidating,
          isTrue,
          reason: 'Should be validating',
        );

        // Check isValid (Optimistic)
        expect(
          controller.currentState.isValid,
          isTrue,
          reason: 'Form assumes valid while validating',
        );

        bool submitted = false;

        // Start submit (don't await yet, it waits for validation)
        final submitFuture = controller.submit(
          onValid: (_) async {
            submitted = true;
          },
        );

        // Should still be waiting
        await Future.delayed(const Duration(milliseconds: 10)); // Yield
        expect(submitted, isFalse, reason: 'Submit should wait for async');

        // Now complete the validation with an error
        completer.complete('Async Error');

        // Now await the submit completion
        await submitFuture;

        // Verify it did NOT submit
        expect(
          submitted,
          isFalse,
          reason: 'Submit should fail because async validation failed',
        );

        // Check final state
        expect(
          controller.currentState.validations[fieldA.key]?.isValid,
          isFalse,
        );
      },
    );
  });
}
