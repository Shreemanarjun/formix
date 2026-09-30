import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

class AsyncFieldSubmissionPage extends StatelessWidget {
  const AsyncFieldSubmissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Async Field & Submission')),
      body: const AsyncFieldSubmissionContent(),
    );
  }
}

class AsyncFieldSubmissionContent extends StatefulWidget {
  const AsyncFieldSubmissionContent({super.key});

  @override
  State<AsyncFieldSubmissionContent> createState() =>
      _AsyncFieldSubmissionContentState();
}

class _AsyncFieldSubmissionContentState
    extends State<AsyncFieldSubmissionContent> {
  final countryField = const FormixFieldID<String>('country');
  final cityField = const FormixFieldID<String>('city');
  final cityOptionsField = const FormixFieldID<List<String>>('cityOptions');
  final nameField = const FormixFieldID<String>('name');
  final usernameField = const FormixFieldID<String>('username');

  // Simulated API
  Future<List<String>> fetchCities(String? country) async {
    if (country == null || country.isEmpty) return [];
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    if (country == 'USA') return ['New York', 'Los Angeles', 'Chicago'];
    if (country == 'India') return ['Mumbai', 'Delhi', 'Bangalore'];
    if (country == 'UK') return ['London', 'Manchester', 'Birmingham'];
    return ['Other'];
  }

  // Simulated Username check
  Future<String?> checkUsername(String? username) async {
    if (username == null || username.isEmpty) return null;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (username.toLowerCase() == 'admin' || username.toLowerCase() == 'root') {
      return 'Username already taken';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Formix(
      fields: [
        FormixFieldConfig<String>(
          id: nameField,
          validator: (value) =>
              value == null || value.isEmpty ? 'Required' : null,
        ),
        FormixFieldConfig<String>(
          id: usernameField,
          validator: (value) =>
              value == null || value.isEmpty ? 'Required' : null,
          asyncValidator: checkUsername,
        ),
        FormixFieldConfig<String>(id: countryField, initialValue: 'USA'),
        FormixFieldConfig<String>(
          id: cityField,
          validator: (value) =>
              value == null || value.isEmpty ? 'Select a city' : null,
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Async Form Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'This demo shows Formix waiting for async fields and validators before submission.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            FormixTextFormField(
              fieldId: nameField,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            FormixTextFormField(
              fieldId: usernameField,
              decoration: InputDecoration(
                labelText: 'Username',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.alternate_email),
                helperText:
                    'Try "admin" or "root" to see async validation error',
                suffix: FormixBuilder(
                  builder: (context, scope) {
                    final isValidating = scope.watchIsValidating(usernameField);
                    if (isValidating) {
                      return const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            FormixDropdownFormField<String>(
              fieldId: countryField,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.public),
              ),
              items: const [
                DropdownMenuItem(value: 'USA', child: Text('USA')),
                DropdownMenuItem(value: 'India', child: Text('India')),
                DropdownMenuItem(value: 'UK', child: Text('UK')),
              ],
            ),
            const SizedBox(height: 16),

            // Use FormixAsyncField to fetch cities when country changes
            // Use FormixDependentAsyncField to fetch cities when country changes
            FormixDependentAsyncField<List<String>, String>(
              fieldId: cityOptionsField,
              dependency: countryField,
              resetField: cityField,
              // The future is re-triggered automatically if dependencies in the closure change
              future: (country) => fetchCities(country),
              keepPreviousData: true,
              onData: (context, controller, cities) {
                // Auto-select first city if none selected
                if (cities.isNotEmpty &&
                    controller.getValue(cityField) == null) {
                  controller.setValue(cityField, cities.first);
                }
              },
              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(),
              ),
              builder: (context, state) {
                final cities = state.asyncState.value ?? [];
                return FormixDropdownFormField<String>(
                  fieldId: cityField,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  items: cities
                      .map(
                        (city) =>
                            DropdownMenuItem(value: city, child: Text(city)),
                      )
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 32),

            const FormixFormStatus(),
            const SizedBox(height: 24),

            FormixBuilder(
              builder: (context, scope) {
                final controller = scope.controller;
                final formState = scope.watchState;

                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // The new submit() automatically waits for:
                          // 1. Any async validators currently running (e.g. Username check)
                          // 2. Any async fields currently pending (e.g. City fetch)
                          controller.submit(
                            onValid: (values) async {
                              // Simulate final API call
                              await Future.delayed(const Duration(seconds: 2));

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                      'Success! Final values: $values',
                                    ),
                                  ),
                                );
                              }
                            },
                            onError: (errors) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text(
                                    'Please fix the errors in the form',
                                  ),
                                ),
                              );
                            },
                            autoFocusOnInvalid: true,
                          );
                        },
                        child: formState.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit (Waits for Pending)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => controller.reset(),
                        child: const Text('Reset Form (Re-triggers Async)'),
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
