import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('FieldDerivationConfig', () {
    test('equality works correctly', () {
      const fieldId1 = FormixFieldID<String>('field1');
      const fieldId2 = FormixFieldID<String>('field2');
      const targetId = FormixFieldID<String>('target');

      final config1 = FieldDerivationConfig(
        dependencies: [fieldId1, fieldId2],
        derive: (values) => 'derived',
        targetField: targetId,
      );

      final config2 = FieldDerivationConfig(
        dependencies: [fieldId1, fieldId2],
        derive: (values) => 'derived',
        targetField: targetId,
      );

      final config3 = FieldDerivationConfig(
        dependencies: [fieldId2, fieldId1], // Different order
        derive: (values) => 'derived',
        targetField: targetId,
      );

      expect(config1 == config2, true);
      expect(config1 == config3, false); // Order matters for listEquals
    });

    test('hashCode works correctly', () {
      const fieldId1 = FormixFieldID<String>('field1');
      const fieldId2 = FormixFieldID<String>('field2');
      const targetId = FormixFieldID<String>('target');

      final config1 = FieldDerivationConfig(
        dependencies: [fieldId1, fieldId2],
        derive: (values) => 'derived',
        targetField: targetId,
      );

      final config2 = FieldDerivationConfig(
        dependencies: [fieldId1, fieldId2],
        derive: (values) => 'derived',
        targetField: targetId,
      );

      expect(config1.hashCode == config2.hashCode, true);
    });
  });

  group('FormixFieldDerivation', () {
    late FormixFieldID<String> sourceField;
    late FormixFieldID<String> targetField;
    late FormixFieldID<int> ageField;
    late FormixFieldID<DateTime> dobField;

    setUp(() {
      sourceField = const FormixFieldID<String>('source');
      targetField = const FormixFieldID<String>('target');
      ageField = const FormixFieldID<int>('age');
      dobField = const FormixFieldID<DateTime>('dob');
    });

    testWidgets('build returns SizedBox.shrink', (tester) async {
      final widget = FormixFieldDerivation(
        dependencies: [sourceField],
        derive: (values) => values[sourceField]?.toUpperCase(),
        targetField: targetField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'initial',
              'target': 'target_initial',
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      expect(find.byWidget(widget), findsOneWidget);
      // The widget should render as a SizedBox.shrink
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('derives value on dependency change', (tester) async {
      final widget = FormixFieldDerivation(
        dependencies: [sourceField],
        derive: (values) => values[sourceField]?.toUpperCase(),
        targetField: targetField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'initial',
              'target': 'target_initial',
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      // Get controller to check values
      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;

      // Initial value should be derived
      expect(controller.getValue(targetField), 'INITIAL');

      // Change source value
      controller.setValue(sourceField, 'new value');
      await tester.pump();

      expect(controller.getValue(targetField), 'NEW VALUE');
    });

    testWidgets('handles multiple dependencies', (tester) async {
      const firstNameField = FormixFieldID<String>('firstName');
      const lastNameField = FormixFieldID<String>('lastName');
      const fullNameField = FormixFieldID<String>('fullName');

      final widget = FormixFieldDerivation(
        dependencies: const [firstNameField, lastNameField],
        derive: (values) => '${values[firstNameField]} ${values[lastNameField]}',
        targetField: fullNameField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'firstName': 'John',
              'lastName': 'Doe',
              'fullName': '',
            },
            fields: const [
              FormixFieldConfig(id: firstNameField),
              FormixFieldConfig(id: lastNameField),
              FormixFieldConfig(id: fullNameField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;

      expect(controller.getValue(fullNameField), 'John Doe');

      controller.setValue(firstNameField, 'Jane');
      await tester.pump();
      expect(controller.getValue(fullNameField), 'Jane Doe');
    });

    testWidgets('handles age calculation from date of birth', (tester) async {
      final widget = FormixFieldDerivation(
        dependencies: [dobField],
        derive: (values) {
          final dob = values[dobField] as DateTime?;
          if (dob == null) return 0; // Return 0 instead of null

          final now = DateTime.now();
          int age = now.year - dob.year;
          if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          return age;
        },
        targetField: ageField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {'age': 0},
            fields: [
              FormixFieldConfig(
                id: dobField,
                initialValue: DateTime(2000, 1, 1),
              ),
              FormixFieldConfig(id: ageField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;

      final expectedAge = DateTime.now().year - 2000;
      expect(controller.getValue(ageField), expectedAge);
    });

    testWidgets('handles errors gracefully in debug mode', (tester) async {
      final widget = FormixFieldDerivation(
        dependencies: [sourceField],
        derive: (values) {
          throw Exception('Test error');
        },
        targetField: targetField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'initial',
              'target': 'target_initial',
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;

      // Should not crash, target field should keep its initial value
      expect(controller.getValue(targetField), 'target_initial');
    });

    testWidgets('updates listeners when dependencies change', (tester) async {
      const newSourceField = FormixFieldID<String>('newSource');

      final widget = FormixFieldDerivation(
        dependencies: [sourceField],
        derive: (values) => values[sourceField]?.toUpperCase(),
        targetField: targetField,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'initial',
              'target': 'target_initial',
              'newSource': 'new source',
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
              const FormixFieldConfig(id: newSourceField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivation)),
      )!;

      expect(controller.getValue(targetField), 'INITIAL');

      // Update widget with new dependencies
      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'source': 'initial',
              'target': 'target_initial',
              'newSource': 'new source',
            },
            fields: [
              FormixFieldConfig(id: sourceField),
              FormixFieldConfig(id: targetField),
              const FormixFieldConfig(id: newSourceField),
            ],
            child: FormixFieldDerivation(
              dependencies: const [newSourceField],
              derive: (values) {
                final value = values[newSourceField] as String?;
                return value?.toUpperCase();
              },
              targetField: targetField,
            ),
          ),
        ),
      );

      expect(controller.getValue(targetField), 'NEW SOURCE');
    });
  });

  group('FormixFieldDerivations', () {
    late FormixFieldID<String> firstNameField;
    late FormixFieldID<String> lastNameField;
    late FormixFieldID<String> fullNameField;
    late FormixFieldID<String> emailField;
    late FormixFieldID<String> displayNameField;

    setUp(() {
      firstNameField = const FormixFieldID<String>('firstName');
      lastNameField = const FormixFieldID<String>('lastName');
      fullNameField = const FormixFieldID<String>('fullName');
      emailField = const FormixFieldID<String>('email');
      displayNameField = const FormixFieldID<String>('displayName');
    });

    testWidgets('handles multiple derivations', (tester) async {
      final configs = [
        FieldDerivationConfig(
          dependencies: [firstNameField, lastNameField],
          derive: (values) => '${values[firstNameField]} ${values[lastNameField]}',
          targetField: fullNameField,
        ),
        FieldDerivationConfig(
          dependencies: [firstNameField, emailField],
          derive: (values) => '${values[firstNameField]} <${values[emailField]}>',
          targetField: displayNameField,
        ),
      ];

      final widget = FormixFieldDerivations(derivations: configs);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(
            initialValue: const {
              'firstName': 'John',
              'lastName': 'Doe',
              'fullName': '',
              'email': 'john@example.com',
              'displayName': '',
            },
            fields: [
              FormixFieldConfig(id: firstNameField),
              FormixFieldConfig(id: lastNameField),
              FormixFieldConfig(id: fullNameField),
              FormixFieldConfig(id: emailField),
              FormixFieldConfig(id: displayNameField),
            ],
            child: widget,
          ),
        ),
      );

      final controller = Formix.of(
        tester.element(find.byType(FormixFieldDerivations)),
      )!;

      expect(controller.getValue(fullNameField), 'John Doe');
      expect(controller.getValue(displayNameField), 'John <john@example.com>');

      controller.setValue(firstNameField, 'Jane');
      await tester.pump();

      expect(controller.getValue(fullNameField), 'Jane Doe');
      expect(controller.getValue(displayNameField), 'Jane <john@example.com>');
    });

    testWidgets('build returns SizedBox.shrink', (tester) async {
      const widget = FormixFieldDerivations(derivations: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Formix(initialValue: {}, fields: [], child: widget),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
