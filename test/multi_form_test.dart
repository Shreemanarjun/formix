import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Multi-Form Integration Tests', () {
    testWidgets('Parallel forms should have independent states', (
      tester,
    ) async {
      const nameField = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: Key('form_1'),
                  initialValue: {'name': 'Form 1'},
                  child: Column(
                    children: [
                      Text('Form One'),
                      FormixTextFormField(fieldId: nameField),
                    ],
                  ),
                ),
                Formix(
                  key: Key('form_2'),
                  initialValue: {'name': 'Form 2'},
                  child: Column(
                    children: [
                      Text('Form Two'),
                      FormixTextFormField(fieldId: nameField),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check initial values
      expect(find.text('Form 1'), findsOneWidget);
      expect(find.text('Form 2'), findsOneWidget);

      // Update Form 1
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('form_1')),
          matching: find.byType(TextField),
        ),
        'Updated 1',
      );
      await tester.pump();

      expect(find.text('Updated 1'), findsOneWidget);
      expect(find.text('Form 2'), findsOneWidget);
      expect(find.text('Form 1'), findsNothing);

      // Update Form 2
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('form_2')),
          matching: find.byType(TextField),
        ),
        'Updated 2',
      );
      await tester.pump();

      expect(find.text('Updated 1'), findsOneWidget);
      expect(find.text('Updated 2'), findsOneWidget);
    });

    testWidgets('Nested forms should isolate inner scopes', (tester) async {
      const outerField = FormixFieldID<String>('outer');
      const innerField = FormixFieldID<String>('inner');
      const sharedField = FormixFieldID<String>('shared');

      FormixController? innerController;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              key: const Key('outer_form'),
              initialValue: const {'outer': 'O', 'shared': 'Outer Shared'},
              child: Column(
                children: [
                  const FormixTextFormField(fieldId: outerField),
                  const FormixTextFormField(fieldId: sharedField),
                  const Divider(),
                  Formix(
                    key: const Key('inner_form'),
                    initialValue: const {'inner': 'I', 'shared': 'Inner Shared'},
                    child: FormixBuilder(
                      builder: (context, scope) {
                        innerController = scope.controller;
                        return const Column(
                          children: [
                            FormixTextFormField(fieldId: innerField),
                            FormixTextFormField(fieldId: sharedField),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('O'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('Outer Shared'), findsOneWidget);
      expect(find.text('Inner Shared'), findsOneWidget);

      expect(innerController, isNotNull);
      expect(innerController!.getValue(sharedField), 'Inner Shared');
      expect(innerController!.getValue(outerField), null);

      // Update shared field in inner form
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('inner_form')),
          matching: find.widgetWithText(TextField, 'Inner Shared'),
        ),
        'Modified Inner',
      );
      await tester.pump();

      expect(find.text('Outer Shared'), findsOneWidget);
      expect(find.text('Modified Inner'), findsOneWidget);
    });

    testWidgets('Validation remains independent across multiple forms', (
      tester,
    ) async {
      const fieldId = FormixFieldID<String>('field');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: const Key('form_valid'),
                  fields: [
                    FormixFieldConfig<String>(
                      id: fieldId,
                      validator: (v) => null, // Always valid
                    ),
                  ],
                  child: FormixBuilder(
                    builder: (context, scope) {
                      return Text('Form 1 Valid: ${scope.watchIsValid}');
                    },
                  ),
                ),
                Formix(
                  key: const Key('form_invalid'),
                  fields: [
                    FormixFieldConfig<String>(
                      id: fieldId,
                      initialValue: '',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                  ],
                  child: FormixBuilder(
                    builder: (context, scope) {
                      return Column(
                        children: [
                          Text('Form 2 Valid: ${scope.watchIsValid}'),
                          const FormixTextFormField(fieldId: fieldId),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form 1 should be valid, Form 2 should be invalid (initially empty)
      expect(find.text('Form 1 Valid: true'), findsOneWidget);
      expect(find.text('Form 2 Valid: false'), findsOneWidget);

      // Make Form 2 valid
      await tester.enterText(find.byType(TextField), 'Value');
      await tester.pump();

      expect(find.text('Form 1 Valid: true'), findsOneWidget);
      expect(find.text('Form 2 Valid: true'), findsOneWidget);
    });

    testWidgets('Formix.of returns null when no form is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final provider = Formix.of(context);
                return Text('No Form: ${provider == null}');
              },
            ),
          ),
        ),
      );

      expect(find.text('No Form: true'), findsOneWidget);
    });

    testWidgets('Dynamic form replacement works seamlessly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _DynamicFormSwitcher())),
      );

      expect(find.text('A'), findsOneWidget);

      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('GlobalKey allows external form control', (tester) async {
      final formKey = GlobalKey<FormixState>();
      const nameField = FormixFieldID<String>('name');
      bool savePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      // Access form from outside its tree
                      final controller = formKey.currentState?.controller;
                      final data = formKey.currentState?.data;
                      expect(controller, isNotNull);
                      expect(data?.values['name'], 'John');
                      savePressed = true;
                    },
                  ),
                ),
              ],
            ),
            body: Formix(
              key: formKey,
              initialValue: const {'name': 'John'},
              child: const FormixTextFormField(fieldId: nameField),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state access
      expect(formKey.currentState, isNotNull);
      expect(formKey.currentState!.controller.getValue(nameField), 'John');

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();

      expect(savePressed, true);
    });

    testWidgets('onChanged callback triggers on value updates', (tester) async {
      const nameField = FormixFieldID<String>('name');
      const emailField = FormixFieldID<String>('email');
      final changedValues = <Map<String, dynamic>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'name': 'Alice', 'email': 'alice@example.com'},
              onChanged: (values) => changedValues.add(Map.from(values)),
              child: const Column(
                children: [
                  FormixTextFormField(fieldId: nameField),
                  FormixTextFormField(fieldId: emailField),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Update name
      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.pump();

      expect(changedValues.length, greaterThan(0));
      expect(changedValues.last['name'], 'Bob');
      expect(changedValues.last['email'], 'alice@example.com');

      // Update email
      await tester.enterText(find.byType(TextField).last, 'bob@example.com');
      await tester.pump();

      expect(changedValues.last['name'], 'Bob');
      expect(changedValues.last['email'], 'bob@example.com');
    });

    testWidgets('Triple-nested forms maintain isolation', (tester) async {
      const field = FormixFieldID<String>('value');

      FormixController? level1Controller;
      FormixController? level2Controller;
      FormixController? level3Controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'value': 'L1'},
              child: FormixBuilder(
                builder: (context, scope) {
                  level1Controller = scope.controller;
                  return Column(
                    children: [
                      Text('Level 1: ${scope.watchValue(field)}'),
                      Formix(
                        initialValue: const {'value': 'L2'},
                        child: FormixBuilder(
                          builder: (context, scope) {
                            level2Controller = scope.controller;
                            return Column(
                              children: [
                                Text('Level 2: ${scope.watchValue(field)}'),
                                Formix(
                                  initialValue: const {'value': 'L3'},
                                  child: FormixBuilder(
                                    builder: (context, scope) {
                                      level3Controller = scope.controller;
                                      return Text(
                                        'Level 3: ${scope.watchValue(field)}',
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(level1Controller!.getValue(field), 'L1');
      expect(level2Controller!.getValue(field), 'L2');
      expect(level3Controller!.getValue(field), 'L3');

      expect(find.text('Level 1: L1'), findsOneWidget);
      expect(find.text('Level 2: L2'), findsOneWidget);
      expect(find.text('Level 3: L3'), findsOneWidget);
    });

    testWidgets('Resetting one form does not affect parallel forms', (
      tester,
    ) async {
      final formKey1 = GlobalKey<FormixState>();
      final formKey2 = GlobalKey<FormixState>();
      const field = FormixFieldID<String>('value');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: formKey1,
                  initialValue: const {'value': 'Initial 1'},
                  child: const FormixTextFormField(fieldId: field),
                ),
                Formix(
                  key: formKey2,
                  initialValue: const {'value': 'Initial 2'},
                  child: const FormixTextFormField(fieldId: field),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Modify both forms
      await tester.enterText(find.byType(TextField).first, 'Modified 1');
      await tester.enterText(find.byType(TextField).last, 'Modified 2');
      await tester.pump();

      // Reset only form 1
      formKey1.currentState!.controller.reset();
      await tester.pumpAndSettle();

      expect(formKey1.currentState!.data.values['value'], 'Initial 1');
      expect(formKey2.currentState!.data.values['value'], 'Modified 2');
    });

    testWidgets('Validation errors are isolated between forms', (tester) async {
      const field = FormixFieldID<String>('email');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: const Key('form1'),
                  fields: [
                    FormixFieldConfig<String>(
                      id: field,
                      initialValue: 'invalid',
                      validator: (v) => (v?.contains('@') ?? false) ? null : 'Invalid email',
                    ),
                  ],
                  child: FormixBuilder(
                    builder: (context, scope) {
                      return Column(
                        children: [
                          const FormixTextFormField(fieldId: field),
                          Text('Form 1 Valid: ${scope.watchIsValid}'),
                        ],
                      );
                    },
                  ),
                ),
                Formix(
                  key: const Key('form2'),
                  fields: [
                    FormixFieldConfig<String>(
                      id: field,
                      initialValue: 'valid@example.com',
                      validator: (v) => (v?.contains('@') ?? false) ? null : 'Invalid email',
                    ),
                  ],
                  child: FormixBuilder(
                    builder: (context, scope) {
                      return Text('Form 2 Valid: ${scope.watchIsValid}');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Form 1 Valid: false'), findsOneWidget);
      expect(find.text('Form 2 Valid: true'), findsOneWidget);
    });

    testWidgets('Dirty state is independent across forms', (tester) async {
      final formKey1 = GlobalKey<FormixState>();
      final formKey2 = GlobalKey<FormixState>();
      const field = FormixFieldID<String>('value');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Formix(
                  key: formKey1,
                  initialValue: const {'value': 'A'},
                  child: const FormixTextFormField(fieldId: field),
                ),
                Formix(
                  key: formKey2,
                  initialValue: const {'value': 'B'},
                  child: const FormixTextFormField(fieldId: field),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially both forms are clean
      expect(formKey1.currentState!.data.isDirty, false);
      expect(formKey2.currentState!.data.isDirty, false);

      // Modify only form 1
      await tester.enterText(find.byType(TextField).first, 'Modified');
      await tester.pump();

      expect(formKey1.currentState!.data.isDirty, true);
      expect(formKey2.currentState!.data.isDirty, false);
    });

    testWidgets('Removing a form cleans up its resources', (tester) async {
      const field = FormixFieldID<String>('value');
      bool showForm = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    if (showForm)
                      const Formix(
                        key: Key('disposable_form'),
                        initialValue: {'value': 'Test'},
                        child: FormixTextFormField(fieldId: field),
                      ),
                    ElevatedButton(
                      onPressed: () => setState(() => showForm = !showForm),
                      child: const Text('Toggle'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('disposable_form')), findsOneWidget);

      // Remove the form
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('disposable_form')), findsNothing);

      // Re-add the form (should work without errors)
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('disposable_form')), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
    });
  });
}

class _DynamicFormSwitcher extends StatefulWidget {
  const _DynamicFormSwitcher();

  @override
  State<_DynamicFormSwitcher> createState() => _DynamicFormSwitcherState();
}

class _DynamicFormSwitcherState extends State<_DynamicFormSwitcher> {
  bool useFormA = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (useFormA)
          const Formix(
            key: ValueKey('form_a'),
            initialValue: {'field': 'A'},
            child: FormixTextFormField(fieldId: FormixFieldID<String>('field')),
          )
        else
          const Formix(
            key: ValueKey('form_b'),
            initialValue: {'field': 'B'},
            child: FormixTextFormField(fieldId: FormixFieldID<String>('field')),
          ),
        ElevatedButton(
          onPressed: () => setState(() => useFormA = !useFormA),
          child: const Text('Switch'),
        ),
      ],
    );
  }
}
