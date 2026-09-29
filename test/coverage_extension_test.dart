import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

class _TestWidget extends FormixWidget {
  const _TestWidget();
  @override
  Widget buildForm(BuildContext context, FormixScope scope) => Container();
}

class MyCustomField extends FormixFieldWidget<String> {
  const MyCustomField({super.key, required super.fieldId, super.initialValue});
  @override
  MyCustomFieldState createState() => MyCustomFieldState();
}

class MyCustomFieldState extends FormixFieldWidgetState<String> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          focusNode: focusNode,
          onChanged: setField,
          controller: TextEditingController(text: value),
        ),
        Text('Dirty: $isDirty'),
        Text('Touched: $isTouched'),
        Text('Valid: ${validation.isValid}'),
        ElevatedButton(
          onPressed: () => patchValue({const FormixFieldID<int>('age'): 25}),
          child: const Text('Patch'),
        ),
        ElevatedButton(onPressed: resetField, child: const Text('Reset')),
        ElevatedButton(onPressed: focus, child: const Text('Focus')),
      ],
    );
  }
}

class MyNumberField extends FormixNumberFormFieldWidget {
  const MyNumberField({super.key, required super.fieldId, super.initialValue});
  @override
  MyNumberFieldState createState() => MyNumberFieldState();
}

class MyNumberFieldState extends FormixNumberFormFieldWidgetState {}

class MyTextField extends FormixTextFormFieldWidget {
  const MyTextField({super.key, required super.fieldId, super.initialValue});
  @override
  MyTextFieldState createState() => MyTextFieldState();
}

class MyTextFieldState extends FormixTextFormFieldWidgetState {}

