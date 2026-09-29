import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

const usernameField = FormixFieldID<String>('username');
const passwordField = FormixFieldID<String>('password');

/// Test page demonstrating proper FormixBuilder usage without infinite loops
class FormixBuilderTestPage extends StatefulWidget {
  const FormixBuilderTestPage({super.key});

  @override
  State<FormixBuilderTestPage> createState() => _FormixBuilderTestPageState();
}

class _FormixBuilderTestPageState extends State<FormixBuilderTestPage> {
  final formKey = GlobalKey<FormixState>();
  bool _isPasswordVisible = false;

  /// CORRECT: Use FormixScope for form operations
  /// This prevents accessing the controller during build phase
  Future<void> _loginUser(FormixScope scope) async {
    // Validate using scope
    if (!scope.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Validation failed')));
      return;
    }

    // Get values from scope (non-reactive)
    final values = scope.values;
    final username = values[usernameField.key];
    final password = values[passwordField.key];

    // Simulate login
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login successful!\nUsername: $username\nPassword: $password',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FormixBuilder Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Formix(
          key: formKey,
          fields: [
            FormixFieldConfig<String>(
              id: usernameField,
              initialValue: "test_user",
              validator: FormixValidators.string()
                  .required('Enter Username')
                  .minLength(3, 'Username must be at least 3 characters')
                  .build(),
              label: 'Username',
              hint: 'Enter your username',
            ),
            FormixFieldConfig<String>(
              id: passwordField,
              initialValue: "test@1234",
              validator: FormixValidators.string()
                  .required('Enter Password')
                  .minLength(6, 'Password must be at least 6 characters')
                  .build(),
              label: 'Password',
              hint: 'Enter your password',
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Username Field - Simple approach
              FormixBuilder(
                builder: (context, scope) {
                  final value = scope.watchValue(usernameField);
                  final error = scope.watchError(usernameField);
                  final isValidating = scope.watchIsValidating(usernameField);

                  return TextFormField(
                    initialValue: value,
                    onChanged: (newValue) =>
                        scope.setValue(usernameField, newValue),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter your username',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                      errorText: error,
                      suffixIcon: isValidating
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Password Field - With visibility toggle
              FormixBuilder(
                builder: (context, scope) {
                  final value = scope.watchValue(passwordField);
                  final error = scope.watchError(passwordField);
                  final isValidating = scope.watchIsValidating(passwordField);

                  return TextFormField(
                    initialValue: value,
                    obscureText: !_isPasswordVisible,
                    onChanged: (newValue) =>
                        scope.setValue(passwordField, newValue),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      errorText: error,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isValidating)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // SOLUTION 1: Login Button - Using FormixBuilder with scope
              // This is the CORRECT way - pass scope to the callback
              FormixBuilder(
                builder: (context, scope) {
                  final isSubmitting = scope.watchIsSubmitting;
                  final isValid = scope.watchIsValid;

                  return ElevatedButton(
                    onPressed: (isValid && !isSubmitting)
                        ? () => _loginUser(scope)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Login (Using Scope)",
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // SOLUTION 2: Login Button - Using scope.submit helper
              // This is even BETTER - uses built-in submit functionality
              FormixBuilder(
                builder: (context, scope) {
                  final isSubmitting = scope.watchIsSubmitting;

                  return ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => scope.submit(
                            onValid: (values) async {
                              // Capture context before async operation
                              final messenger = ScaffoldMessenger.of(context);
                              // Simulate login
                              await Future.delayed(const Duration(seconds: 2));

                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Login successful!\n'
                                      'Username: ${values[usernameField.key]}\n'
                                      'Password: ${values[passwordField.key]}',
                                    ),
                                  ),
                                );
                              }
                            },
                            onError: (errors) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Validation failed'),
                                ),
                              );
                            },
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Login (Using Submit Helper)",
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Form Status Display
              FormixBuilder(
                builder: (context, scope) {
                  final isValid = scope.watchIsValid;
                  final isDirty = scope.watchIsFormDirty;
                  final isSubmitting = scope.watchIsSubmitting;

                  return Card(
                    color: Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Form Status:',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _StatusRow(label: 'Valid', value: isValid),
                          _StatusRow(label: 'Dirty', value: isDirty),
                          _StatusRow(label: 'Submitting', value: isSubmitting),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            value.toString(),
            style: TextStyle(
              color: value ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
