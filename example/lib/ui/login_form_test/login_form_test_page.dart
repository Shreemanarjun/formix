import 'package:flutter/material.dart';
import 'package:formix/formix.dart';

const usernameField = FormixFieldID<String>('username');
const passwordField = FormixFieldID<String>('password');

class LoginFormTestPage extends StatefulWidget {
  const LoginFormTestPage({super.key});

  @override
  State<LoginFormTestPage> createState() => _LoginFormTestPageState();
}

class _LoginFormTestPageState extends State<LoginFormTestPage> {
  final formKey = GlobalKey<FormixState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _loginUser() async {
    final controller = formKey.currentState?.controller;
    if (controller == null || !controller.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Validation failed')));
      return;
    }

    // Get values before async operation to avoid accessing disposed controller
    final username = controller.getValue(usernameField);
    final password = controller.getValue(passwordField);

    setState(() {
      _isLoading = true;
    });

    // Simulate login
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

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
      appBar: AppBar(title: const Text('Login Form Test')),
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
                  .build(),
              label: 'Username',
              hint: 'Enter your username',
            ),
            FormixFieldConfig<String>(
              id: passwordField,
              initialValue: "test@1234",
              validator: FormixValidators.string()
                  .required('Enter Password')
                  .build(),
              label: 'Password',
              hint: 'Enter your password',
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Username Field
              FormixTextFormField(
                fieldId: usernameField,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              // Password Field - Using FormixBuilder for custom obscureText control
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
              const SizedBox(height: 18),
              // Login Button
              FormixBuilder(
                builder: (context, scope) => ElevatedButton(
                  onPressed: _isLoading ? null : _loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Login", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 18),
              // Sign up link
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigate to signup')),
                    );
                  },
                  child: const Text(
                    "Sign up as a new Patient",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
