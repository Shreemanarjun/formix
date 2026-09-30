import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Advanced Formix Tests', () {
    testWidgets('Dynamic Array Fields (Contacts List)', (tester) async {
      // We will simulate a dynamic list of contacts.
      // Each contact has a name and a phone number.

      const contactsCountField = FormixFieldID<int>('contactsCount');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'contactsCount': 0},
              fields: const [
                FormixFieldConfig<int>(
                  id: contactsCountField,
                  initialValue: 0,
                ),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  // Use watchValue for reactivity
                  final int count = scope.watchValue(contactsCountField) ?? 0;

                  return Column(
                    children: [
                      ...List.generate(count, (index) {
                        final nameId = FormixFieldID<String>(
                          'contact_${index}_name',
                        );
                        final phoneId = FormixFieldID<String>(
                          'contact_${index}_phone',
                        );

                        return FormixSection(
                          key: ValueKey('contact_$index'),
                          fields: [
                            FormixFieldConfig<String>(
                              id: nameId,
                              initialValue: '',
                              validator: (v) => (v?.isEmpty ?? true) ? 'Name required' : null,
                            ),
                            FormixFieldConfig<String>(
                              id: phoneId,
                              initialValue: '',
                              validator: (v) => (v?.isEmpty ?? true) ? 'Phone required' : null,
                            ),
                          ],
                          child: Column(
                            children: [
                              FormixTextFormField(
                                fieldId: nameId,
                                decoration: InputDecoration(
                                  labelText: 'Name $index',
                                ),
                              ),
                              FormixTextFormField(
                                fieldId: phoneId,
                                decoration: InputDecoration(
                                  labelText: 'Phone $index',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  // Remove contact: In a real app we'd shift data, but here we just decrement count
                                  // and rely on unregistering the last one for simplicity of this test structure,
                                  // or we can implement real removal logic if we want to be fancy.
                                  // For this test, let's just test ADDING and VALIDATING specific items.
                                },
                                child: Text('Remove $index'),
                              ),
                            ],
                          ),
                        );
                      }),
                      ElevatedButton(
                        onPressed: () {
                          scope.controller.setValue(
                            contactsCountField,
                            count + 1,
                          );
                        },
                        child: const Text('Add Contact'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (count > 0) {
                            // Start unregistering from the end
                            final nameId = FormixFieldID<String>(
                              'contact_${count - 1}_name',
                            );
                            final phoneId = FormixFieldID<String>(
                              'contact_${count - 1}_phone',
                            );
                            scope.controller.unregisterFields([
                              nameId,
                              phoneId,
                            ]);
                            scope.controller.setValue(
                              contactsCountField,
                              count - 1,
                            );
                          }
                        },
                        child: const Text('Remove Last'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          scope.controller.submit(onValid: (_) async {});
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state: 0 contacts
      expect(find.text('Name 0'), findsNothing);

      // Add contact 0
      await tester.tap(find.text('Add Contact'));
      await tester.pumpAndSettle();

      expect(find.text('Name 0'), findsOneWidget);
      expect(find.text('Phone 0'), findsOneWidget);

      // Verify validation fails for contact 0
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Name required'), findsOneWidget); // Found 1

      // Add contact 1
      await tester.tap(find.text('Add Contact'));
      // Adding a contact updates the state (setValue), triggering FormixBuilder rebuild.
      await tester.pumpAndSettle();
      expect(find.text('Name 1'), findsOneWidget);

      // Verify validation fails for both
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Name required'), findsNWidgets(2));

      // Fill contact 0
      await tester.enterText(
        find.widgetWithText(FormixTextFormField, 'Name 0'),
        'Alice',
      );
      await tester.enterText(
        find.widgetWithText(FormixTextFormField, 'Phone 0'),
        '123',
      );
      await tester.pumpAndSettle();

      // Verify dynamic validation updates
      expect(
        find.text('Name required'),
        findsOneWidget,
      ); // Only contact 1 is invalid now

      // Remove contact 1 (Remove Last)
      await tester.tap(find.text('Remove Last'));
      await tester.pumpAndSettle();
      expect(find.text('Name 1'), findsNothing);

      // Verify validation passes now (only contact 0 remains and is valid)
      expect(find.text('Name required'), findsNothing);

      // Verify data of contact 0 persists
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('Multi-Step Wizard with State Preservation', (tester) async {
      // Step 1: Personal (Name)
      // Step 2: Address (City)
      // Fields from Step 1 should persist when moving to Step 2 (if keepAlive=true)
      // Validation should consider all fields.

      const stepField = FormixFieldID<int>('step');
      const nameField = FormixFieldID<String>('name');
      const cityField = FormixFieldID<String>('city');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Formix(
              initialValue: const {'step': 1},
              fields: const [
                FormixFieldConfig<int>(id: stepField, initialValue: 1),
              ],
              child: FormixBuilder(
                builder: (context, scope) {
                  final step = scope.watchValue(stepField) ?? 1;

                  return Column(
                    children: [
                      if (step == 1)
                        FormixSection(
                          keepAlive: true, // IMPORTANT: Keep state when switching away
                          fields: [
                            FormixFieldConfig<String>(
                              id: nameField,
                              initialValue: '',
                              validator: (v) => (v?.isEmpty ?? true) ? 'Name required' : null,
                            ),
                          ],
                          child: const FormixTextFormField(
                            fieldId: nameField,
                            decoration: InputDecoration(labelText: 'Name'),
                          ),
                        ),
                      if (step == 2)
                        FormixSection(
                          keepAlive: true,
                          fields: [
                            FormixFieldConfig<String>(
                              id: cityField,
                              initialValue: '',
                              validator: (v) => (v?.isEmpty ?? true) ? 'City required' : null,
                            ),
                          ],
                          child: const FormixTextFormField(
                            fieldId: cityField,
                            decoration: InputDecoration(labelText: 'City'),
                          ),
                        ),
                      Row(
                        children: [
                          Text('Current Step: $step'),
                          ElevatedButton(
                            onPressed: () => scope.controller.setValue(stepField, 1),
                            child: const Text('Go Step 1'),
                          ),
                          ElevatedButton(
                            onPressed: () => scope.controller.setValue(stepField, 2),
                            child: const Text('Go Step 2'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              scope.controller.validate();
                            },
                            child: const Text('Validate All'),
                          ),
                        ],
                      ),
                      FormixBuilder(
                        builder: (context, innerScope) {
                          return Text('Is Valid: ${innerScope.watchIsValid}');
                        },
                      ),
                      FormixBuilder(
                        builder: (context, innerScope) {
                          final nameVal = innerScope.watchValue(nameField);
                          return Text('Name Value: $nameVal');
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Start Step 1
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('City'), findsNothing);

      // Enter Name
      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.pump();
      expect(find.text('Name Value: Bob'), findsOneWidget);

      // Go to Step 2
      await tester.tap(find.text('Go Step 2'));
      await tester.pumpAndSettle();

      // UI Check
      expect(find.text('Name'), findsNothing);
      expect(find.text('City'), findsOneWidget);

      // Verify Name data persisted (via helper text)
      expect(find.text('Name Value: Bob'), findsOneWidget);

      // Validate All (should fail because City is empty)
      await tester.tap(find.text('Validate All'));
      await tester.pump();

      expect(find.text('Is Valid: false'), findsOneWidget);
      expect(find.text('City required'), findsOneWidget); // Visible error

      // Enter City
      await tester.enterText(find.byType(TextField), 'New York');
      await tester.pump();

      // Validate All (should pass now)
      await tester.tap(find.text('Validate All'));
      await tester.pump();
      expect(find.text('Is Valid: true'), findsOneWidget);

      // Go back to Step 1
      await tester.tap(find.text('Go Step 1'));
      await tester.pumpAndSettle();

      // Name should still be Bob
      expect(find.text('Bob'), findsOneWidget);
    });
  });
}
