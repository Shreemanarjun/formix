import 'package:flutter/material.dart';
import 'package:formix/formix.dart';
import '../../constants/field_ids.dart';

// Basic Form Example with Declarative API
class BasicFormExample extends StatelessWidget {
  const BasicFormExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'basic_form_example',
      initialValue: {'name': '', 'email': '', 'age': 18, 'newsletter': false},
      fields: [
        FormixFieldConfig<String>(
          id: nameField,
          initialValue: '',
          validator: _validateName,
          label: 'Full Name',
          hint: 'Enter your full name',
        ),
        FormixFieldConfig<String>(
          id: emailField,
          initialValue: '',
          validator: _validateEmail,
          label: 'Email',
          hint: 'Enter your email',
        ),
        FormixFieldConfig<num>(
          id: ageField,
          initialValue: 18,
          validator: _validateAge,
          label: 'Age',
          hint: 'Enter your age',
        ),
        FormixFieldConfig<bool>(
          id: newsletterField,
          initialValue: false,
          label: 'Newsletter',
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Form Fields (Declarative API)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fields are automatically registered with validation!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
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
            FormixNumberFormField(
              fieldId: ageField,
              min: 0,
              max: 120,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            FormixCheckboxFormField(
              fieldId: newsletterField,
              title: const Text('Subscribe to newsletter'),
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
                        onPressed: () {
                          final values = formState.values;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Form values: $values'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        child: const Text('Show Values'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.reset(),
                        child: const Text('Reset'),
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

  static String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Invalid email format';
    return null;
  }

  static String? _validateAge(num? value) {
    if (value == null) return 'Age is required';
    if (value < 0) return 'Age cannot be negative';
    if (value > 120) return 'Age must be realistic';
    return null;
  }
}
