import 'package:flutter/material.dart';
import 'package:formix/formix.dart';
import 'logging_analytics.dart';

/// A comprehensive example demonstrating a multi-step form with:
/// - 4 steps with independent validation
/// - GlobalKey for external control
/// - Step-by-step validation before proceeding
/// - Progress tracking and navigation
class MultiStepFormPage extends StatefulWidget {
  const MultiStepFormPage({super.key});

  @override
  State<MultiStepFormPage> createState() => _MultiStepFormPageState();
}

class _MultiStepFormPageState extends State<MultiStepFormPage> {
  // We no longer need local _currentStep state as it's managed by FormixController

  // GlobalKeys no longer needed as we use FormixFieldRegistry
  // final _step1Key = GlobalKey<FormixState>(); ...

  // Field IDs for Step 1: Personal Information
  final nameField = FormixFieldID<String>('name');
  final emailField = FormixFieldID<String>('email');
  final phoneField = FormixFieldID<String>('phone');

  // Field IDs for Step 2: Address
  final streetField = FormixFieldID<String>('street');
  final cityField = FormixFieldID<String>('city');
  final zipField = FormixFieldID<String>('zip');
  final countryField = FormixFieldID<String>('country');

  // Field IDs for Step 3: Employment
  final companyField = FormixFieldID<String>('company');
  final positionField = FormixFieldID<String>('position');
  final salaryField = FormixFieldID<num>('salary');

  // Field IDs for Step 4: Preferences
  final newsletterField = FormixFieldID<bool>('newsletter');
  final notificationsField = FormixFieldID<bool>('notifications');
  final commentsField = FormixFieldID<String>('comments');

  // Define fields ONCE to preserve provider state
  late final List<FormixFieldConfig> _step1Fields = [
    FormixFieldConfig<String>(
      id: nameField,
      label: 'Full Name',
      validator: (v) {
        if (v == null || v.isEmpty) return 'Name is required';
        if (v.length < 3) return 'Name must be at least 3 characters';
        return null;
      },
    ),
    FormixFieldConfig<String>(
      id: emailField,
      label: 'Email',
      validator: (v) {
        if (v == null || v.isEmpty) return 'Email is required';
        if (!v.contains('@')) return 'Invalid email format';
        return null;
      },
    ),
    FormixFieldConfig<String>(
      id: phoneField,
      label: 'Phone',
      validator: (v) {
        if (v == null || v.isEmpty) return 'Phone is required';
        if (v.length < 10) return 'Phone must be at least 10 digits';
        return null;
      },
    ),
  ];

  late final List<FormixFieldConfig> _step2Fields = [
    FormixFieldConfig<String>(
      id: streetField,
      validator: (v) => (v?.isEmpty ?? true) ? 'Street is required' : null,
    ),
    FormixFieldConfig<String>(
      id: cityField,
      validator: (v) => (v?.isEmpty ?? true) ? 'City is required' : null,
    ),
    FormixFieldConfig<String>(
      id: zipField,
      validator: (v) {
        if (v == null || v.isEmpty) return 'ZIP is required';
        if (v.length < 5) return 'ZIP must be at least 5 digits';
        return null;
      },
    ),
    FormixFieldConfig<String>(
      id: countryField,
      validator: (v) => (v?.isEmpty ?? true) ? 'Country is required' : null,
    ),
  ];

  late final List<FormixFieldConfig> _step3Fields = [
    FormixFieldConfig<String>(
      id: companyField,
      validator: (v) => (v?.isEmpty ?? true) ? 'Company is required' : null,
    ),
    FormixFieldConfig<String>(
      id: positionField,
      validator: (v) => (v?.isEmpty ?? true) ? 'Position is required' : null,
    ),
    FormixFieldConfig<num>(
      id: salaryField,
      validator: (v) {
        if ((v ?? 0) <= 0) return 'Salary must be greater than 0';
        return null;
      },
    ),
  ];

  late final List<FormixFieldConfig> _step4Fields = [
    FormixFieldConfig<String>(
      id: commentsField,
      validator: (v) {
        if (v != null && v.isNotEmpty && v.length < 10) {
          return 'Comments must be at least 10 characters';
        }
        return null;
      },
    ),
  ];

  // Removed GlobalKey logic as we now use a single shared Formix state

  // No longer needed
  // Map<String, dynamic> _getStepData(int step) ...

  void _onStepContinue(FormixScope scope) {
    final currentStep = scope.watchCurrentStep;
    final List<FormixFieldConfig> currentFields;

    switch (currentStep) {
      case 0:
        currentFields = _step1Fields;
        break;
      case 1:
        currentFields = _step2Fields;
        break;
      case 2:
        currentFields = _step3Fields;
        break;
      default:
        currentFields = _step4Fields;
    }

    if (currentStep < 3) {
      final success = scope.nextStep(
        fields: currentFields.map((f) => f.id).toList(),
      );
      if (!success) {
        _showErrorSnackBar();
      }
    } else {
      if (scope.validate()) {
        _submitForm(scope);
      } else {
        _showErrorSnackBar();
      }
    }
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fix validation errors before continuing'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _onStepCancel(FormixScope scope) {
    scope.previousStep();
  }

