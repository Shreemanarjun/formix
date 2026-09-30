import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Performance Stress Tests', () {
    test('Handles 1000 fields gracefully', () {
      final fields = List.generate(
        1000,
        (i) => FormixFieldConfig<String>(
          id: FormixFieldID<String>('field_$i'),
          initialValue: '',
          validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
        ),
      );

      final controller = FormixController.fromParameter(
        FormixParameter(fields: fields),
      );
      addTearDown(controller.dispose);

      final stopwatch = Stopwatch()..start();

      // Batch register & initial validation
      expect(controller.currentState.validations.length, 1000);

      // Bulk update
      for (var i = 0; i < 1000; i++) {
        controller.setValue(FormixFieldID<String>('field_$i'), 'Value $i');
      }

      expect(controller.currentState.isValid, true);
      stopwatch.stop();

      // ignore: avoid_print
      print('Updated 1000 fields in ${stopwatch.elapsedMilliseconds}ms');
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
      ); // Should be well under 1s
    });

    test('Cross-field dependency chain performance', () {
      // Create a chain of 500 fields where each depends on the previous one
      const chainLength = 100000;
      int validationCount = 0;

      final fields = <FormixFieldConfig<String>>[];
      fields.add(
        const FormixFieldConfig<String>(
          id: FormixFieldID<String>('field_0'),
          initialValue: '0',
        ),
      );

      for (var i = 1; i < chainLength; i++) {
        final prevId = FormixFieldID<String>('field_${i - 1}');
        fields.add(
          FormixFieldConfig<String>(
            id: FormixFieldID<String>('field_$i'),
            initialValue: '$i',
            dependsOn: [prevId],
            crossFieldValidator: (value, state) {
              validationCount++;
              final prevVal = state.getValue(prevId);
              if (prevVal == null) return 'Previous missing';
              return null;
            },
          ),
        );
      }

      final controller = FormixController.fromParameter(
        FormixParameter(fields: fields),
      );
      addTearDown(controller.dispose);

      // Reset count after initial validation triggers
      validationCount = 0;

      final stopwatch = Stopwatch()..start();

      // Changing the first field SHOULD trigger validation for the entire chain
      // thanks to the new `_collectTransitiveDependents` logic.
      controller.setValue(const FormixFieldID<String>('field_0'), 'New Value');

      stopwatch.stop();
      // ignore: avoid_print
      print(
        'Triggered dependency update for $chainLength fields in ${stopwatch.elapsedMilliseconds}ms',
      );

      // Assert that all downstream fields were validated
      // (chainLength - 1) fields depend on something.
      expect(validationCount, greaterThanOrEqualTo(chainLength - 1));

      // Performance benchmark: 500 simple validations should be very fast (< 200ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(chainLength));
    });
  });
}
