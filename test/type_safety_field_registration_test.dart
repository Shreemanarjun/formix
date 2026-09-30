import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formix/formix.dart';

void main() {
  group('Type Safety - Field Registration with Typed Validators', () {
    testWidgets(
      'DateTime field with typed validator works correctly',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const dateField = FormixFieldID<DateTime?>('appointmentDate');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                fields: [
                  FormixFieldConfig<DateTime?>(
                    id: dateField,
                    initialValue: DateTime(2026, 2, 8),
                    validator: (value) {
                      return value == null ? 'Please select a date' : null;
                    },
                  ),
                ],
                child: FormixRawFormField<DateTime?>(
                  fieldId: dateField,
                  builder: (context, state) {
                    return Column(
                      children: [
                        Text('Date: ${state.value}'),
                        if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the field is registered and working
        expect(find.text('Date: 2026-02-08 00:00:00.000'), findsOneWidget);

        // Clear the field to trigger validation
        final controller = formKey.currentState!.controller;
        controller.setValue(dateField, null);
        controller.markAsTouched(dateField);
        await tester.pumpAndSettle();

        // Verify validation error appears
        expect(find.text('Error: Please select a date'), findsOneWidget);
      },
    );

    testWidgets(
      'Multiple typed fields with different types work together',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const dateField = FormixFieldID<DateTime?>('date');
        const timeField = FormixFieldID<TimeOfDay?>('time');
        const stringField = FormixFieldID<String>('remark');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                fields: [
                  FormixFieldConfig<DateTime?>(
                    id: dateField,
                    validator: (value) => value == null ? 'Date required' : null,
                  ),
                  FormixFieldConfig<TimeOfDay?>(
                    id: timeField,
                    validator: (value) => value == null ? 'Time required' : null,
                  ),
                  FormixFieldConfig<String>(
                    id: stringField,
                    validator: (value) => value?.isEmpty ?? true ? 'Remark required' : null,
                  ),
                ],
                child: Column(
                  children: [
                    FormixRawFormField<DateTime?>(
                      fieldId: dateField,
                      builder: (context, state) => Text('Date: ${state.value}'),
                    ),
                    FormixRawFormField<TimeOfDay?>(
                      fieldId: timeField,
                      builder: (context, state) => Text('Time: ${state.value}'),
                    ),
                    const FormixTextFormField(
                      fieldId: stringField,
                      decoration: InputDecoration(labelText: 'Remark'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify all fields are rendered without type errors
        expect(find.text('Date: null'), findsOneWidget);
        expect(find.text('Time: null'), findsOneWidget);
        expect(find.byType(FormixTextFormField), findsOneWidget);

        // Trigger validation on all fields
        final controller = formKey.currentState!.controller;
        final result = controller.validate();

        expect(result, false);
        expect(controller.errors.length, 3);
      },
    );

    testWidgets(
      'Field re-registration with different validator preserves type safety',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const dateField = FormixFieldID<DateTime?>('date');

        // First validator
        String? validator1(DateTime? value) {
          return value == null ? 'Date required' : null;
        }

        // Second validator with different logic
        String? validator2(DateTime? value) {
          if (value == null) return 'Date is required';
          if (value.isBefore(DateTime.now())) {
            return 'Date must be in the future';
          }
          return null;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                fields: [
                  FormixFieldConfig<DateTime?>(
                    id: dateField,
                    validator: validator1,
                  ),
                ],
                child: FormixRawFormField<DateTime?>(
                  fieldId: dateField,
                  validator: validator2, // Override with widget validator
                  builder: (context, state) {
                    return Column(
                      children: [
                        Text('Date: ${state.value}'),
                        if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Set a past date
        final controller = formKey.currentState!.controller;
        controller.setValue(dateField, DateTime(2020, 1, 1));
        controller.markAsTouched(dateField);
        await tester.pumpAndSettle();

        // Should use validator2 (from widget)
        final validation = controller.getValidation(dateField);
        expect(validation.isValid, false);
        expect(validation.errorMessage, 'Date must be in the future');
      },
    );

    testWidgets(
      'Async validator with typed field works correctly',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const dateField = FormixFieldID<DateTime?>('date');

        Future<String?> asyncValidator(DateTime? value) async {
          await Future.delayed(const Duration(milliseconds: 50));
          if (value == null) return 'Date required';
          // Simulate checking if date is available
          if (value.weekday == DateTime.saturday || value.weekday == DateTime.sunday) {
            return 'Weekends not available';
          }
          return null;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                autovalidateMode: FormixAutovalidateMode.always,
                fields: [
                  FormixFieldConfig<DateTime?>(
                    id: dateField,
                    asyncValidator: asyncValidator,
                    debounceDuration: Duration.zero, // No debounce for testing
                  ),
                ],
                child: FormixRawFormField<DateTime?>(
                  fieldId: dateField,
                  builder: (context, state) {
                    return Column(
                      children: [
                        Text('Date: ${state.value}'),
                        if (state.validation.isValidating) const Text('Validating...') else if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final controller = formKey.currentState!.controller;

        // Set a Saturday
        controller.setValue(dateField, DateTime(2026, 2, 7)); // Saturday

        // Wait for debounce and async validation to complete
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final validation = controller.getValidation(dateField);
        expect(validation.isValid, false);
        expect(validation.errorMessage, 'Weekends not available');
      },
    );

    testWidgets(
      'Complex object type with custom validator',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const locationField = FormixFieldID<ScheduleLocation?>('location');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                fields: [
                  FormixFieldConfig<ScheduleLocation?>(
                    id: locationField,
                    validator: (value) {
                      return value == null ? 'Please select a location' : null;
                    },
                  ),
                ],
                child: FormixRawFormField<ScheduleLocation?>(
                  fieldId: locationField,
                  builder: (context, state) {
                    return Column(
                      children: [
                        Text('Location: ${state.value?.name ?? "None"}'),
                        if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify field renders without type errors
        expect(find.text('Location: None'), findsOneWidget);

        // Set a value
        final controller = formKey.currentState!.controller;
        controller.setValue(
          locationField,
          const ScheduleLocation(id: '1', name: 'Clinic A', followUpType: 'In-person'),
        );
        await tester.pumpAndSettle();

        // Verify validation passes
        final validation = controller.getValidation(locationField);
        expect(validation.isValid, true);
        expect(find.text('Location: Clinic A'), findsOneWidget);
      },
    );

    testWidgets(
      'Widget validator override with different type signature works',
      (tester) async {
        final formKey = GlobalKey<FormixState>();
        const locationField = FormixFieldID<ScheduleLocation?>('location');

        // Config validator
        String? configValidator(ScheduleLocation? value) {
          return value == null ? 'Location required' : null;
        }

        // Widget validator with different logic
        String? widgetValidator(ScheduleLocation? value) {
          if (value == null) return 'Please select a location';
          if (value.followUpType == 'Remote') {
            return 'Remote locations not supported';
          }
          return null;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Formix(
                key: formKey,
                fields: [
                  FormixFieldConfig<ScheduleLocation?>(
                    id: locationField,
                    validator: configValidator,
                  ),
                ],
                child: FormixRawFormField<ScheduleLocation?>(
                  fieldId: locationField,
                  validator: widgetValidator, // Override
                  builder: (context, state) {
                    return Column(
                      children: [
                        Text('Location: ${state.value?.name ?? "None"}'),
                        if (state.hasError) Text('Error: ${state.validation.errorMessage}'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final controller = formKey.currentState!.controller;

        // Set a remote location
        controller.setValue(
          locationField,
          const ScheduleLocation(id: '2', name: 'Remote Clinic', followUpType: 'Remote'),
        );
        controller.markAsTouched(locationField);
        await tester.pumpAndSettle();

        // Should use widget validator
        final validation = controller.getValidation(locationField);
        expect(validation.isValid, false);
        expect(validation.errorMessage, 'Remote locations not supported');
      },
    );
  });
}

// Test model class
class ScheduleLocation {
  final String id;
  final String name;
  final String followUpType;

  const ScheduleLocation({
    required this.id,
    required this.name,
    required this.followUpType,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScheduleLocation && runtimeType == other.runtimeType && id == other.id && name == other.name && followUpType == other.followUpType;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ followUpType.hashCode;
}
