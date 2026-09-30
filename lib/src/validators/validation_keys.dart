/// Keys used for standard validation errors to support internationalization.
class FormixValidationKeys {
  /// Error key for a required field.
  static const String required = 'formix_key_required';

  /// Error key for an invalid format.
  static const String invalidFormat = 'formix_key_invalid_format';

  /// Error key for an invalid email address.
  static const String invalidEmail = 'formix_key_invalid_email';

  /// Error key for a string that is too short.
  static const String minLength = 'formix_key_min_length';

  /// Error key for a string that is too long.
  static const String maxLength = 'formix_key_max_length';

  /// Error key for a numeric value that is too small.
  static const String min = 'formix_key_min';

  /// Error key for a numeric value that is too large.
  static const String max = 'formix_key_max';

  /// Error key for a date that is before the allowed minimum.
  static const String minDate = 'formix_key_min_date';

  /// Error key for a date that is after the allowed maximum.
  static const String maxDate = 'formix_key_max_date';

  /// Error key for a value that is not one of the allowed options.
  static const String invalidSelection = 'formix_key_invalid_selection';

  // Helper to encode params into the key string if needed,
  // though simple string concatenation with separator might suffice.
  /// Encodes a parameter into a validation key string.
  static String withParam(String key, dynamic param) => '$key:$param';
}
