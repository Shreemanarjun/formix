import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Formix State Restoration Widget Tests', () {
    testWidgets('Renders restoration form correctly - empty state', (tester) async {
      await tester.pumpWidget(
        const RootRestorationScope(
          restorationId: 'root',
          child: MaterialApp(
            restorationScopeId: 'app',
            home: RestorationTestForm(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('Restoration Test Form'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Submit'), findsOneWidget);

      // Capture golden of empty form
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restoration_empty.png'),
      );
    });

    testWidgets('Renders restoration form with data', (tester) async {
      await tester.pumpWidget(
        const RootRestorationScope(
          restorationId: 'root',
          child: MaterialApp(
            restorationScopeId: 'app',
            home: RestorationTestForm(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter data into fields
      final nameField = find.widgetWithText(TextFormField, 'Name').first;
      await tester.enterText(nameField, 'John Doe');
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Email').first;
      await tester.enterText(emailField, 'john@example.com');
      await tester.pumpAndSettle();

      final ageField = find.widgetWithText(TextFormField, 'Age').first;
      await tester.enterText(ageField, '25');
      await tester.pumpAndSettle();

      // Verify data was entered
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Verify form state shows dirty
      expect(find.textContaining('Dirty: true'), findsOneWidget);

      // Capture golden with data
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restoration_with_data.png'),
      );
    });

    testWidgets('Renders restoration form with validation errors', (tester) async {
      await tester.pumpWidget(
        const RootRestorationScope(
          restorationId: 'root',
          child: MaterialApp(
            restorationScopeId: 'app',
            home: RestorationTestForm(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter invalid email
      final emailField = find.widgetWithText(TextFormField, 'Email').first;
      await tester.enterText(emailField, 'invalid-email');
      await tester.pumpAndSettle();

      // Tap outside to lose focus and trigger validation
      await tester.tap(find.text('Restoration Test Form'));
      await tester.pumpAndSettle();

      // Submit to trigger all validations
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Verify error is shown
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(find.textContaining('Valid: false'), findsOneWidget);

      // Capture golden with errors
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/restoration_with_errors.png'),
      );
    });

    testWidgets('Form state is preserved in RestorableFormixData', (tester) async {
      await tester.pumpWidget(
        const RootRestorationScope(
          restorationId: 'root',
          child: MaterialApp(
            restorationScopeId: 'app',
            home: RestorationTestForm(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name').first,
        'Jane Smith',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email').first,
        'jane@example.com',
      );
      await tester.pumpAndSettle();

      // Get the state and verify it's being tracked
      final state = tester.state<_RestorationTestFormState>(
        find.byType(RestorationTestForm),
      );

      final formData = state.formData.value;
      expect(formData.values['name'], 'Jane Smith');
      expect(formData.values['email'], 'jane@example.com');
      expect(formData.isDirty, true);

      // Verify the RestorableFormixData can serialize
      final primitives = state.formData.toPrimitives();
      expect(primitives, isNotNull);
      expect(primitives, isA<Map>());

      // Verify we can deserialize
      final restored = state.formData.fromPrimitives(primitives);
      expect(restored.values['name'], 'Jane Smith');
      expect(restored.values['email'], 'jane@example.com');
      expect(restored.isDirty, true);
    });
  });
}

/// Test widget that demonstrates full restoration functionality
class RestorationTestForm extends StatefulWidget {
  const RestorationTestForm({super.key});

  @override
  State<RestorationTestForm> createState() => _RestorationTestFormState();
}

class _RestorationTestFormState extends State<RestorationTestForm> with RestorationMixin {
  final RestorableFormixData _formData = RestorableFormixData();

  static const nameField = FormixFieldID<String>('name');
  static const emailField = FormixFieldID<String>('email');
  static const ageField = FormixFieldID<String>('age');

  RestorableFormixData get formData => _formData;

  @override
  String? get restorationId => 'restoration_test_form';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_formData, 'form_state');
  }

  @override
  void dispose() {
    _formData.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Age is optional
    }
    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid number';
    }
    if (age < 0 || age > 150) {
      return 'Please enter a valid age';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restoration Test Form'),
        backgroundColor: Colors.blue,
      ),
      body: Formix(
        formId: 'restoration_test',
        initialData: _formData.value,
        autovalidateMode: FormixAutovalidateMode.onUserInteraction,
        onChangedData: (data) {
          setState(() {
            _formData.value = data;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Fill out this form to test restoration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              const FormixTextFormField(
                fieldId: nameField,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FormixTextFormField(
                fieldId: emailField,
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              FormixTextFormField(
                fieldId: ageField,
                validator: _validateAge,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'Enter your age (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final controller = Formix.controllerOf(context)!;
                  return ValueListenableBuilder<bool>(
                    valueListenable: controller.isValidNotifier,
                    builder: (context, isValid, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: controller.isSubmittingNotifier,
                        builder: (context, isSubmitting, _) {
                          return ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (isValid) {
                                      controller.setSubmitting(true);
                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );
                                      controller.setSubmitting(false);
                                    } else {
                                      controller.validate();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text('Submit'),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              const FormixStateDisplay(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to display current form state for debugging
class FormixStateDisplay extends StatelessWidget {
  const FormixStateDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Formix.controllerOf(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: controller.isValidNotifier,
      builder: (context, isValid, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: controller.isDirtyNotifier,
          builder: (context, isDirty, _) {
            final state = controller.state;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Form State:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Valid: $isValid'),
                  Text('Dirty: $isDirty'),
                  Text('Errors: ${state.errorCount}'),
                  Text('Dirty Fields: ${state.dirtyCount}'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
