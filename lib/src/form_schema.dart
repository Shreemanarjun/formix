import 'dart:async';
import 'i18n.dart';
import 'enums.dart';

import 'package:flutter/material.dart';

import 'controllers/formix_base_controller.dart';
import 'controllers/field_id.dart';
import 'controllers/field.dart';
import 'controllers/validation.dart';

/// Base class for form field schemas with type safety
abstract class FormFieldSchema<T> {
  /// Creates a [FormFieldSchema].
  const FormFieldSchema({
    required this.id,
    required this.initialValue,
    this.validator,
    this.asyncValidator,
    this.label,
    this.hint,
    this.isRequired = false,
    this.isVisible = true,
    this.dependencies = const [],
    this.debounceDuration,
    this.builder,
    this.transformer,
    this.stateValidator,
    this.emptyValue,
  });

  /// Unique identifier for the field
  final FormixFieldID<T> id;

  /// Initial value for the field
  final T initialValue;

  /// Synchronous validator
  final String? Function(T? value)? validator;

  /// Validator with access to full form state (for cross-field validation)
  final String? Function(T? value, Map<String, dynamic> values)? stateValidator;

  /// Asynchronous validator
  final Future<String?> Function(T? value)? asyncValidator;

  /// Debounce duration for async validation
  final Duration? debounceDuration;

  /// Custom widget builder
  final Widget Function(
    BuildContext context,
    FormixController controller,
    FormixField<T> field,
  )?
  builder;

  /// Input transformer
  final T Function(dynamic value)? transformer;

  /// Value used when clearing the field
  final T? emptyValue;

  /// Display label
  final String? label;

  /// Display hint
  final String? hint;

  /// Whether the field is required
  final bool isRequired;

  /// Whether the field is currently visible
  final bool isVisible;

  /// Fields that this field depends on for visibility/validation
  final List<FormixFieldID<dynamic>> dependencies;

  /// Create the actual field definition
  FormixField<T> toFieldDefinition() {
    return FormixField<T>(
      id: id,
      initialValue: initialValue,
      validator: validator,
      asyncValidator: asyncValidator,
      debounceDuration: debounceDuration,
      label: label,
      hint: hint,
      transformer: transformer,
      emptyValue: emptyValue,
    );
  }

  /// Check if this field should be visible based on form state
  bool shouldBeVisible(Map<String, dynamic> formState) {
    return isVisible;
  }

  /// Get validation errors for this field
  Future<List<String>> validate(
    T? value,
    Map<String, dynamic> formState, {
    FormixMessages messages = const DefaultFormixMessages(),
  }) async {
    final errors = <String>[];

    // Synchronous validation
    if (validator != null) {
      final syncError = validator!(value);
      if (syncError != null) {
        errors.add(syncError);
      }
    }

    // Cross-field validation
    if (stateValidator != null) {
      final stateError = stateValidator!(value, formState);
      if (stateError != null) {
        errors.add(stateError);
      }
    }

    // Asynchronous validation
    if (asyncValidator != null) {
      try {
        final asyncError = await asyncValidator!(value);
        if (asyncError != null) {
          errors.add(asyncError);
        }
      } catch (e) {
        errors.add(messages.validationFailed(e.toString()));
      }
    }

    // Required field validation
    if (isRequired && _isEmptyValue(value)) {
      errors.add(messages.required(label ?? id.key));
    }

    return errors;
  }

  bool _isEmptyValue(T? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Iterable) {
      return value.isEmpty;
    }
    return false;
  }
}

/// Schema for text fields
class TextFieldSchema extends FormFieldSchema<String> {
  /// Creates a [TextFieldSchema].
  const TextFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.keyboardType,
  });

  /// Minimum length of the text.
  final int? minLength;

  /// Maximum length of the text.
  final int? maxLength;

  /// Regular expression pattern for validation.
  final String? pattern;

  /// Type of keyboard to display.
  final TextInputType? keyboardType;

  @override
  Future<List<String>> validate(
    String? value,
    Map<String, dynamic> formState, {
    FormixMessages messages = const DefaultFormixMessages(),
  }) async {
    final errors = await super.validate(value, formState, messages: messages);

    if (value == null) return errors;

    if (minLength != null && value.length < minLength!) {
      errors.add(messages.minLength(label ?? id.key, minLength!));
    }

    if (maxLength != null && value.length > maxLength!) {
      errors.add(messages.maxLength(label ?? id.key, maxLength!));
    }

    if (pattern != null && !RegExp(pattern!).hasMatch(value)) {
      errors.add(messages.invalidFormat());
    }

    return errors;
  }
}

/// Schema for number fields
class NumberFieldSchema extends FormFieldSchema<num> {
  /// Creates a [NumberFieldSchema].
  const NumberFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
    this.min,
    this.max,
    this.decimalPlaces = 0,
  });

  /// Minimum value.
  final num? min;

  /// Maximum value.
  final num? max;

  /// Number of decimal places allowed.
  final int decimalPlaces;

  @override
  Future<List<String>> validate(
    num? value,
    Map<String, dynamic> formState, {
    FormixMessages messages = const DefaultFormixMessages(),
  }) async {
    final errors = await super.validate(value, formState, messages: messages);

    if (value == null) return errors;

    if (min != null && value < min!) {
      errors.add(messages.minValue(label ?? id.key, min!));
    }

    if (max != null && value > max!) {
      errors.add(messages.maxValue(label ?? id.key, max!));
    }

    return errors;
  }
}

