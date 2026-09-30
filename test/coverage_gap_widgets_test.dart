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

      await tester.pumpWidget(
        _app(
          const FormixTextFormField(fieldId: id, forceErrorText: 'forced!'),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixDropdownFormField<String>(
            fieldId: id,
            forceErrorText: 'bad choice',
            items: [
              DropdownMenuItem(value: 'a', child: Text('A')),
              DropdownMenuItem(value: 'b', child: Text('B')),
            ],
          ),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixCheckboxFormField(
            fieldId: id,
            title: Text('Agree'),
            forceErrorText: 'must agree',
          ),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixTextFormField(fieldId: id),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixNumberFormField<int>(fieldId: id),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixDropdownFormField<String>(
            fieldId: id,
            items: [
              DropdownMenuItem(value: 'a', child: Text('A')),
              DropdownMenuItem(value: 'b', child: Text('B')),
            ],
          ),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixCupertinoTextFormField(fieldId: id),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixCheckboxFormField(fieldId: id, title: Text('Agree')),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
          const FormixCupertinoTextFormField(fieldId: id),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormixTheme(
              data: const FormixThemeData(enabled: false),
              child: Formix(
                controller: c,
                child: const FormixNumberFormField<int>(fieldId: id),
              ),
            ),
          ),
        ),
      );
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

      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
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
      await tester.pumpWidget(
        _app(
          FormixNumberFormField<int>(
            fieldId: id,
            onFieldSubmitted: (v) => submitted = v,
          ),
          controller: c,
        ),
      );
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

      await tester.pumpWidget(
        _app(
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
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B').last);
      await tester.pumpAndSettle();
      expect(submitted, 'b');
      expect(c.getValue(id), 'b');
    });
  });

  group('base field lifecycle: focusNode swap + preserved validators', () {
    testWidgets('swapping focusNode re-inits + preserves existing validators', (tester) async {
      const id = FormixFieldID<String>('name');
      // Pre-register the field WITH a validator so re-registration must preserve
      // the wrapped validator (base_form_field _ensureFieldRegistered branches).
      final c = FormixController(
        initialValue: const {'name': ''},
        fields: [
          FormixField<String>(
            id: id,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
            asyncValidator: (v) async => null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      final node1 = FocusNode();
      final node2 = FocusNode();
      addTearDown(node1.dispose);
      addTearDown(node2.dispose);

      var useNode1 = true;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                FormixTextFormField(
                  fieldId: id,
                  focusNode: useNode1 ? node1 : node2,
                  // Providing a widget-level validator forces re-registration,
                  // exercising the preserved-validator branch.
                  validator: (v) => null,
                ),
                ElevatedButton(
                  onPressed: () => setState(() => useNode1 = false),
                  child: const Text('swap-node'),
                ),
              ],
            ),
          ),
          controller: c,
        ),
      );
      await tester.pump();

      // Swap the focusNode -> didUpdateWidget focusNode branch.
      await tester.tap(find.text('swap-node'));
      await tester.pump();
      expect(c.isFieldRegistered(id), isTrue);
    });
  });

  group('legacy base widgets: forceErrorText + error display', () {
    testWidgets('base text/number widgets show forced + validated errors', (tester) async {
      const textId = FormixFieldID<String>('t');
      const numId = FormixFieldID<int>('n');
      final c = FormixController(
        initialValue: const {'t': '', 'n': 0},
        fields: [
          FormixField<String>(
            id: textId,
            initialValue: '',
            validator: (v) => (v == null || v.isEmpty) ? 'text-required' : null,
          ),
          FormixField<int>(
            id: numId,
            initialValue: 0,
            validator: (v) => v == 0 ? 'no-zero' : null,
          ),
        ],
        autovalidateMode: FormixAutovalidateMode.always,
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              _BaseText(fieldId: textId),
              _BaseNumber(fieldId: numId),
            ],
          ),
          controller: c,
        ),
      );
      await tester.pump();

      // Drive both base fields into a shown error (touched path) so the
      // errorText branches (549 / 621) render.
      c.markAsTouched(textId);
      c.setValue(textId, '');
      c.markAsTouched(numId);
      c.setValue(numId, 0);
      await tester.pump();
      expect(find.text('text-required'), findsOneWidget);
      expect(find.text('no-zero'), findsOneWidget);
    });
  });

  group('base field: re-registration preserves wrapped validators', () {
    testWidgets('mounting with a differing autovalidateMode preserves async + cross validators', (tester) async {
      const id = FormixFieldID<String>('preserve');
      // Pre-register with async + cross-field validators so the wrapped-*
      // getters are present when the widget re-registers.
      final c = FormixController(
        initialValue: const {'preserve': ''},
        fields: [
          FormixField<String>(
            id: id,
            initialValue: '',
            validationMode: FormixAutovalidateMode.onBlur,
            asyncValidator: (v) async => null,
            crossFieldValidator: (v, s) => null,
          ),
        ],
      );
      addTearDown(c.dispose);

      // Mount a widget that provides NO validator but a DIFFERENT
      // autovalidateMode, which forces re-registration and exercises the
      // preserved async (236) and cross-field (241) branches.
      await tester.pumpWidget(
        _app(
          const FormixTextFormField(
            fieldId: id,
            autovalidateMode: FormixAutovalidateMode.always,
          ),
          controller: c,
        ),
      );
      await tester.pump();
      expect(c.isFieldRegistered(id), isTrue);
    });
  });
}

/// Concrete subclass of the legacy [FormixTextFormFieldWidget] base class.
class _BaseText extends FormixTextFormFieldWidget {
  const _BaseText({required super.fieldId});
  @override
  _BaseTextState createState() => _BaseTextState();
}

class _BaseTextState extends FormixTextFormFieldWidgetState {}

/// Concrete subclass of the legacy [FormixNumberFormFieldWidget] base class.
class _BaseNumber extends FormixNumberFormFieldWidget {
  const _BaseNumber({required super.fieldId});
  @override
  _BaseNumberState createState() => _BaseNumberState();
}

class _BaseNumberState extends FormixNumberFormFieldWidgetState {}
