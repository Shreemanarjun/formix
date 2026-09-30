import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:formix/src/devtools/formix_devtools.dart';

/// Exercises the pure, testable DevTools payload/action logic (the parts that do
/// NOT require the DevTools VM-service bridge).
void main() {
  const name = FormixFieldID<String>('name');
  const age = FormixFieldID<int>('age');

  FormixController make(String id) {
    final c = FormixController(
      formId: id,
      fields: [
        FormixField<String>(id: name, initialValue: '', validator: (v) => (v == null || v.isEmpty) ? 'required' : null),
        const FormixField<int>(id: age, initialValue: 0),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('listFormsPayload reflects active + historical forms newest-first', () {
    make('dp_a');
    make('dp_b');
    final payload = FormixDevToolsService.listFormsPayload();
    expect(payload['latestActiveId'], 'dp_b');
    final forms = (payload['forms'] as List).cast<Map>();
    final ids = forms.map((f) => f['id']).toList();
    expect(ids, containsAllInOrder(['dp_b', 'dp_a']));
    expect(forms.firstWhere((f) => f['id'] == 'dp_b')['isActive'], isTrue);
    expect(FormixDevToolsService.latestActiveId, 'dp_b');
  });

  test('formDetailsPayload returns full inspector state, null when missing', () {
    final c = make('dp_details');
    c.setValue(name, 'Ada');
    final payload = FormixDevToolsService.formDetailsPayload('dp_details')!;
    expect(payload['values'], containsPair('name', 'Ada'));
    expect(payload['fieldCount'], 2);
    expect(payload['errorCount'], isA<int>());
    expect(payload['validations'], isA<Map>());
    expect(payload['dirtyStates'], containsPair('name', true));
    expect(payload['canUndo'], isA<bool>());
    expect(FormixDevToolsService.formDetailsPayload('does_not_exist'), isNull);
  });

  test('encodePayload handles DateTime and non-encodable values', () {
    final json = FormixDevToolsService.encodePayload({
      'date': DateTime(2021, 5, 6),
      'obj': Object(),
      'n': 1,
    });
    expect(json, contains('2021-05-06'));
    expect(json, contains('"n":1'));
  });

  group('applyAction', () {
    test('returns false for unknown form', () {
      expect(FormixDevToolsService.applyAction('resetForm', {'formId': 'nope'}), isFalse);
    });

    test('resetForm / undo / redo / validateField / debugFillDummyData', () {
      final c = make('dp_actions');
      c.setValue(name, 'x');
      expect(c.state.isDirty, isTrue);

      expect(FormixDevToolsService.applyAction('resetForm', {'formId': 'dp_actions'}), isTrue);
      expect(c.state.isDirty, isFalse);

      c.setValue(name, 'y');
      expect(FormixDevToolsService.applyAction('undo', {'formId': 'dp_actions'}), isTrue);
      expect(FormixDevToolsService.applyAction('redo', {'formId': 'dp_actions'}), isTrue);

      expect(FormixDevToolsService.applyAction('validateField', {'formId': 'dp_actions', 'fieldId': 'name'}), isTrue);
      expect(FormixDevToolsService.applyAction('validateField', {'formId': 'dp_actions'}), isFalse); // missing fieldId

      expect(FormixDevToolsService.applyAction('debugFillDummyData', {'formId': 'dp_actions'}), isTrue);
    });

    test('updateFieldValue parses JSON and sets value', () {
      final c = make('dp_update');
      expect(FormixDevToolsService.applyAction('updateFieldValue', {'formId': 'dp_update', 'fieldId': 'age', 'value': '42'}), isTrue);
      expect(c.getValue(age), 42);
      // Missing value -> false
      expect(FormixDevToolsService.applyAction('updateFieldValue', {'formId': 'dp_update', 'fieldId': 'age'}), isFalse);
    });

    test('setFormState applies a whole map', () {
      final c = make('dp_setstate');
      expect(FormixDevToolsService.applyAction('setFormState', {'formId': 'dp_setstate', 'state': '{"name":"Zed","age":9}'}), isTrue);
      expect(c.getValue(name), 'Zed');
      expect(c.getValue(age), 9);
      expect(FormixDevToolsService.applyAction('setFormState', {'formId': 'dp_setstate'}), isFalse); // missing state
    });

    test('unknown action returns false', () {
      make('dp_unknown');
      expect(FormixDevToolsService.applyAction('bogus', {'formId': 'dp_unknown'}), isFalse);
    });
  });
}
