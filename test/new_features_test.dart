import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';
import 'package:formix/formix_test.dart';

void main() {
  const name = FormixFieldID<String>('name');
  const email = FormixFieldID<String>('email');
  const qty = FormixFieldID<int>('qty');
  const price = FormixFieldID<int>('price');

  group('applyServerErrors', () {
    test('sets errors on multiple fields in a single update', () {
      final c = FormixController(initialValue: const {'name': '', 'email': ''});
      addTearDown(c.dispose);

      c.applyServerErrors({'name': 'Taken', 'email': 'Invalid'});
      expect(c.getValidation(name).errorMessage, 'Taken');
      expect(c.getValidation(email).errorMessage, 'Invalid');
      expect(c.state.errorCount, 2);
      expect(c.state.isValid, isFalse);
    });

    test('empty map is a no-op', () {
      final c = FormixController();
      addTearDown(c.dispose);
      c.applyServerErrors({});
      expect(c.state.errorCount, 0);
    });
  });

  group('derived', () {
    test('recomputes only when its inputs change', () {
      final c = FormixController(initialValue: const {'qty': 2, 'price': 3});
      addTearDown(c.dispose);

      final total = c.derived((s) => (s.getValue(qty) ?? 0) * (s.getValue(price) ?? 0));
      expect(total.value, 6);

      c.setValue(qty, 4);
      expect(total.value, 12);

      c.setValue(price, 5);
      expect(total.value, 20);
    });
  });

  group('debouncedValueSignal', () {
    testWidgets('emits the latest value only after the debounce window', (tester) async {
      final c = FormixController(initialValue: const {'name': ''});
      addTearDown(c.dispose);

      final debounced = c.debouncedValueSignal(name, const Duration(milliseconds: 100));
      // Drain the initial-value timer.
      await tester.pump(const Duration(milliseconds: 120));
      expect(debounced.value, '');

      c.setValue(name, 'a');
      c.setValue(name, 'ab');
      expect(debounced.value, ''); // not emitted yet

      await tester.pump(const Duration(milliseconds: 120));
      expect(debounced.value, 'ab');

      // Same instance is cached per (field, duration).
      expect(identical(c.debouncedValueSignal(name, const Duration(milliseconds: 100)), debounced), isTrue);
    });
  });

  group('reactive field flags', () {
    testWidgets('setEnabled disables the built-in text field reactively', (tester) async {
      final c = await pumpFormix(tester, child: const FormixTextFormField(fieldId: name));
      TextField tf() => tester.widget<TextField>(find.byType(TextField));

      expect(tf().enabled, isTrue);
      c.setEnabled(name, false);
      await tester.pump();
      expect(tf().enabled, isFalse);

      c.setEnabled(name, true);
      await tester.pump();
      expect(tf().enabled, isTrue);
    });

    testWidgets('setReadOnly toggles the text field readOnly reactively', (tester) async {
      final c = await pumpFormix(tester, child: const FormixTextFormField(fieldId: name));
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);

      c.setReadOnly(name, true);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    test('visibleSignal defaults true and toggles', () {
      final c = FormixController();
      addTearDown(c.dispose);
      expect(c.visibleSignal(name).value, isTrue);
      c.setVisible(name, false);
      expect(c.visibleSignal(name).value, isFalse);
    });
  });

  group('FormixFormField (Flutter Form interop)', () {
    testWidgets('participates in Form.validate() and shows Formix errors', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Formix(
                fields: [
                  FormixFieldConfig<String>(
                    id: name,
                    validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
                  ),
                ],
                child: FormixFormField<String>(
                  fieldId: name,
                  builder: (context, value, error, onChanged) => TextField(
                    onChanged: onChanged,
                    decoration: InputDecoration(errorText: error),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Empty required field → Flutter Form.validate() returns false via Formix.
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('required'), findsOneWidget);

      // Enter a value → validates true and pushes into the controller.
      await tester.enterText(find.byType(TextField), 'John');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      expect(Formix.controllerOf(tester.element(find.byType(FormixFormField<String>)))!.getValue(name), 'John');
    });

    testWidgets('shows a config error when used without a Formix ancestor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormixFormField<String>(
              fieldId: name,
              builder: (context, value, error, onChanged) => const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });

  group('test utilities (pumpFormix + RebuildCounter)', () {
    testWidgets('RebuildCounter + rebuiltExactly track surgical rebuilds', (tester) async {
      final counter = RebuildCounter();

      final c = await pumpFormix(
        tester,
        initialValue: const {'name': '', 'email': ''},
        child: FormixBuilder(
          builder: (context, scope) => counter.wrap((_) => Text('${scope.watchValue(name)}')),
        ),
      );

      final baseline = counter.count;

      // Changing an UNwatched field does not rebuild the builder.
      c.setValue(email, 'x@y.com');
      await tester.pump();
      expect(counter, rebuiltExactly(baseline));

      // Changing the watched field rebuilds exactly once more.
      c.setValue(name, 'Ada');
      await tester.pump();
      expect(counter, rebuiltExactly(baseline + 1));
      expect(counter, rebuiltAtMost(baseline + 1));
    });
  });
}
