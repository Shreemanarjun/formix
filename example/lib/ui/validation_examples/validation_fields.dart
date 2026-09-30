import 'package:formix/formix.dart';

// ── Field IDs ────────────────────────────────────────────────────────────────

const validationEmailId = FormixFieldID<String>('email');
const validationPasswordId = FormixFieldID<String>('password');
const validationConfirmPasswordId = FormixFieldID<String>('confirmPassword');
const validationAgeId = FormixFieldID<num>('age');
const validationPhoneId = FormixFieldID<String>('phone');
const validationUrlId = FormixFieldID<String>('url');
const validationCreditCardId = FormixFieldID<String>('creditCard');
const validationZipCodeId = FormixFieldID<String>('zipCode');
const validationUsernameId = FormixFieldID<String>('username');
const validationBioId = FormixFieldID<String>('bio');

// ── Static field configs (validators that don't need BuildContext) ─────────────

final validationEmailConfig = FormixFieldConfig<String>(
  id: validationEmailId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(value!)) return 'Invalid email format';
    return null;
  },
);

final validationPasswordConfig = FormixFieldConfig<String>(
  id: validationPasswordId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Password is required';
    if (value!.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
      return 'Password must contain lowercase letter';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
      return 'Password must contain uppercase letter';
    }
    if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
      return 'Password must contain number';
    }
    return null;
  },
);

/// The confirmPassword field config using [FormixFieldConfig.crossFieldValidator]
/// so it can read the *password* field from the full [FormixData] state.
///
/// `dependsOn: [validationPasswordId]` tells Formix to re-run this
/// validator whenever the password field value changes, keeping the
/// confirmPassword error in sync as the user types.
///
/// ## Why not capture a BuildContext?
///
/// The `fields:` list is evaluated in the **parent** widget's build method,
/// whose `BuildContext` is an *ancestor* of [Formix]. Calling
/// `Formix.controllerOf(context)` from that context searches **upward**
/// via `dependOnInheritedWidgetOfExactType<_FormixScope>()`, but
/// `_FormixScope` is placed *inside* Formix's subtree — so the lookup
/// always returns `null`, `password` is always `null`, and validation
/// always fails even for matching inputs.
final confirmPasswordConfig = FormixFieldConfig<String>(
  id: validationConfirmPasswordId,
  initialValue: '',
  dependsOn: [validationPasswordId],
  crossFieldValidator: (value, state) {
    final password = state.getValue(validationPasswordId);
    if (value?.isEmpty ?? true) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  },
);

final validationAgeConfig = FormixFieldConfig<num>(
  id: validationAgeId,
  initialValue: 18,
  validator: (value) {
    if ((value ?? 0) < 13) return 'Must be at least 13 years old';
    if ((value ?? 0) > 120) return 'Age must be realistic';
    return null;
  },
);

final validationPhoneConfig = FormixFieldConfig<String>(
  id: validationPhoneId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Phone number is required';
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value!)) return 'Invalid phone number format';
    return null;
  },
);

final validationUrlConfig = FormixFieldConfig<String>(
  id: validationUrlId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return null; // Optional field
    final urlRegex = RegExp(r'^https?://[^\s/$.?#].[^\s]*$');
    if (!urlRegex.hasMatch(value!)) return 'Invalid URL format';
    return null;
  },
);

final validationCreditCardConfig = FormixFieldConfig<String>(
  id: validationCreditCardId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return null; // Optional field
    final cleanValue = value!.replaceAll(RegExp(r'\s+'), '');
    if (cleanValue.length < 13 || cleanValue.length > 19) {
      return 'Invalid credit card number length';
    }
    if (!RegExp(r'^\d+$').hasMatch(cleanValue)) {
      return 'Credit card must contain only digits';
    }
    if (!_isValidLuhn(cleanValue)) return 'Invalid credit card number';
    return null;
  },
);

final validationZipCodeConfig = FormixFieldConfig<String>(
  id: validationZipCodeId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return 'ZIP code is required';
    final zipRegex = RegExp(r'^\d{5}(-\d{4})?$');
    if (!zipRegex.hasMatch(value!)) {
      return 'Invalid ZIP code format (12345 or 12345-6789)';
    }
    return null;
  },
);

final validationUsernameConfig = FormixFieldConfig<String>(
  id: validationUsernameId,
  initialValue: '',
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Username is required';
    if (value!.length < 3) return 'Username must be at least 3 characters';
    if (value.length > 20) return 'Username must be less than 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  },
);

final validationBioConfig = FormixFieldConfig<String>(
  id: validationBioId,
  initialValue: '',
  validator: (value) {
    if ((value?.length ?? 0) > 500) {
      return 'Bio must be less than 500 characters';
    }
    return null;
  },
);

// ── Luhn algorithm (shared utility) ──────────────────────────────────────────

bool _isValidLuhn(String number) {
  int sum = 0;
  bool alternate = false;
  for (int i = number.length - 1; i >= 0; i--) {
    int digit = int.parse(number[i]);
    if (alternate) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    alternate = !alternate;
  }
  return sum % 10 == 0;
}
