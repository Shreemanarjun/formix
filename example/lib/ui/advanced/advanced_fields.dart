import 'package:formix/formix.dart';
import '../../constants/field_ids.dart';

// ── Field Validators (Top-level functions allow for 'const' configs) ─────────

String? _validateName(String? value) {
  if (value == null || value.isEmpty) return 'Name is required';
  if (value.length < 2) return 'Name must be at least 2 characters';
  return null;
}

String? _validateEmail(String? value) {
  if (value == null || value.isEmpty) return 'Email is required';
  // Note: RegExp is NOT constant, so we create it inside the non-constant validator function.
  // Validation logic remains isolated for testing.
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
    return 'Invalid email format';
  }
  return null;
}

String? _validateAge(int? value) {
  if (value == null) return null;
  if (value < 13) return 'Must be at least 13 years old';
  if (value > 120) return 'Age must be realistic';
  return null;
}

String? _validateBio(String? value) {
  if (value != null && value.length > 500) {
    return 'Bio must be less than 500 characters';
  }
  return null;
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Password must be at least 8 characters';
  return null;
}

String? _crossValidateConfirmPassword(String? value, FormixData state) {
  final password = state.getValue(passwordField);
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != password) {
    return 'Passwords do not match';
  }
  return null;
}

// ── Constant Field Configs ───────────────────────────────────────────────────

const advancedNameConfig = FormixFieldConfig<String>(
  id: nameField,
  validator: _validateName,
);

const advancedEmailConfig = FormixFieldConfig<String>(
  id: emailField,
  validator: _validateEmail,
);

const advancedAgeConfig = FormixFieldConfig<int>(
  id: ageField,
  validator: _validateAge,
);

const advancedNewsletterConfig = FormixFieldConfig<bool>(id: newsletterField);

const advancedCountryConfig = FormixFieldConfig<String>(
  id: countryField,
  initialValue: 'US',
);

const advancedBioConfig = FormixFieldConfig<String>(
  id: bioField,
  validator: _validateBio,
);

const advancedPasswordConfig = FormixFieldConfig<String>(
  id: passwordField,
  validator: _validatePassword,
);

const advancedConfirmPasswordConfig = FormixFieldConfig<String>(
  id: confirmPasswordField,
  dependsOn: [passwordField],
  crossFieldValidator: _crossValidateConfirmPassword,
);

// ── Field List ───────────────────────────────────────────────────────────────

/// Explicitly typed constant list of advanced field configurations.
const List<FormixFieldConfig<dynamic>> advancedFieldConfigs = [
  advancedNameConfig,
  advancedEmailConfig,
  advancedAgeConfig,
  advancedNewsletterConfig,
  advancedCountryConfig,
  advancedBioConfig,
  advancedPasswordConfig,
  advancedConfirmPasswordConfig,
];
