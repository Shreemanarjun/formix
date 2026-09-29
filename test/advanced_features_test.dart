import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Restoration and Theming Tests', () {
    test('FormixData serialization', () {
      final data = FormixData.withCalculatedCounts(
        values: {'name': 'John'},
        validations: {'name': const ValidationResult(isValid: false, errorMessage: 'Error')},
        currentStep: 2,
      );

      final map = data.toMap();
      final restored = FormixData.fromMap(map);

      expect(restored.values['name'], 'John');
      expect(restored.validations['name']?.isValid, false);
      expect(restored.validations['name']?.errorMessage, 'Error');
      expect(restored.currentStep, 2);
    });

    testWidgets('FormixTheme applies default decoration', (tester) async {
      const id = FormixFieldID<String>('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              theme: FormixThemeData(
                decorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.red,
                ),
              ),
              fields: [
                FormixFieldConfig(id: id, initialValue: ''),
              ],
              child: FormixTextFormField(fieldId: id),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.filled, true);
      expect(textField.decoration?.fillColor, Colors.red);
    });

    testWidgets('FormixTheme does NOT apply when enabled is false', (tester) async {
      const id = FormixFieldID<String>('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              theme: FormixThemeData(
                enabled: false,
                decorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.red,
                ),
              ),
              fields: [
                FormixFieldConfig(id: id, initialValue: ''),
              ],
              child: FormixTextFormField(fieldId: id),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      // Default filled is false
      expect(textField.decoration?.filled, isNot(true));
      expect(textField.decoration?.fillColor, isNot(Colors.red));
    });

    testWidgets('FormixTheme applies to Number and Dropdown fields', (tester) async {
      const numId = FormixFieldID<int>('num');
      const dropId = FormixFieldID<String>('drop');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              theme: FormixThemeData(
                decorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.blue,
                ),
              ),
              fields: [
                FormixFieldConfig(id: numId, initialValue: 0),
                FormixFieldConfig(id: dropId, initialValue: 'A'),
              ],
              child: Column(
                children: [
                  FormixNumberFormField<int>(fieldId: numId),
                  FormixDropdownFormField<String>(
                    fieldId: dropId,
                    items: [
                      DropdownMenuItem(value: 'A', child: Text('A')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.first.decoration?.filled, true);
      expect(textFields.first.decoration?.fillColor, Colors.blue);

      final inputDecorator = tester.widget<InputDecorator>(
        find.descendant(of: find.byType(FormixDropdownFormField<String>), matching: find.byType(InputDecorator)),
      );
      expect(inputDecorator.decoration.filled, true);
      expect(inputDecorator.decoration.fillColor, Colors.blue);
    });

    testWidgets('Nested FormixTheme overrides outer one', (tester) async {
      const id1 = FormixFieldID<String>('f1');
      const id2 = FormixFieldID<String>('f2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              theme: FormixThemeData(
                decorationTheme: InputDecorationTheme(fillColor: Colors.red, filled: true),
              ),
              fields: [
                FormixFieldConfig(id: id1, initialValue: ''),
                FormixFieldConfig(id: id2, initialValue: ''),
              ],
              child: Column(
                children: [
                  FormixTextFormField(fieldId: id1),
                  FormixTheme(
                    data: FormixThemeData(
                      decorationTheme: InputDecorationTheme(fillColor: Colors.green, filled: true),
                    ),
                    child: FormixTextFormField(fieldId: id2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields[0].decoration?.fillColor, Colors.red);
      expect(textFields[1].decoration?.fillColor, Colors.green);
    });

    test('Complex FormixData restoration integrity', () {
      final original = FormixData.withCalculatedCounts(
        values: {
          'name': 'Alice',
          'age': 30,
          'tags': ['flutter', 'dart'],
        },
        validations: {
          'name': const ValidationResult(isValid: true),
          'age': const ValidationResult(isValid: false, errorMessage: 'Too old'),
        },
        dirtyStates: {'name': true},
        touchedStates: {'age': true},
        currentStep: 5,
        isSubmitting: true,
      );

      final serialized = original.toMap();
      final restored = FormixData.fromMap(serialized);

      expect(restored.values['name'], 'Alice');
      expect(restored.values['age'], 30);
      expect(restored.values['tags'], containsAll(['flutter', 'dart']));
      expect(restored.validations['age']?.errorMessage, 'Too old');
      expect(restored.dirtyStates['name'], true);
      expect(restored.touchedStates['age'], true);
      expect(restored.currentStep, 5);
      expect(restored.isSubmitting, true);

      // Verify pre-calculated counts were restored correctly
      expect(restored.errorCount, 1);
      expect(restored.dirtyCount, 1);
    });

    testWidgets('FormixTheme is reactive when data changes', (tester) async {
      const id = FormixFieldID<String>('test');

      final themeNotifier = ValueNotifier<Color>(Colors.red);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Color>(
              valueListenable: themeNotifier,
              builder: (context, color, child) {
                return Formix(
                  theme: FormixThemeData(
                    decorationTheme: InputDecorationTheme(fillColor: color, filled: true),
                  ),
                  fields: const [
                    FormixFieldConfig(id: id, initialValue: ''),
                  ],
                  child: const FormixTextFormField(fieldId: id),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).decoration?.fillColor, Colors.red);

      // Change theme color
      themeNotifier.value = Colors.blue;
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).decoration?.fillColor, Colors.blue);
    });

    testWidgets('FormixTheme applies global icons', (tester) async {
      const id = FormixFieldID<String>('test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              theme: FormixThemeData(
                loadingIcon: Icon(Icons.refresh, key: Key('global-loading')),
                editIcon: Icon(Icons.check, key: Key('global-edit')),
              ),
              fields: [
                FormixFieldConfig(id: id, initialValue: 'initial'),
              ],
              child: FormixTextFormField(fieldId: id),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially not dirty, no edit icon
      expect(find.byKey(const Key('global-edit')), findsNothing);

      // Make it dirty
      await tester.enterText(find.byType(TextField), 'changed');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global-edit')), findsOneWidget);
    });
  });
}
