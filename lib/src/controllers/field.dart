import 'package:flutter/services.dart';
import 'field_id.dart';
import '../enums.dart';
import 'form_state.dart';
import 'field_config.dart';

/// Form field definition with validation and type information
class FormixField<T> implements FormixFieldDefinition {
  /// Creates a [FormixField] definition.
  const FormixField({
    required this.id,
    required this.initialValue,
    this.validator,
    this.crossFieldValidator,
    this.dependsOn = const [],
    this.label,
    this.hint,
    this.transformer,
    this.asyncValidator,
    this.debounceDuration,
    this.emptyValue,
    this.validationMode = FormixAutovalidateMode.auto,
    this.initialValueStrategy = FormixInitialValueStrategy.preferLocal,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
  });

  /// Unique identifier for this field
  final FormixFieldID<T> id;

  /// Initial value of the field
  final T? initialValue;

  /// Strategy for handling initial values
  final FormixInitialValueStrategy initialValueStrategy;

  /// Value to use when the field is cleared or reset
  final T? emptyValue;

  /// Synchronous validator function
  final String? Function(T? value)? validator;

  /// Cross-field validator that can access the entire form state
  final String? Function(T? value, FormixData state)? crossFieldValidator;

  /// List of fields that this field depends on for validation
  final List<FormixFieldID<dynamic>> dependsOn;

  /// Label for the field (UI hint)
  final String? label;

  /// Hint text for the field (UI hint)
  final String? hint;

  /// Optional transformer to convert raw input to specific type
  final T Function(dynamic value)? transformer;

  /// Asynchronous validator
  final Future<String?> Function(T? value)? asyncValidator;

  /// Debounce duration for async validation
  final Duration? debounceDuration;

  /// Validation mode for this field
  final FormixAutovalidateMode validationMode;

  /// Input formatters for the field (UI)
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard action (e.g. next, done)
  final TextInputAction? textInputAction;

  /// Callback when field is submitted
  final void Function(String)? onSubmitted;

  /// Creates a configuration object that correctly preserves type `<T>`
  @override
  FormixFieldConfig<T> toConfig() {
    return FormixFieldConfig<T>(
      id: id,
      initialValue: initialValue,
      validator: wrappedValidator,
      crossFieldValidator: wrappedCrossFieldValidator,
      dependsOn: dependsOn,
      label: label,
      hint: hint,
      asyncValidator: wrappedAsyncValidator,
      debounceDuration: debounceDuration,
      validationMode: validationMode,
      initialValueStrategy: initialValueStrategy,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      transformer: transformer,
      emptyValue: emptyValue,
      onSubmitted: onSubmitted,
    );
  }

  /// Returns a wrapped version of the validator that accepts dynamic input.
  String? Function(dynamic)? get wrappedValidator {
    final v = validator;
    if (v == null) return null;
    return (dynamic value) => v(value as T?);
  }

  /// Returns a wrapped version of the cross-field validator that accepts dynamic input.
  String? Function(dynamic, FormixData)? get wrappedCrossFieldValidator {
    final v = crossFieldValidator;
    if (v == null) return null;
    return (dynamic value, FormixData state) => v(value as T?, state);
  }

  /// Returns a wrapped version of the async validator that accepts dynamic input.
  Future<String?> Function(dynamic)? get wrappedAsyncValidator {
    final v = asyncValidator;
    if (v == null) return null;
    return (dynamic value) => v(value as T?);
  }

  /// Returns a wrapped version of the transformer that accepts dynamic input.
  dynamic Function(dynamic)? get wrappedTransformer {
    final t = transformer;
    if (t == null) return null;
    return (dynamic value) => t(value);
  }

  /// Checks if the given value matches the field's type [T].
  /// This is more robust than runtimeType comparison as it handles
  /// inheritance and generic type compatibility correctly.
  bool isTypeValid(dynamic value) => value is T;

  /// Returns true if [T] is a nullable type.
  bool get isNullableType => null is T;

  @override
  String toString() {
    return 'FormixField<$T>(id: $id, label: $label, initialValue: $initialValue)';
  }
}
