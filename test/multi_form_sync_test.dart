import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Multi-Form Synchronization Tests', () {
    const fieldA = FormixFieldID<String>('fieldA');
    const fieldB = FormixFieldID<String>('fieldB');

    testWidgets('One-way binding updates target field', (tester) async {
      late FormixController controllerA;
      late FormixController controllerB;

      controllerA = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldA, initialValue: 'A').toField(),
        ],
      );
      controllerB = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldB, initialValue: 'B').toField(),
        ],
      );

      // Verify initial
      expect(controllerA.getValue(fieldA), 'A');
      expect(controllerB.getValue(fieldB), 'B');

      // Bind B -> A
      controllerB.bindField(
        fieldB,
        sourceController: controllerA,
        sourceField: fieldA,
      );

      // Change A -> B should update
      controllerA.setValue(fieldA, 'New A');

      expect(controllerB.getValue(fieldB), 'New A');

      // Change B -> A should NOT update (one way)
      controllerB.setValue(fieldB, 'New B');
      expect(controllerA.getValue(fieldA), 'New A'); // Unchanged

      // Clean up
      controllerA.dispose();
      controllerB.dispose();
    });

    testWidgets('Two-way binding updates both fields', (tester) async {
      late FormixController controllerA;
      late FormixController controllerB;

      controllerA = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldA, initialValue: 'A').toField(),
        ],
      );
      controllerB = FormixController(
        fields: [
          const FormixFieldConfig<String>(id: fieldB, initialValue: 'B').toField(),
        ],
      );

      // Bind B <-> A
      controllerB.bindField(
        fieldB,
        sourceController: controllerA,
        sourceField: fieldA,
        twoWay: true,
      );

      // Change A -> B update
      controllerA.setValue(fieldA, 'UpdateFromA');
      expect(controllerB.getValue(fieldB), 'UpdateFromA');

      // Change B -> A update
      controllerB.setValue(fieldB, 'UpdateFromB');
      expect(controllerA.getValue(fieldA), 'UpdateFromB');

      // Clean up
      controllerA.dispose();
      controllerB.dispose();
    });
  });
}
