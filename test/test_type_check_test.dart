import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  test('type mismatch test', () {
    const nameField = FormixFieldID<String>('name');
    final controller = FormixController(
      fields: [const FormixField<String>(id: nameField, initialValue: 'initial')],
    );

    final FormixField<String> _ = controller.formFieldDefinitions['name'] as FormixField<String>;

    final _ = controller.setValues({nameField: 123}, strict: false);
  });
}