/// Schema for boolean fields
class BooleanFieldSchema extends FormFieldSchema<bool> {
  /// Creates a [BooleanFieldSchema].
  const BooleanFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
  });
}

/// Schema for date fields
class DateFieldSchema extends FormFieldSchema<DateTime> {
  /// Creates a [DateFieldSchema].
  const DateFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
    this.minDate,
    this.maxDate,
  });

  /// Minimum allowed date.
  final DateTime? minDate;

  /// Maximum allowed date.
  final DateTime? maxDate;

  @override
  Future<List<String>> validate(
    DateTime? value,
    Map<String, dynamic> formState, {
    FormixMessages messages = const DefaultFormixMessages(),
  }) async {
    final errors = await super.validate(value, formState, messages: messages);

    if (value == null) return errors;

    if (minDate != null && value.isBefore(minDate!)) {
      errors.add(messages.minDate(label ?? id.key, minDate!));
    }

    if (maxDate != null && value.isAfter(maxDate!)) {
      errors.add(messages.maxDate(label ?? id.key, maxDate!));
    }

    return errors;
  }
}

/// Schema for selection fields (dropdown, radio, etc.)
class SelectionFieldSchema<T> extends FormFieldSchema<T> {
  /// Creates a [SelectionFieldSchema].
  const SelectionFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
    required this.options,
  });

  /// List of available options for selection.
  final List<T> options;

  @override
  Future<List<String>> validate(
    T? value,
    Map<String, dynamic> formState, {
    FormixMessages messages = const DefaultFormixMessages(),
  }) async {
    final errors = await super.validate(value, formState, messages: messages);

    if (value == null) return errors;

    if (!options.contains(value)) {
      errors.add(messages.invalidSelection(label ?? id.key));
    }

    return errors;
  }
}

/// Conditional field schema that shows/hides based on other field values
class ConditionalFieldSchema<T> extends FormFieldSchema<T> {
  /// Creates a [ConditionalFieldSchema].
  const ConditionalFieldSchema({
    required super.id,
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.debounceDuration,
    super.builder,
    super.transformer,
    super.stateValidator,
    super.label,
    super.hint,
    super.isRequired,
    super.isVisible,
    super.dependencies,
    required this.visibilityCondition,
  });

  /// Condition to determine if the field should be visible.
  final bool Function(Map<String, dynamic> formState) visibilityCondition;

  @override
  bool shouldBeVisible(Map<String, dynamic> formState) {
    return visibilityCondition(formState);
  }
}

/// Form schema that defines the structure of an entire form
class FormSchema {
  /// Creates a [FormSchema].
  const FormSchema({
    required this.fields,
    this.name,
    this.description,
    this.submitButtonText = 'Submit',
    this.resetButtonText = 'Reset',
    this.onSubmit,
    this.onValidate,
    this.messages = const DefaultFormixMessages(),
  });

  /// Translation messages for validation
  final FormixMessages messages;

  /// Name of the form
  final String? name;

  /// Description of the form
  final String? description;

  /// All field schemas in the form
  final List<FormFieldSchema<dynamic>> fields;

  /// Text for submit button
  final String submitButtonText;

  /// Text for reset button
  final String resetButtonText;

  /// Submit handler
  final Future<void> Function(Map<String, dynamic> values)? onSubmit;

  /// Custom validation handler
  final Future<List<String>> Function(Map<String, dynamic> values)? onValidate;

  /// Get a field schema by ID
  FormFieldSchema<T>? getField<T>(FormixFieldID<T> fieldId) {
    try {
      return fields.firstWhere((field) => field.id == fieldId) as FormFieldSchema<T>;
    } catch (_) {
      return null;
    }
  }

  /// Get all visible fields based on current form state
  List<FormFieldSchema<dynamic>> getVisibleFields(
    Map<String, dynamic> formState,
  ) {
    return fields.where((field) => field.shouldBeVisible(formState)).toList();
  }

  /// Validate the given values against the schema
  Future<FormValidationResult> validate(
    Map<String, dynamic> values, {
    FormixMessages? customMessages,
  }) async {
    final actualMessages = customMessages ?? messages;
    final results = <FormixFieldID<dynamic>, List<String>>{};

    for (final field in fields) {
      final value = values[field.id.key];
      final fieldErrors = await field.validate(
        value,
        values,
        messages: actualMessages,
      );
      if (fieldErrors.isNotEmpty) {
        results[field.id] = fieldErrors;
      }
    }

    // Run form-level validation
    List<String> customErrors = [];
    if (onValidate != null) {
      customErrors = await onValidate!(values);
    }

    return FormValidationResult(
      isValid: results.isEmpty && customErrors.isEmpty,
      fieldErrors: results,
      customErrors: customErrors,
    );
  }

