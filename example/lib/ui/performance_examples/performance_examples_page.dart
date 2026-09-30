import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

// Performance Examples
class PerformanceExamples extends StatelessWidget {
  const PerformanceExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformanceExamplesContent();
  }
}

class PerformanceExamplesContent extends StatefulWidget {
  const PerformanceExamplesContent({super.key});

  @override
  State<PerformanceExamplesContent> createState() =>
      _PerformanceExamplesContentState();
}

class _PerformanceExamplesContentState
    extends State<PerformanceExamplesContent> {
  @override
  Widget build(BuildContext context) {
    return Formix(
      initialValue: {
        'firstName': '',
        'lastName': '',
        'email': '',
        'age': 25,
        'newsletter': false,
        'country': 'US',
      },
      fields: [
        FormixFieldConfig<String>(
          id: FormixFieldID<String>('firstName'),
          initialValue: '',
        ),
        FormixFieldConfig<String>(
          id: FormixFieldID<String>('lastName'),
          initialValue: '',
        ),
        FormixFieldConfig<String>(
          id: FormixFieldID<String>('email'),
          initialValue: '',
        ),
        FormixFieldConfig<num>(id: FormixFieldID<num>('age'), initialValue: 25),
        FormixFieldConfig<bool>(
          id: FormixFieldID<bool>('newsletter'),
          initialValue: false,
        ),
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
              'Performance Examples',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Optimized widgets that rebuild only when necessary',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Performance Monitor
            const Text(
              'Rebuild Counter (Field Selector)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixFieldPerformanceMonitor<String>(
              fieldId: FormixFieldID<String>('firstName'),
              builder: (context, info, rebuildCount) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First Name: ${info.value ?? 'Not set'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rebuilds: $rebuildCount',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Optimized Field Selector (value only)
            const Text(
              'Value-Only Selector (Minimal Rebuilds)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixFieldValueSelector<String>(
              fieldId: FormixFieldID<String>('lastName'),
              builder: (context, value, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Last Name: ${value ?? 'Not set'}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Conditional Selector
            const Text(
              'Conditional Selector (Smart Rebuilds)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixFieldConditionalSelector<bool>(
              fieldId: FormixFieldID<bool>('newsletter'),
              shouldRebuild: (info) =>
                  info.valueChanged, // Only rebuild on value changes
              builder: (context, info, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (info.value ?? false)
                        ? Colors.purple.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (info.value ?? false)
                          ? Colors.purple.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (info.value ?? false)
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: (info.value ?? false)
                            ? Colors.purple
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Newsletter: ${(info.value ?? false) ? 'Subscribed' : 'Not subscribed'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Form Fields
            const Text(
              'Form Fields (Standard Widgets)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FormixTextFormField(
              fieldId: FormixFieldID<String>('firstName'),
              decoration: const InputDecoration(
                labelText: 'First Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            FormixTextFormField(
              fieldId: FormixFieldID<String>('lastName'),
              decoration: const InputDecoration(
                labelText: 'Last Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            FormixTextFormField(
              fieldId: FormixFieldID<String>('email'),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            FormixNumberFormField(
              fieldId: FormixFieldID<num>('age'),
              decoration: const InputDecoration(
                labelText: 'Age',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            FormixCheckboxFormField(
              fieldId: FormixFieldID<bool>('newsletter'),
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
              ],
              decoration: const InputDecoration(
                labelText: 'Country',
                prefixIcon: Icon(Icons.flag),
              ),
            ),

            const SizedBox(height: 24),
            const FormixFormStatus(),
            const SizedBox(height: 16),

            FormixBuilder(
              builder: (context, scope) {
                final formState = scope.watchState;

                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final values = formState.values;
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
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
                      },
                      child: const Text('Show Form Values'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: Notice how the performance monitors only rebuild when their specific fields change!',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
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
