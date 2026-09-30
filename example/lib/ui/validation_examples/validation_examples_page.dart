import 'package:flutter/material.dart';
import 'package:formix/formix.dart';
import 'validation_fields.dart';

// Validation Examples
class ValidationExamples extends StatelessWidget {
  const ValidationExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return const ValidationExamplesContent();
  }
}

class ValidationExamplesContent extends StatefulWidget {
  const ValidationExamplesContent({super.key});

  @override
  State<ValidationExamplesContent> createState() =>
      _ValidationExamplesContentState();
}

class _ValidationExamplesContentState extends State<ValidationExamplesContent> {
  @override
  Widget build(BuildContext context) {
    return Formix(
      formId: 'validation_examples',
      initialValue: const {
        'email': '',
        'password': '',
        'confirmPassword': '',
        'age': 18,
        'phone': '',
        'url': '',
        'creditCard': '',
        'zipCode': '',
        'username': '',
        'bio': '',
      },
      fields: [
        validationEmailConfig,
        validationPasswordConfig,
        confirmPasswordConfig,
        validationAgeConfig,
        validationPhoneConfig,
        validationUrlConfig,
        validationCreditCardConfig,
        validationZipCodeConfig,
        validationUsernameConfig,
        validationBioConfig,
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Validation Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Different types of validation rules and error messages',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Email Validation
            const Text(
              'Email Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationEmailId,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            // Password Validation
            const Text(
              'Password Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationPasswordId,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText:
                    'At least 8 chars, with uppercase, lowercase & number',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            FormixTextFormField(
              fieldId: validationConfirmPasswordId,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Age Validation
            const Text(
              'Numeric Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixNumberFormField(
              fieldId: validationAgeId,
              min: 0,
              max: 150,
              decoration: const InputDecoration(
                labelText: 'Age',
                hintText: '13-120 years',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Validation
            const Text(
              'Phone Number Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationPhoneId,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+1 (555) 123-4567',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // URL Validation
            const Text(
              'URL Validation (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationUrlId,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website URL',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),

            // Credit Card Validation
            const Text(
              'Credit Card Validation (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationCreditCardId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Credit Card Number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 16),

            // ZIP Code Validation
            const Text(
              'ZIP Code Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationZipCodeId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ZIP Code',
                hintText: '12345 or 12345-6789',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Username Validation
            const Text(
              'Username Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationUsernameId,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: '3-20 characters, letters/numbers/underscores',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Bio Validation (Length)
            const Text(
              'Text Length Validation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: validationBioId,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself (max 500 characters)',
                prefixIcon: Icon(Icons.text_fields),
              ),
            ),
            const SizedBox(height: 24),

            const FormixFormStatus(),
            const SizedBox(height: 16),

            FormixBuilder(
              builder: (context, scope) {
                return ElevatedButton(
                  onPressed: () {
                    final isValid = scope.validate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isValid
                              ? 'All validations passed! ${scope.controller.errors}'
                              : 'Some fields have errors',
                        ),
                        backgroundColor: isValid ? Colors.green : Colors.red,
                      ),
                    );
                  },
                  child: const Text('Validate Form'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
