import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  const emailId = FormixFieldID<String>('email');
  const ageId = FormixFieldID<int>('age');

  group('owned controller (context-free, no Formix ancestor)', () {
    testWidgets('explicit controller on a field works with no Formix + imperative seed', (tester) async {
      // Own the controller and seed it imperatively (as you would in initState).
      final form = FormixController(
        fields: const [
          FormixFieldConfig<String>(id: emailId),
          FormixFieldConfig<int>(id: ageId),
        ],
      );
      addTearDown(form.dispose);
      form.batchUpdate((b) => b
        ..set(emailId, 'a@b.c')
        ..set(ageId, 18));

      // No Formix ancestor — the field gets the controller explicitly.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FormixTextFormField(fieldId: emailId, controller: form),
                FormixValue<int>(ageId, controller: form, builder: (_, age) => Text('age:${age ?? 0}')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'a@b.c'), findsOneWidget);
      expect(find.text('age:18'), findsOneWidget);

      // Editing writes back to the owned controller.
      await tester.enterText(find.byType(TextField), 'new@x.io');
      await tester.pump();
      expect(form.getValue(emailId), 'new@x.io');
    });

    test('reading the controller in initState-style code never throws (no InheritedWidget)', () {
      final form = FormixController(fields: const [FormixFieldConfig<String>(id: emailId)]);
      addTearDown(form.dispose);
      // The whole point: no context, no Formix.of — just the object.
      expect(() => form.setValue(emailId, 'x@y.z'), returnsNormally);
      expect(form.getValue(emailId), 'x@y.z');
    });

    testWidgets('FormixSubmitButton with an owned controller submits and drives submission state', (tester) async {
      Map<String, dynamic>? submitted;
      final form = FormixController(
        fields: [
          FormixFieldConfig<String>(
            id: emailId,
            validationMode: FormixAutovalidateMode.always,
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
      );
      addTearDown(form.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FormixSubmitButton(
                  controller: form,
                  onValid: (values) async => submitted = values,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      ElevatedButton btn() => tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      // Invalid (empty email) after validate → disabled.
      form.validate();
      await tester.pump();
      expect(btn().onPressed, isNull);
      expect(form.submissionSignal.value, const FormixSubmission.idle());

      // Valid → enabled → submit → success.
      form.setValue(emailId, 'a@b.c');
      await tester.pump();
      expect(btn().onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(submitted, {'email': 'a@b.c'});
      expect(form.submissionSignal.value, const FormixSubmission.success());
    });
  });

  group('FormixFieldDerivation (derived-fields example mechanism)', () {
    testWidgets('derives target from dependencies, updates on change, no build-time writes', (tester) async {
      const firstId = FormixFieldID<String>('first');
      const lastId = FormixFieldID<String>('last');
      const fullId = FormixFieldID<String>('full');
      final c = FormixController(initialValue: const {'first': 'Ada', 'last': 'Lovelace'});
      addTearDown(c.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            controller: c,
            child: FormixFieldDerivation(
              dependencies: const <FormixFieldID<dynamic>>[firstId, lastId],
              targetField: fullId,
              derive: (v) => '${v[firstId] ?? ''} ${v[lastId] ?? ''}'.trim(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(c.getValue(fullId), 'Ada Lovelace');

      c.setValue(firstId, 'Grace');
      await tester.pumpAndSettle();
      expect(c.getValue(fullId), 'Grace Lovelace');
    });
  });

  group('bindField (multi-form sync example mechanism)', () {
    test('one-way sync propagates source changes to the target controller', () {
      const titleId = FormixFieldID<String>('title');
      final a = FormixController(fields: const [FormixFieldConfig<String>(id: titleId, initialValue: 'X')]);
      final b = FormixController(fields: const [FormixFieldConfig<String>(id: titleId)]);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      b.bindField(titleId, sourceController: a, sourceField: titleId);

      a.setValue(titleId, 'Synced');
      expect(b.getValue(titleId), 'Synced');

      a.setValue(titleId, 'Again');
      expect(b.getValue(titleId), 'Again');
    });
  });
}
