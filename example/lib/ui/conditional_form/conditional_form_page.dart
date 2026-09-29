import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

// Conditional Fields Example
class ConditionalFormExample extends StatelessWidget {
  const ConditionalFormExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conditional Form Example')),
      body: const ConditionalFormExampleContent(),
    );
  }
}

class ConditionalFormExampleContent extends StatefulWidget {
  const ConditionalFormExampleContent({super.key});

  @override
  State<ConditionalFormExampleContent> createState() =>
      _ConditionalFormExampleContentState();
}

class _ConditionalFormExampleContentState
    extends State<ConditionalFormExampleContent> {
  static const accountTypeField = FormixFieldID<String>('accountType');
  static const companyNameField = FormixFieldID<String>('companyName');
  static const taxIdField = FormixFieldID<String>('taxId');
  static const firstNameField = FormixFieldID<String>('firstName');
  static const lastNameField = FormixFieldID<String>('lastName');
  static const hasNewsletterField = FormixFieldID<bool>('hasNewsletter');
  static const newsletterFrequencyField = FormixFieldID<String>(
    'newsletterFrequency',
  );
  static const contactMethodField = FormixFieldID<String>('contactMethod');
  static const phoneNumberField = FormixFieldID<String>('phoneNumber');
  static const preferredTimeField = FormixFieldID<String>('preferredTime');

  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'conditional_form_example',
      initialValue: {
        'accountType': 'personal',
        'companyName': '',
        'taxId': '',
        'firstName': '', // Ensure initial values for always-visible fields
        'lastName': '',
      },
      fields: [
        FormixFieldConfig<String>(
          id: accountTypeField,
          initialValue: 'personal',
        ),
        FormixFieldConfig<String>(
          id: firstNameField,
          initialValue: '',
          validator: (value) {
            if (value == null || value.isEmpty) return 'First name is required';
            return null;
          },
        ),
        FormixFieldConfig<String>(
          id: lastNameField,
          initialValue: '',
          validator: (value) {
            if (value == null || value.isEmpty) return 'Last name is required';
            return null;
          },
        ),
        FormixFieldConfig<bool>(id: hasNewsletterField, initialValue: false),
        FormixFieldConfig<String>(
          id: contactMethodField,
          initialValue: 'email',
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conditional Fields',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fields that show/hide based on other field values',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Account Type Selection
            const Text('Account Type'),
            const SizedBox(height: 8),
            FormixDropdownFormField<String>(
              fieldId: accountTypeField,
              items: const [
                DropdownMenuItem(
                  value: 'personal',
                  child: Text('Personal Account'),
                ),
                DropdownMenuItem(
                  value: 'business',
                  child: Text('Business Account'),
                ),
              ],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),

            // Conditional Business Fields using FormixSection
            FormixBuilder(
              builder: (context, scope) {
                final accountType = scope.watchValue(accountTypeField);
                if (accountType == 'business') {
                  return FormixSection(
                    key: const ValueKey('business_section'),
                    keepAlive: false, // Drop state when switched to personal
                    fields: [
                      FormixFieldConfig<String>(
                        id: companyNameField,
                        initialValue: '',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Company name is required';
                          }
                          return null;
                        },
                      ),
                      FormixFieldConfig<String>(
                        id: taxIdField,
                        initialValue: '',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tax ID is required';
                          }
                          return null;
                        },
                      ),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const FormixTextFormField(
                          fieldId: companyNameField,
                          decoration: InputDecoration(
                            labelText: 'Company Name',
                            prefixIcon: Icon(Icons.business_center),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const FormixTextFormField(
                          fieldId: taxIdField,
                          decoration: InputDecoration(
                            labelText: 'Tax ID',
                            prefixIcon: Icon(Icons.account_balance),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Personal Information (always shown)
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const FormixTextFormField(
              fieldId: firstNameField,
              decoration: InputDecoration(
                labelText: 'First Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            const FormixTextFormField(
              fieldId: lastNameField,
              decoration: InputDecoration(
                labelText: 'Last Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Newsletter Subscription
            const FormixCheckboxFormField(
              fieldId: hasNewsletterField,
              title: Text('Subscribe to newsletter'),
            ),
            const SizedBox(height: 16),

            // Conditional Newsletter Frequency
            FormixBuilder(
              builder: (context, scope) {
                final hasNewsletter = scope.watchValue(hasNewsletterField);
                if (hasNewsletter == true) {
                  return FormixSection(
                    key: const ValueKey('newsletter_section'),
                    keepAlive: false,
                    fields: [
                      FormixFieldConfig<String>(
                        id: newsletterFrequencyField,
                        initialValue: 'weekly',
                      ),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Newsletter Frequency'),
                        const SizedBox(height: 8),
                        const FormixDropdownFormField<String>(
                          fieldId: newsletterFrequencyField,
                          items: [
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                          ],
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.schedule),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Contact Method
            const Text('Preferred Contact Method'),
            const SizedBox(height: 8),
            const FormixDropdownFormField<String>(
              key: ValueKey('contactMethodField'),
              fieldId: contactMethodField,
              items: [
                DropdownMenuItem(value: 'email', child: Text('Email')),
                DropdownMenuItem(value: 'phone', child: Text('Phone')),
                DropdownMenuItem(value: 'sms', child: Text('SMS')),
              ],
              decoration: InputDecoration(prefixIcon: Icon(Icons.contact_mail)),
            ),
            const SizedBox(height: 16),

            // Conditional Phone Number
            FormixBuilder(
              builder: (context, scope) {
                final contactMethod = scope.watchValue(contactMethodField);
                if (contactMethod == 'phone' || contactMethod == 'sms') {
                  // Dynamic fields dependent on contact method
                  final phoneFields = [
                    FormixFieldConfig<String>(
                      id: phoneNumberField,
                      initialValue: '',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                  ];

                  if (contactMethod == 'phone') {
                    phoneFields.add(
                      FormixFieldConfig<String>(
                        id: preferredTimeField,
                        initialValue: 'morning',
                      ),
                    );
                  }

                  return FormixSection(
                    key: ValueKey('contact_${contactMethod}_section'),
                    keepAlive: false,
                    fields: phoneFields,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FormixTextFormField(
                          fieldId: phoneNumberField,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Conditional Preferred Time (only for phone calls)
                        if (contactMethod == 'phone') ...[
                          const Text('Preferred Call Time'),
                          const SizedBox(height: 8),
                          const FormixDropdownFormField<String>(
                            fieldId: preferredTimeField,
                            items: [
                              DropdownMenuItem(
                                value: 'morning',
                                child: Text('Morning (9 AM - 12 PM)'),
                              ),
                              DropdownMenuItem(
                                value: 'afternoon',
                                child: Text('Afternoon (12 PM - 5 PM)'),
                              ),
                              DropdownMenuItem(
                                value: 'evening',
                                child: Text('Evening (5 PM - 9 PM)'),
                              ),
                            ],
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.access_time),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 24),
            const FormixFormStatus(),
            const SizedBox(height: 16),

            FormixBuilder(
              builder: (context, scope) {
                final controller = scope.controller;
                // Watch validity to trigger rebuilds
                scope.watchIsValid;

                return ElevatedButton(
                  onPressed: () {
                    // Try to validate first
                    if (controller.validate()) {
                      _showValues(context, controller.values);
                    } else {
                      // Validation failed, errors should show
                      debugPrint('Validation failed: ${controller.errors}');
                    }
                  },
                  child: const Text('Submit'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showValues(BuildContext context, Map<String, dynamic> values) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Form Values'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: values.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${entry.key}: ${entry.value}'),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
