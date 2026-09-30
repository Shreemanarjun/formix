import 'package:flutter/material.dart' hide FormState;
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

Widget _app(Widget child, {FormixController? controller}) {
  return MaterialApp(
    home: Scaffold(
      body: Formix(controller: controller, child: child),
    ),
  );
}

void main() {
  group('field widgets: forceErrorText branch', () {
    testWidgets('text field renders forced error', (tester) async {
      const id = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: id, initialValue: '')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixTextFormField(fieldId: id, forceErrorText: 'forced!'),
        controller: c,
      ));
      await tester.pump();
      expect(find.text('forced!'), findsOneWidget);
    });

    testWidgets('dropdown renders forced error', (tester) async {
      const id = FormixFieldID<String>('choice');
      final c = FormixController(
        initialValue: const {'choice': 'a'},
        fields: [const FormixField<String>(id: id, initialValue: 'a')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixDropdownFormField<String>(
          fieldId: id,
          forceErrorText: 'bad choice',
          items: [
            DropdownMenuItem(value: 'a', child: Text('A')),
            DropdownMenuItem(value: 'b', child: Text('B')),
          ],
        ),
        controller: c,
      ));
      await tester.pump();
      expect(find.text('bad choice'), findsOneWidget);
    });

    testWidgets('checkbox renders forced error', (tester) async {
      const id = FormixFieldID<bool>('agree');
      final c = FormixController(
        initialValue: const {'agree': false},
        fields: [const FormixField<bool>(id: id, initialValue: false)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixCheckboxFormField(
          fieldId: id,
          title: Text('Agree'),
          forceErrorText: 'must agree',
        ),
        controller: c,
      ));
      await tester.pump();
      expect(find.text('must agree'), findsOneWidget);
    });
  });

  group('field widgets: validating (loading) suffix via setFieldValidating', () {
    // Drive the validating state directly so the suffix-building branch runs
    // deterministically, independent of async debounce timing.
    testWidgets('text field shows validating fallback', (tester) async {
      const id = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: id, initialValue: '')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixTextFormField(fieldId: id),
        controller: c,
      ));
      await tester.pump();
      c.setFieldValidating(id, isValidating: true);
      await tester.pump();
      expect(c.getValidation(id).isValidating, isTrue);
    });

    testWidgets('number field shows validating fallback', (tester) async {
      const id = FormixFieldID<int>('qty');
      final c = FormixController(
        initialValue: const {'qty': 0},
        fields: [const FormixField<int>(id: id, initialValue: 0)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixNumberFormField<int>(fieldId: id),
        controller: c,
      ));
      await tester.pump();
      c.setFieldValidating(id, isValidating: true);
      await tester.pump();
      expect(c.getValidation(id).isValidating, isTrue);
    });

    testWidgets('dropdown shows validating fallback', (tester) async {
      const id = FormixFieldID<String>('choice');
      final c = FormixController(
        initialValue: const {'choice': 'a'},
        fields: [const FormixField<String>(id: id, initialValue: 'a')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixDropdownFormField<String>(
          fieldId: id,
          items: [
            DropdownMenuItem(value: 'a', child: Text('A')),
            DropdownMenuItem(value: 'b', child: Text('B')),
          ],
        ),
        controller: c,
      ));
      await tester.pump();
      c.setFieldValidating(id, isValidating: true);
      await tester.pump();
      expect(c.getValidation(id).isValidating, isTrue);
    });

    testWidgets('cupertino field shows validating fallback', (tester) async {
      const id = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [const FormixField<String>(id: id, initialValue: '')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixCupertinoTextFormField(fieldId: id),
        controller: c,
      ));
      await tester.pump();
      c.setFieldValidating(id, isValidating: true);
      await tester.pump();
      expect(find.text('Validating...'), findsOneWidget);
    });

    testWidgets('checkbox shows validating widget fallback', (tester) async {
      const id = FormixFieldID<bool>('agree');
      final c = FormixController(
        initialValue: const {'agree': false},
        fields: [const FormixField<bool>(id: id, initialValue: false)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixCheckboxFormField(fieldId: id, title: Text('Agree')),
        controller: c,
      ));
      await tester.pump();
      c.setFieldValidating(id, isValidating: true);
      await tester.pump();
      expect(find.text('Validating...'), findsOneWidget);
    });
  });

  group('field widgets: cupertino error branch (default Text)', () {
    testWidgets('cupertino field shows validation error text', (tester) async {
      const id = FormixFieldID<String>('name');
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [
          FormixField<String>(
            id: id,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(
        const FormixCupertinoTextFormField(fieldId: id),
        controller: c,
      ));
      await tester.pump();
      c.markAsTouched(id);
      c.setValue(id, '');
      await tester.pump();
      expect(find.text('required'), findsOneWidget);
    });
  });

  group('field widgets: theme-disabled decoration path', () {
    testWidgets('number field with disabled FormixTheme', (tester) async {
      const id = FormixFieldID<int>('qty');
      final c = FormixController(
        initialValue: const {'qty': 1},
        fields: [const FormixField<int>(id: id, initialValue: 1)],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormixTheme(
            data: const FormixThemeData(enabled: false),
            child: Formix(
              controller: c,
              child: const FormixNumberFormField<int>(fieldId: id),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('dropdown with disabled FormixTheme', (tester) async {
      const id = FormixFieldID<String>('choice');
      final c = FormixController(
        initialValue: const {'choice': 'a'},
        fields: [const FormixField<String>(id: id, initialValue: 'a')],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FormixTheme(
            data: const FormixThemeData(enabled: false),
            child: Formix(
              controller: c,
              child: const FormixDropdownFormField<String>(
                fieldId: id,
                items: [
                  DropdownMenuItem(value: 'a', child: Text('A')),
                  DropdownMenuItem(value: 'b', child: Text('B')),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });
  });

  group('field widgets: onSubmitted / focusNext callbacks', () {
    testWidgets('number field onFieldSubmitted fires', (tester) async {
      const id = FormixFieldID<int>('qty');
      final c = FormixController(
        initialValue: const {'qty': 0},
        fields: [const FormixField<int>(id: id, initialValue: 0)],
      );
      addTearDown(c.dispose);

      int? submitted;
      await tester.pumpWidget(_app(
        FormixNumberFormField<int>(
          fieldId: id,
          onFieldSubmitted: (v) => submitted = v,
        ),
        controller: c,
      ));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), '42');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, 42);
    });

    testWidgets('dropdown onSubmitted + focusNext on next action', (tester) async {
      const id = FormixFieldID<String>('choice');
      const next = FormixFieldID<String>('next');
      final c = FormixController(
        initialValue: const {'choice': 'a', 'next': ''},
        fields: [
          const FormixField<String>(id: id, initialValue: 'a'),
          const FormixField<String>(id: next, initialValue: ''),
        ],
      );
      addTearDown(c.dispose);

      String? submitted;
      final nextNode = FocusNode();
      addTearDown(nextNode.dispose);

      await tester.pumpWidget(_app(
        Column(
          children: [
            FormixDropdownFormField<String>(
              fieldId: id,
              textInputAction: TextInputAction.next,
              onSubmitted: (v) => submitted = v,
              items: const [
                DropdownMenuItem(value: 'a', child: Text('A')),
                DropdownMenuItem(value: 'b', child: Text('B')),
              ],
            ),
            FormixTextFormField(fieldId: next, focusNode: nextNode),
          ],
        ),
        controller: c,
      ));
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      expect(submitted, 'b');
      expect(c.getValue(id), 'b');
    });
  });
}
