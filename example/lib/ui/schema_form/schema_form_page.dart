import 'package:flutter/material.dart';
import 'package:formix/formix.dart';
import '../../constants/field_ids.dart';

// Schema-based Form Example
class SchemaFormExample extends StatelessWidget {
  const SchemaFormExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const SchemaFormExampleContent();
  }
}

class SchemaFormExampleContent extends StatefulWidget {
  const SchemaFormExampleContent({super.key});

  @override
  State<SchemaFormExampleContent> createState() =>
      _SchemaFormExampleContentState();
}

class _SchemaFormExampleContentState extends State<SchemaFormExampleContent> {
  late final FormSchema schema;
  late final SchemaBasedFormController controller;

  @override
  void initState() {
    super.initState();
    schema = FormSchema(
      name: 'User Registration',
      description: 'Complete your profile information',
      fields: [
        TextFieldSchema(
          id: nameField,
          initialValue: '',
          label: 'Full Name',
          hint: 'Enter your full name',
          isRequired: true,
          minLength: 2,
          maxLength: 50,
        ),
        TextFieldSchema(
          id: emailField,
          initialValue: '',
          label: 'Email Address',
          hint: 'Enter your email',
          isRequired: true,
          pattern: r'^[^@]+@[^@]+\.[^@]+$',
        ),
        NumberFieldSchema(
          id: ageField,
          initialValue: 18,
          label: 'Age',
          hint: 'Enter your age',
          min: 13,
          max: 120,
          decimalPlaces: 0,
        ),
        DateFieldSchema(
          id: dobField,
          initialValue: DateTime(2000, 1, 1),
          label: 'Date of Birth',
          minDate: DateTime(1900, 1, 1),
          maxDate: DateTime.now(),
        ),
        BooleanFieldSchema(
          id: newsletterField,
          initialValue: false,
          label: 'Subscribe to newsletter',
        ),
        SelectionFieldSchema<String>(
          id: FormixFieldID<String>('country'),
          initialValue: 'US',
          label: 'Country',
          options: ['US', 'CA', 'UK', 'DE', 'FR', 'JP'],
        ),
      ],
      submitButtonText: 'Register',
      resetButtonText: 'Clear Form',
      onSubmit: _handleSubmit,
      onValidate: _customValidation,
    );

    controller = SchemaBasedFormController(schema: schema);
  }

  Future<void> _handleSubmit(Map<String, dynamic> values) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration successful! Welcome ${values['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<List<String>> _customValidation(Map<String, dynamic> values) async {
    final errors = <String>[];

    // Cross-field validation example
    final age = values['age'] as num?;
    final dob = values['dob'] as DateTime?;

    if (age != null && dob != null) {
      final calculatedAge = DateTime.now().year - dob.year;
      if ((DateTime.now().month < dob.month ||
              (DateTime.now().month == dob.month &&
                  DateTime.now().day < dob.day)) &&
          calculatedAge - 1 != age) {
        errors.add('Age does not match date of birth');
      }
    }

    return errors;
  }

  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'schema_form_example',
      initialValue: {
        'name': '',
        'email': '',
        'age': 18,
        'dob': DateTime(2000, 1, 1),
        'newsletter': false,
        'country': 'US',
      },
      fields: [
        FormixFieldConfig<String>(
          id: nameField,
          initialValue: '',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Name is required';
            if (value!.length < 2) return 'Name must be at least 2 characters';
            return null;
          },
        ),
        FormixFieldConfig<String>(
          id: emailField,
          initialValue: '',
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Email is required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value!)) {
              return 'Invalid email format';
            }
            return null;
          },
        ),
        FormixFieldConfig<num>(
          id: ageField,
          initialValue: 18,
          validator: (value) {
            if ((value ?? 0) < 13) return 'Must be at least 13 years old';
            if ((value ?? 0) > 120) return 'Age must be realistic';
            return null;
          },
        ),
        FormixFieldConfig<DateTime>(
          id: dobField,
          initialValue: DateTime(2000, 1, 1),
        ),
        FormixFieldConfig<bool>(id: newsletterField, initialValue: false),
        FormixFieldConfig<String>(
          id: FormixFieldID<String>('country'),
          initialValue: 'US',
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schema-Based Form',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Forms defined with schemas for type safety and validation',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Form fields
            FormixTextFormField(
              fieldId: nameField,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 16),

            FormixTextFormField(
              fieldId: emailField,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.email)),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Date field using custom widget
            const Text('Date of Birth'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FormixBuilder(
                builder: (context, scope) {
                  final controller = scope.controller;
                  final value = scope.watchValue(dobField);
                  return ListTile(
                    title: Text(
                      value?.toString().split(' ')[0] ?? 'Select date',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: value ?? DateTime(2000, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        controller.setValue(dobField, picked);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            FormixCheckboxFormField(
              fieldId: newsletterField,
              title: const Text('Subscribe to newsletter'),
            ),
            const SizedBox(height: 16),

            FormixDropdownFormField<String>(
              fieldId: FormixFieldID<String>('country'),
              items: const [
                DropdownMenuItem(value: 'US', child: Text('United States')),
                DropdownMenuItem(value: 'CA', child: Text('Canada')),
                DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
                DropdownMenuItem(value: 'DE', child: Text('Germany')),
                DropdownMenuItem(value: 'FR', child: Text('France')),
                DropdownMenuItem(value: 'JP', child: Text('Japan')),
              ],
              decoration: const InputDecoration(prefixIcon: Icon(Icons.flag)),
            ),

            const SizedBox(height: 24),
            const FormixFormStatus(),
            const SizedBox(height: 16),

            FormixBuilder(
              builder: (context, scope) {
                final controller = scope.controller;
                final formState = scope.watchState;

                return Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final result = await schema.submit(
                              formState.values,
                            );
                            if (!context.mounted) return;

                            if (result.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Registration successful!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Validation failed: ${result.error}',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Register'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.reset(),
                        child: const Text('Clear Form'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
