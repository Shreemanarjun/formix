import 'package:signals_flutter/signals_flutter.dart';

// Localization exports
export 'i18n/formix_localizations.dart';
export 'i18n/messages_de.dart';
export 'i18n/messages_es.dart';
export 'i18n/messages_fr.dart';
export 'i18n/messages_hi.dart';
export 'i18n/messages_zh.dart';

/// The global, reactive validation messages used by every form that does not
/// override them via `Formix(messages: ...)` or `FormixController(messages: ...)`.
///
/// Set `formixGlobalMessages.value = MyLocalizedMessages()` (e.g. on a language
/// change) and all forms watching it will re-validate with the new copy.
final Signal<FormixMessages> formixGlobalMessages = signal(
  const DefaultFormixMessages(),
  options: const SignalOptions(name: 'formixGlobalMessages'),
);

/// Interface for all validation messages used in the formix library.
/// Developers can implement this class to provide translations.
abstract class FormixMessages {
  /// Creates a [FormixMessages].
  const FormixMessages();

  /// Default error message for required fields
  String required(String label);

  /// Default error message for invalid format (pattern)
  String invalidFormat();

  /// Error for min length validation
  String minLength(String label, int minLength);

  /// Error for max length validation
  String maxLength(String label, int maxLength);

  /// Error for min value validation
  String minValue(String label, num min);

  /// Error for max value validation
  String maxValue(String label, num max);

  /// Error for min date validation
  String minDate(String label, DateTime minDate);

  /// Error for max date validation
  String maxDate(String label, DateTime maxDate);

  /// Error for invalid selection
  String invalidSelection(String label);

  /// Error message when async validation fails unexpectedly
  String validationFailed(String error);

  /// Helper text when async validation is in progress
  String validating();

  /// Resolve a template string with placeholders.
  /// Example: format('{label} must be {min}', {'label': 'Age', 'min': 18})
  String format(String template, Map<String, dynamic> params) {
    var result = template;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}

/// Default implementation of [FormixMessages] in English.
class DefaultFormixMessages extends FormixMessages {
  /// Creates a [DefaultFormixMessages].
  const DefaultFormixMessages();

  @override
  String required(String label) => '$label is required';

  @override
  String invalidFormat() => 'Invalid format';

  @override
  String minLength(String label, int minLength) => '$label must be at least $minLength characters';

  @override
  String maxLength(String label, int maxLength) => '$label must be at most $maxLength characters';

  @override
  String minValue(String label, num min) => '$label must be at least $min';

  @override
  String maxValue(String label, num max) => '$label must be at most $max';

  @override
  String minDate(String label, DateTime minDate) => '$label must be after ${minDate.toString().split(' ')[0]}';

  @override
  String maxDate(String label, DateTime maxDate) => '$label must be before ${maxDate.toString().split(' ')[0]}';

  @override
  String invalidSelection(String label) => 'Invalid selection for $label';

  @override
  String validationFailed(String error) => 'Validation failed: $error';

  @override
  String validating() => 'Validating...';
}
