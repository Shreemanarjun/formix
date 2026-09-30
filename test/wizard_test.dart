import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Multi-Step Wizard API Tests', () {
    const field1 = FormixFieldID<String>('field1');
    const field2 = FormixFieldID<String>('field2');

    test('nextStep should transition only if fields are valid', () {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field1,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Error' : null,
          ),
          FormixField<String>(
            id: field2,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Error' : null,
          ),
        ],
      );

      expect(controller.state.currentStep, 0);

      // Try nextStep without valid fields
      final success = controller.nextStep(fields: [field1]);
      expect(success, false);
      expect(controller.state.currentStep, 0);

      // Make field 1 valid
      controller.setValue(field1, 'Valid');

      // Try nextStep again for field 1
      final success2 = controller.nextStep(fields: [field1]);
      expect(success2, true);
      expect(controller.state.currentStep, 1);

      // Try nextStep for field 2 (which is invalid)
      final success3 = controller.nextStep(fields: [field2]);
      expect(success3, false);
      expect(controller.state.currentStep, 1);

      // Make field 2 valid
      controller.setValue(field2, 'Valid');
      final success4 = controller.nextStep(fields: [field2], targetStep: 5);
      expect(success4, true);
      expect(controller.state.currentStep, 5);
    });

    test('previousStep and goToStep should update currentStep', () {
      final controller = FormixController();
      expect(controller.state.currentStep, 0);

      controller.goToStep(10);
      expect(controller.state.currentStep, 10);

      controller.previousStep();
      expect(controller.state.currentStep, 9);

      controller.previousStep(targetStep: 0);
      expect(controller.state.currentStep, 0);
    });

    test('validateStep is an alias for validate', () {
      final controller = FormixController(
        fields: [
          FormixField<String>(
            id: field1,
            initialValue: '',
            validator: (v) => v!.isEmpty ? 'Error' : null,
          ),
        ],
      );

      expect(controller.validateStep([field1]), false);
      controller.setValue(field1, 'Valid');
      expect(controller.validateStep([field1]), true);
    });
  });
}