void main() {
  group('FieldID Coverage', () {
    test('FormixFieldID methods', () {
      const id = FormixFieldID<String>('user.profile.name');
      expect(id.parentKey, 'user.profile');
      expect(id.localName, 'name');
      expect(
        id.toString(),
        contains('FormixFieldID<String>(user.profile.name)'),
      );

      const rootId = FormixFieldID<String>('name');
      expect(rootId.parentKey, isNull);
      expect(rootId.localName, 'name');
    });

    test('FormixArrayID methods', () {
      const arrayId = FormixArrayID<String>('items');
      final itemId = arrayId.item(0);
      expect(itemId.key, 'items[0]');
      expect(arrayId.withPrefix('group').key, 'group.items');
      expect(arrayId.toString(), contains('FormixArrayID<String>(items)'));
    });
  });

  group('FormixData Coverage', () {
    test('isGroupValid and isGroupDirty', () {
      final state = FormixData.withCalculatedCounts(
        values: const {'user.name': 'John', 'user.age': 30, 'other': 'value'},
        validations: {
          'user.name': ValidationResult.valid,
          'user.age': const ValidationResult(
            isValid: false,
            errorMessage: 'Too young',
          ),
        },
        dirtyStates: const {
          'user.name': true,
          'user.age': false,
          'other': false,
        },
      );

      expect(state.isGroupValid('user'), isFalse);
      expect(state.isGroupDirty('user'), isTrue);
      expect(state.isGroupValid('other_group'), isTrue); // empty group is valid
      expect(state.isGroupDirty('other_group'), isFalse);
    });

    test('toNestedMap with dot notation', () {
      final state = FormixData.withCalculatedCounts(
        values: const {
          'user.name': 'John',
          'user.profile.bio': 'Developer',
          'settings.theme': 'dark',
          'root': 'value',
        },
      );

      final nested = state.toNestedMap();
      expect(nested['user']['name'], 'John');
      expect(nested['user']['profile']['bio'], 'Developer');
      expect(nested['settings']['theme'], 'dark');
      expect(nested['root'], 'value');
    });

    test('getValue type mismatch', () {
      final state = FormixData.withCalculatedCounts(
        values: const {'age': '30'}, // String value
      );
      const ageId = FormixFieldID<int>('age');
      expect(state.getValue(ageId), isNull); // Type mismatch returns null
    });
  });

  group('FormixScope Coverage', () {
    testWidgets('Granular watchers and non-reactive methods', (tester) async {
      const nameField = FormixFieldID<String>('name');
      const arrayField = FormixArrayID<String>('items');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'name': 'Initial',
                'items': ['Item 1'],
              },
              fields: const [
                FormixFieldConfig(id: nameField),
                FormixFieldConfig(id: arrayField),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  // Watchers
                  scope.watchValue(nameField);
                  scope.watchValidation(nameField);
                  scope.watchError(nameField);
                  scope.watchIsValidating(nameField);
                  scope.watchFieldIsValid(nameField);
                  scope.watchIsDirty(nameField);
                  scope.watchIsTouched(nameField);
                  // ignore: unnecessary_statements
                  scope.watchIsValid;
                  // ignore: unnecessary_statements
                  scope.watchIsFormDirty;
                  // ignore: unnecessary_statements
                  scope.watchIsSubmitting;
                  scope.watchGroupIsValid('user');
                  scope.watchGroupIsDirty('user');
                  scope.watchArray(arrayField);

                  try {
                    // ignore: unnecessary_statements
                    scope.watchState;
                  } catch (_) {}

                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Action methods
                          scope.toNestedMap();
                          scope.isGroupValid('user');
                          scope.isGroupDirty('user');
                          scope.markAsTouched(nameField);
                          scope.focusField(nameField);
                          scope.scrollToField(nameField);
                          scope.focusFirstError();
                          scope.addArrayItem(arrayField, 'Item 2');
                          scope.replaceArrayItem(arrayField, 0, 'New Item');
                          scope.moveArrayItem(arrayField, 0, 1);
                          scope.clearArray(arrayField);
                          scope.removeArrayItemAt(arrayField, 0);
                        },
                        child: const Text('Actions'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Actions'));
      await tester.pump();
    });
  });

  group('FormixNavigationGuard Extra Coverage', () {
    testWidgets('Guard without Formix ancestor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FormixNavigationGuard(child: Text('Child'))),
      );
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('Guard with onDirtyPop', (tester) async {
      bool onDirtyPopCalled = false;
      const nameField = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            fields: const [FormixFieldConfig(id: nameField)],
            child: FormixNavigationGuard(
              onDirtyPop: (context) async {
                onDirtyPopCalled = true;
                return true;
              },
              child: Scaffold(
                body: FormixBuilder(
                  builder: (context, scope) {
                    return Column(
                      children: [
                        const FormixTextFormField(fieldId: nameField),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Back'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Change');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(onDirtyPopCalled, isTrue);
    });

    testWidgets('Guard default dialog - Discard', (tester) async {
      const nameField = FormixFieldID<String>('name');
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Formix(
                        fields: const [FormixFieldConfig(id: nameField)],
                        child: FormixNavigationGuard(
                          child: Scaffold(
                            body: FormixBuilder(
                              builder: (context, scope) {
                                return Column(
                                  children: [
                                    const FormixTextFormField(fieldId: nameField),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      child: const Text('Back'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Change');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });

    testWidgets('Guard default dialog - Cancel', (tester) async {
      const nameField = FormixFieldID<String>('name');
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Formix(
                        fields: const [FormixFieldConfig(id: nameField)],
                        child: FormixNavigationGuard(
                          child: Scaffold(
                            body: FormixBuilder(
                              builder: (context, scope) {
                                return Column(
                                  children: [
                                    const FormixTextFormField(fieldId: nameField),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      child: const Text('Back'),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Change');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(popped, isFalse);
    });

    testWidgets('FormixBuilder outside Formix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FormixBuilder(builder: (context, scope) => Container()),
        ),
      );
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('FormixWidget outside Formix', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestWidget()));
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });

    testWidgets('FormixFieldConditionalSelector', (tester) async {
      const fieldId = FormixFieldID<String>('name');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'name': 'A'},
            fields: const [FormixFieldConfig(id: fieldId)],
            child: FormixFieldConditionalSelector<String>(
              fieldId: fieldId,
              shouldRebuild: (info) => true, // Ensure it builds
              builder: (context, info, child) {
                buildCount++;
                return Text('Value: ${info.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);
    });

    testWidgets('FormixFieldPerformanceMonitor', (tester) async {
      const fieldId = FormixFieldID<String>('name');
      int lastCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'name': 'A'},
            fields: const [FormixFieldConfig(id: fieldId)],
            child: FormixBuilder(
              builder: (context, scope) => Column(
                children: [
                  FormixFieldPerformanceMonitor<String>(
                    fieldId: fieldId,
                    builder: (context, info, count) {
                      lastCount = count;
                      return Text('Count: $count');
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => scope.setValue(fieldId, 'B'),
                    child: const Text('Update'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(lastCount, 1);
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(lastCount, 2);
    });
  });

  group('FormixController Extra Coverage', () {
    testWidgets('resetToValues and focusFirstError', (tester) async {
      const nameField = FormixFieldID<String>('name');
      late FormixController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              fields: [
                FormixFieldConfig(
                  id: nameField,
                  validator: (val) => val == 'error' ? 'Error' : null,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  controller = scope.controller;
                  return const FormixTextFormField(fieldId: nameField);
                },
              ),
            ),
          ),
        ),
      );

      // 1. Reset to values
      controller.resetToValues(const {'name': 'New Value'});
      await tester.pump();
      expect(controller.getValue(nameField), 'New Value');

      // 2. Focus first error
      controller.setValue(nameField, 'error');
      await tester.pump();
      controller.focusFirstError();
      await tester.pump();
    });
  });

  group('FormixFieldWidget Extra Coverage', () {
    testWidgets('Custom field interactions', (tester) async {
      const nameField = FormixFieldID<String>('name');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {'name': 'Initial', 'age': 20},
              child: Column(children: [MyCustomField(fieldId: nameField)]),
            ),
          ),
        ),
      );

      expect(find.text('Dirty: false'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.pump();
      expect(find.text('Dirty: true'), findsOneWidget);

      await tester.tap(find.text('Patch'));
      await tester.pump();

      await tester.tap(find.text('Focus'));
      await tester.pump();

      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('Dirty: false'), findsOneWidget);
    });

    testWidgets('FormixNumberFormFieldWidget and FormixTextFormFieldWidget', (
      tester,
    ) async {
      const numberField = FormixFieldID<int>('count');
      const textField = FormixFieldID<String>('desc');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: {'count': 10, 'desc': 'Hello'},
              child: Column(
                children: [
                  MyNumberField(fieldId: numberField),
                  MyTextField(fieldId: textField),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '10'), '20');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hello'),
        'World',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('didUpdateWidget coverage', (tester) async {
      // Just testing manual field register if not already there
      const fieldId = FormixFieldID<String>('manual');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: MyCustomField(fieldId: fieldId, initialValue: 'Initial'),
            ),
          ),
        ),
      );

      expect(find.text('Initial'), findsOneWidget);
    });
  });

  group('FormixArray and FormGroup Extra Coverage', () {
    testWidgets('Empty array builder', (tester) async {
      const arrayId = FormixArrayID<String>('items');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixArray<String>(
                id: arrayId,
                emptyBuilder: (context, scope) => const Text('Empty'),
                itemBuilder: (context, index, id, scope) => Container(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('Scrollable array', (tester) async {
      const arrayId = FormixArrayID<String>('items');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {
                'items': ['A', 'B'],
              },
              child: FormixArray<String>(
                id: arrayId,
                scrollable: true,
                itemBuilder: (context, index, id, scope) => Text('Item $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('Nested form groups resolution', (tester) async {
      String? resolvedPrefix;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              child: FormixGroup(
                prefix: 'user',
                child: FormixGroup(
                  prefix: 'profile',
                  child: Builder(
                    builder: (context) {
                      resolvedPrefix = FormixGroup.prefixOf(context);
                      return Container();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(resolvedPrefix, 'user.profile');
    });

    testWidgets('FormixArray outside Formix', (tester) async {
      const arrayId = FormixArrayID<String>('items');
      await tester.pumpWidget(
        MaterialApp(
          home: FormixArray<String>(
            id: arrayId,
            itemBuilder: (context, index, id, scope) => Container(),
          ),
        ),
      );
      expect(find.byType(FormixConfigurationErrorWidget), findsOneWidget);
    });
  });
}
