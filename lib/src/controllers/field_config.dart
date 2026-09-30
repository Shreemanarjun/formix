import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'field_id.dart';
import 'field.dart';
import '../enums.dart';
import 'form_state.dart';
import '../validators/validators.dart';

/// Common interface for anything that can define a form field.
///
/// Both [FormixFieldConfig] and `FormixField` implement it, so APIs that take a
/// list of fields (`Formix(fields: ...)`, `FormixController(fields: ...)`) can
/// accept either — statically typed, no `List<dynamic>` or runtime type checks.
abstract interface class FormixFieldDefinition {
  /// Normalizes this definition to a [FormixFieldConfig].
  FormixFieldConfig<dynamic> toConfig();
}

/// Configuration for a form field
class FormixFieldConfig<T> implements FormixFieldDefinition {
  /// Creates a configuration for a form field.
  const FormixFieldConfig({
    required this.id,
    this.initialValue,
    this.validator,
    this.crossFieldValidator,
    this.dependsOn = const [],
    this.label,
    this.hint,
    this.asyncValidator,
    this.debounceDuration,
    this.transformer,
    this.emptyValue,
    this.validationMode = FormixAutovalidateMode.auto,
    this.initialValueStrategy = FormixInitialValueStrategy.preferLocal,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
  });

  /// Create a field config with a validator chain.
  factory FormixFieldConfig.chain({
    required FormixFieldID<T> id,
    required ValidatorChain<T, dynamic> rules,
    T? initialValue,
    String? label,
    String? hint,
    Duration? debounceDuration,
    FormixAutovalidateMode validationMode = FormixAutovalidateMode.auto,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return FormixFieldConfig<T>(
      id: id,
      initialValue: initialValue,
      validator: (T? v) => rules.build()(v),
      asyncValidator: (T? v) => rules.buildAsync()(v),
      label: label,
      hint: hint,
      debounceDuration: debounceDuration ?? rules.debounceDuration,
      validationMode: validationMode,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }

  /// Unique identifier for this field
  final FormixFieldID<T> id;

  /// Initial value of the field
  final T? initialValue;

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

  /// Asynchronous validator
  final Future<String?> Function(T? value)? asyncValidator;

  /// Debounce duration for async validation
  final Duration? debounceDuration;

  /// Validation mode for this field
  final FormixAutovalidateMode validationMode;

  /// Strategy for handling initial values
  final FormixInitialValueStrategy initialValueStrategy;

  /// Input formatters for the field (UI)
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard action (e.g. next, done)
  final TextInputAction? textInputAction;

  /// Optional transformer to convert raw input to specific type
  final T Function(dynamic value)? transformer;

  /// Value to use when the field is cleared or reset
  final T? emptyValue;

  /// Callback when field is submitted
  final void Function(String)? onSubmitted;

  /// A [FormixFieldConfig] is already a config; returns itself.
  @override
  FormixFieldConfig<T> toConfig() => this;

  /// Converts this configuration into a [FormixField].
  FormixField<T> toField() {
    // Capture values to avoid type inference issues
    final localValidator = validator;
    final localCrossFieldValidator = crossFieldValidator;
    final localAsyncValidator = asyncValidator;

    return FormixField<T>(
      id: id,
      initialValue: initialValue,
      validator: localValidator,
      crossFieldValidator: localCrossFieldValidator,
      dependsOn: dependsOn,
      label: label,
      hint: hint,
      asyncValidator: localAsyncValidator,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormixFieldConfig<T> &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          initialValue == other.initialValue &&
          validator == other.validator &&
          crossFieldValidator == other.crossFieldValidator &&
          const ListEquality().equals(dependsOn, other.dependsOn) &&
          label == other.label &&
          hint == other.hint &&
          asyncValidator == other.asyncValidator &&
          debounceDuration == other.debounceDuration &&
          validationMode == other.validationMode &&
          initialValueStrategy == other.initialValueStrategy &&
          inputFormatters == other.inputFormatters &&
          textInputAction == other.textInputAction &&
          transformer == other.transformer &&
          emptyValue == other.emptyValue &&
          onSubmitted == other.onSubmitted;

  @override
  int get hashCode =>
      id.hashCode ^
      initialValue.hashCode ^
      validator.hashCode ^
      crossFieldValidator.hashCode ^
      const ListEquality().hash(dependsOn) ^
      label.hashCode ^
      hint.hashCode ^
      asyncValidator.hashCode ^
      debounceDuration.hashCode ^
      validationMode.hashCode ^
      initialValueStrategy.hashCode ^
      inputFormatters.hashCode ^
      textInputAction.hashCode ^
      transformer.hashCode ^
      emptyValue.hashCode ^
      onSubmitted.hashCode;

  @override
  String toString() {
    return 'FormixFieldConfig<$T>(id: $id, initialValue: $initialValue, label: $label)';
  }
}