  void _submitForm(FormixScope scope) {
    // With preserving state, scope.values contains EVERYTHING, even from unmounted steps!
    final allData = scope.values;
    debugPrint('All collected data: $allData');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Form Submitted! 🎉'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'All data collected:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...allData.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${e.key}: ${e.value}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              scope.reset(); // Reset the form
              scope.goToStep(0);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Step Registration'),
        elevation: 2,
      ),
      body: Formix(
        formId: 'multi_step_wizard', // ID required for analytics tracking
        analytics: const LoggingFormixAnalytics(),
        initialValue: const {'newsletter': false, 'notifications': true},
        child: FormixBuilder(
          select: (state) => Object.hash(state.currentStep, state.isValid),
          builder: (context, scope) {
            final currentStep = scope.watchCurrentStep;

            return Column(
              children: [
                // Step indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: currentStep >= index
                                ? Colors.blue
                                : Colors.grey.shade300,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: currentStep >= index
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (index < 3)
                            Container(
                              width: 40,
                              height: 2,
                              color: currentStep > index
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                // Step titles
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    [
                      'Personal Information',
                      'Address',
                      'Employment',
                      'Preferences',
                    ][currentStep],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                // Active Step (Lazy Loaded)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      switch (currentStep) {
                        case 0:
                          return SingleChildScrollView(
                            key: const ValueKey(0),
                            child: _buildStep1(),
                          );
                        case 1:
                          return SingleChildScrollView(
                            key: const ValueKey(1),
                            child: _buildStep2(),
                          );
                        case 2:
                          return SingleChildScrollView(
                            key: const ValueKey(2),
                            child: _buildStep3(),
                          );
                        case 3:
                          return SingleChildScrollView(
                            key: const ValueKey(3),
                            child: _buildStep4(),
                          );
                        default:
                          return const SizedBox();
                      }
                    },
                  ),
                ),
                // Navigation buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (currentStep > 0)
                        TextButton(
                          key: const Key('back_button'),
                          onPressed: () => _onStepCancel(scope),
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox.shrink(),

                      ElevatedButton(
                        key: const Key('continue_button'),
                        onPressed: () => _onStepContinue(scope),
                        child: Text(currentStep == 3 ? 'Submit' : 'Continue'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return FormixFieldRegistry(
      fields: _step1Fields,
      // Default is true, but explicit here for clarity:
      // Preserves data even when this widget unmounts (next step)
      preserveStateOnDispose: true,
      child: Column(
        children: [
          FormixTextFormField(
            key: const Key('name_field'),
            fieldId: nameField,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormixTextFormField(
            fieldId: emailField,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormixTextFormField(
            fieldId: phoneField,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormixBuilder(
            builder: (context, scope) {
              final isValid = scope.watchIsValid;
              return Card(
                color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        isValid ? Icons.check_circle : Icons.info,
                        color: isValid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isValid
                              ? 'All fields are valid!'
                              : 'Please fill all required fields',
                          style: TextStyle(
                            color: isValid
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return FormixFieldRegistry(
      fields: _step2Fields,
      preserveStateOnDispose: true,
      child: Column(
        children: [
          FormixTextFormField(
            key: const Key('street_field'),
            fieldId: streetField,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FormixTextFormField(
                  fieldId: cityField,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FormixTextFormField(
                  fieldId: zipField,
                  decoration: const InputDecoration(
                    labelText: 'ZIP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FormixTextFormField(
            fieldId: countryField,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.flag),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return FormixFieldRegistry(
      fields: _step3Fields,
      preserveStateOnDispose: true,
      child: Column(
        children: [
          FormixTextFormField(
            fieldId: companyField,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormixTextFormField(
            fieldId: positionField,
            decoration: const InputDecoration(
              labelText: 'Position',
              prefixIcon: Icon(Icons.work),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FormixNumberFormField(
            fieldId: salaryField,
            decoration: const InputDecoration(
              labelText: 'Annual Salary',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
              helperText: 'Enter your expected annual salary',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return FormixFieldRegistry(
      fields: _step4Fields,
      preserveStateOnDispose: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Communication Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          FormixBuilder(
            builder: (context, scope) {
              final newsletter = scope.watchValue(newsletterField) ?? false;
              return SwitchListTile(
                title: const Text('Subscribe to Newsletter'),
                subtitle: const Text('Receive weekly updates'),
                value: newsletter,
                onChanged: (v) => scope.setValue(newsletterField, v),
              );
            },
          ),
          FormixBuilder(
            builder: (context, scope) {
              final notifications =
                  scope.watchValue(notificationsField) ?? true;
              return SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Get notified about important updates'),
                value: notifications,
                onChanged: (v) => scope.setValue(notificationsField, v),
              );
            },
          ),
          const SizedBox(height: 16),
          FormixTextFormField(
            key: const Key('comments_field'),
            fieldId: commentsField,
            decoration: const InputDecoration(
              labelText: 'Additional Comments (Optional)',
              border: OutlineInputBorder(),
              hintText: 'Any additional information...',
            ),
          ),
          const SizedBox(height: 16),
          FormixBuilder(
            builder: (context, scope) {
              // Now inspecting global form dirtiness
              final isDirty = scope.watchIsFormDirty;
              if (isDirty) {
                return const Card(
                  color: Colors.blue,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You have unsaved changes',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