  /// Submit the form
  Future<FormSubmissionResult> submit(Map<String, dynamic> formState) async {
    try {
      // Validate first
      final validationResult = await validate(formState);
      if (!validationResult.isValid) {
        return FormSubmissionResult.failure(
          error: 'Validation failed',
          validationResult: validationResult,
        );
      }

      // Submit if handler provided
      if (onSubmit != null) {
        await onSubmit!(formState);
        return FormSubmissionResult.success();
      } else {
        return FormSubmissionResult.success(data: formState);
      }
    } catch (e) {
      return FormSubmissionResult.failure(error: e.toString());
    }
  }
}

/// Result of form validation
class FormValidationResult {
  /// Creates a [FormValidationResult].
  const FormValidationResult({
    required this.isValid,
    this.fieldErrors = const {},
    this.customErrors = const [],
  });

  /// Whether the validation was successful.
  final bool isValid;

  /// Map of errors per field ID.
  final Map<FormixFieldID<dynamic>, List<String>> fieldErrors;

  /// List of custom form-level errors.
  final List<String> customErrors;

  /// Get all error messages
  List<String> get allErrors {
    final errors = <String>[];
    errors.addAll(customErrors);
    for (final fieldErrors in fieldErrors.values) {
      errors.addAll(fieldErrors);
    }
    return errors;
  }

  /// Get errors for a specific field
  List<String> getFieldErrors(FormixFieldID<dynamic> fieldId) {
    return fieldErrors[fieldId] ?? [];
  }
}

/// Result of form submission
class FormSubmissionResult {
  const FormSubmissionResult._({
    required this.success,
    this.data,
    this.error,
    this.validationResult,
  });

  /// Creates a successful [FormSubmissionResult].
  factory FormSubmissionResult.success({dynamic data}) {
    return FormSubmissionResult._(success: true, data: data);
  }

  /// Creates a failed [FormSubmissionResult].
  factory FormSubmissionResult.failure({
    required String error,
    FormValidationResult? validationResult,
  }) {
    return FormSubmissionResult._(
      success: false,
      error: error,
      validationResult: validationResult,
    );
  }

  /// Whether the submission was successful.
  final bool success;

  /// Optional returned data from submission.
  final dynamic data;

  /// Optional error message.
  final String? error;

  /// Optional validation result if failed due to validation.
  final FormValidationResult? validationResult;
}

/// Enhanced controller that works with form schemas
class SchemaBasedFormController extends FormixController {
  /// Creates a [SchemaBasedFormController].
  SchemaBasedFormController({
    required this.schema,
    Map<String, dynamic> initialValue = const {},
  }) : super(initialValue: _buildInitialValue(schema, initialValue)) {
    // Register fields
    for (final field in schema.fields) {
      registerField(field.toFieldDefinition());
    }
  }

  /// The schema that defines this form.
  final FormSchema schema;

  /// Get visible fields based on current form state
  /// Returns only the fields that are currently visible.
  List<FormFieldSchema<dynamic>> get visibleFields {
    return schema.getVisibleFields(values);
  }

  /// Validate the entire form using the schema
  Future<FormValidationResult> validateForm() async {
    final result = await schema.validate(values);

    // Update field validation notifiers manually
    for (final field in schema.fields) {
      final fieldErrors = result.getFieldErrors(field.id);
      final validationResult = fieldErrors.isEmpty
          ? ValidationResult.valid
          : ValidationResult(
              isValid: false,
              errorMessage: fieldErrors.join(', '),
            );

      // Update the field validation notifier
      final validationNotifier = fieldValidationNotifier<dynamic>(field.id);
      validationNotifier.value = validationResult;
    }

    return result;
  }

  /// Submit the form using the schema
  Future<FormSubmissionResult> submitForm() async {
    // For now, just submit without checking submitting state
    try {
      final result = await schema.submit(values);
      if (!result.success && result.validationResult != null) {
        focusFirstError();
      }
      return result;
    } catch (e) {
      // coverage:ignore-start — unreachable: schema.submit has its own try/catch and always returns a result rather than throwing
      return FormSubmissionResult.failure(
        error: schema.messages.validationFailed(e.toString()),
      );
      // coverage:ignore-end
    }
  }

  /// Reset the form
  void resetForm({ResetStrategy strategy = ResetStrategy.initialValues}) {
    reset(strategy: strategy);
  }

  /// Check if the form is dirty (different from initial values)
  bool get isFormDirty => isDirty;

  /// Check if a specific field is dirty
  bool isFieldModified<T>(FormixFieldID<T> fieldId) => isFieldDirty(fieldId);

  static Map<String, dynamic> _buildInitialValue(
    FormSchema schema,
    Map<String, dynamic> initialValue,
  ) {
    final result = <String, dynamic>{};

    // Set schema defaults
    for (final field in schema.fields) {
      result[field.id.key] = field.initialValue;
    }

    // Override with provided values
    result.addAll(initialValue);

    return result;
  }
}
