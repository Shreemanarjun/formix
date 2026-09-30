import 'package:flutter/material.dart';
import 'package:formix/formix.dart';
import '../../constants/field_ids.dart';
import 'advanced_fields.dart';

// Advanced Example
class AdvancedExample extends StatelessWidget {
  const AdvancedExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdvancedExampleContent();
  }
}

class AdvancedExampleContent extends StatefulWidget {
  const AdvancedExampleContent({super.key});

  @override
  State<AdvancedExampleContent> createState() => _AdvancedExampleContentState();
}

class _AdvancedExampleContentState extends State<AdvancedExampleContent> {
  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'advanced_showcase',
      initialValue: const {
        'name': 'John Doe',
        'email': 'john@example.com',
        'age': 25,
        'newsletter': true,
        'country': 'US',
        'bio': '',
        'password': '',
        'confirmPassword': '',
      },
      fields: advancedFieldConfigs,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Features Showcase',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Comprehensive example with declarative cross-field validation and automatic state management',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Info notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This form uses crossFieldValidator and dependsOn. Notice how the confirm password field reacts instantly when the original password changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form fields
            FormixTextFormField(
              fieldId: nameField,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            FormixTextFormField(
              fieldId: emailField,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            FormixNumberFormField(
              fieldId: ageField,
              min: 0,
              max: 150,
              decoration: const InputDecoration(
                labelText: 'Age',
                hintText: 'Enter your age',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),

            FormixDropdownFormField<String>(
              fieldId: countryField,
              items: const [
                DropdownMenuItem(value: 'US', child: Text('United States')),
                DropdownMenuItem(value: 'CA', child: Text('Canada')),
                DropdownMenuItem(value: 'UK', child: Text('United Kingdom')),
                DropdownMenuItem(value: 'DE', child: Text('Germany')),
                DropdownMenuItem(value: 'FR', child: Text('France')),
                DropdownMenuItem(value: 'JP', child: Text('Japan')),
              ],
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 16),

            FormixCheckboxFormField(
              fieldId: newsletterField,
              title: const Text('Subscribe to newsletter'),
            ),
            const SizedBox(height: 16),

            // Password fields
            const Text(
              'Password Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: passwordField,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Create a password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),
            FormixTextFormField(
              fieldId: confirmPasswordField,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Confirm your password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Bio field
            FormixTextFormField(
              fieldId: bioField,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself (max 500 characters)',
                prefixIcon: Icon(Icons.text_fields),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 24),
            const FormixFormStatus(),
            const SizedBox(height: 16),

            FormixBuilder(
              select: (state) => Object.hash(state.isValid, state.isDirty),
              builder: (context, scope) {
                final isValid = scope.watchIsValid;
                final isDirty = scope.watchIsFormDirty;
                final formValues = scope.values;

                return Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: isValid
                              ? () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Submitting...'),
                                    ),
                                  );

                                  await Future.delayed(
                                    const Duration(seconds: 2),
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile updated successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Profile'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Form Values'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: formValues.entries.map((entry) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          '${entry.key}: ${entry.value}',
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('Show Values'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => scope.controller.reset(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isValid
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isValid
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isValid ? Icons.check_circle : Icons.error,
                            color: isValid ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isValid
                                  ? 'Form is valid and ready to submit'
                                  : 'Form has validation errors: ${scope.controller.errors}',
                              style: TextStyle(
                                color: isValid
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isDirty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Modified',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
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
