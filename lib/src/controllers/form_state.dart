import 'package:collection/collection.dart';
import 'validation.dart';
import 'field_id.dart';

/// Immutable state of the entire form at a given point in time.
///
/// This includes all field values, validation results, and metadata like
/// dirty and touched states.
class FormixData {
  /// Map of field keys to their current values.
  final Map<String, dynamic> values;

  /// Map of field keys to their current validation results.
  final Map<String, ValidationResult> validations;

  /// Map of field keys to their dirty status (if they have been modified).
  final Map<String, bool> dirtyStates;

  /// Map of field keys to their touched status (if they have been interacted with).
  final Map<String, bool> touchedStates;

  /// Map of field keys to their pending status (e.g. validatng, syncing).
  final Map<String, bool> pendingStates;

  /// Whether the form is currently in the process of being submitted.
  final bool isSubmitting;

  /// Number of times the form has been reset.
  final int resetCount;

  /// The number of validation errors in the form.
  final int errorCount;

  /// The number of fields that are dirty.
  final int dirtyCount;

  /// The number of fields that are pending.
  final int pendingCount;

  /// The set of field keys that changed in the last update.
  ///
  /// This is used for delta updates to optimize notification performance.
  /// If null, consumers should assume all fields might have changed.
  final Set<String>? changedFields;

  /// The current step in a multi-step form (optional).
  final int currentStep;

  /// Creates a new form state.
  const FormixData({
    this.values = const {},
    this.validations = const {},
    this.dirtyStates = const {},
    this.touchedStates = const {},
    this.pendingStates = const {},
    this.isSubmitting = false,
    this.resetCount = 0,
    this.errorCount = 0,
    this.dirtyCount = 0,
    this.pendingCount = 0,
    this.changedFields,
    this.currentStep = 0,
  });

  /// Creates a form state and automatically calculates error, dirty and pending counts.
  /// Useful for testing and manual state creation.
  factory FormixData.withCalculatedCounts({
    Map<String, dynamic> values = const {},
    Map<String, ValidationResult> validations = const {},
    Map<String, bool> dirtyStates = const {},
    Map<String, bool> touchedStates = const {},
    Map<String, bool> pendingStates = const {},
    bool isSubmitting = false,
    int resetCount = 0,
    Set<String>? changedFields,
    int currentStep = 0,
  }) {
    return FormixData(
      values: values,
      validations: validations,
      dirtyStates: dirtyStates,
      touchedStates: touchedStates,
      pendingStates: pendingStates,
      isSubmitting: isSubmitting,
      resetCount: resetCount,
      errorCount: validations.values.where((v) => !v.isValid).length,
      dirtyCount: dirtyStates.values.where((d) => d).length,
      pendingCount: pendingStates.values.where((p) => p).length + validations.values.where((v) => v.isValidating).length,
      changedFields: changedFields,
      currentStep: currentStep,
    );
  }

  /// Creates a copy of this state with some properties replaced.
  FormixData copyWith({
    Map<String, dynamic>? values,
    Map<String, ValidationResult>? validations,
    Map<String, bool>? dirtyStates,
    Map<String, bool>? touchedStates,
    Map<String, bool>? pendingStates,
    bool? isSubmitting,
    int? resetCount,
    int? errorCount,
    int? dirtyCount,
    int? pendingCount,
    Set<String>? changedFields,
    bool clearChangedFields = false,
    int? currentStep,
  }) {
    return FormixData(
      values: values ?? this.values,
      validations: validations ?? this.validations,
      dirtyStates: dirtyStates ?? this.dirtyStates,
      touchedStates: touchedStates ?? this.touchedStates,
      pendingStates: pendingStates ?? this.pendingStates,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      resetCount: resetCount ?? this.resetCount,
      errorCount: errorCount ?? this.errorCount,
      dirtyCount: dirtyCount ?? this.dirtyCount,
      pendingCount: pendingCount ?? this.pendingCount,
      changedFields: clearChangedFields ? null : (changedFields ?? this.changedFields),
      currentStep: currentStep ?? this.currentStep,
    );
  }

  /// returns `true` if all registered fields are valid.
  bool get isValid => errorCount == 0;

  /// returns `true` if any registered field has been modified.
  bool get isDirty => dirtyCount > 0;

  /// returns `true` if any registered field is currently pending (e.g. async operation).
  bool get isPending => pendingCount > 0;

  /// Returns a map of all field keys to their current error messages.
  ///
  /// Fields that are valid or do not have an error message are excluded.
  Map<String, String> get errors => {
    for (final entry in validations.entries)
      if (!entry.value.isValid && entry.value.errorMessage != null) entry.key: entry.value.errorMessage!,
  };

  /// Returns a list of all current validation error messages.
  List<String> get errorMessages => errors.values.toList();

  /// Retrieves the current value for a specific field with type safety.
  ///
  /// Returns null if the field value is null or missing.
  T? getValue<T>(FormixFieldID<T> fieldId) {
    final value = values[fieldId.key];
    return value is T ? value : null;
  }

  /// Retrieves the current value and ensures it is not null.
  ///
  /// Throws a [StateError] if the field value is null.
  T requireValue<T>(FormixFieldID<T> fieldId) {
    final value = getValue(fieldId);
    if (value == null) {
      throw StateError('Field "${fieldId.key}" is required but found null.');
    }
    return value;
  }

  /// Retrieves the current validation result for a specific field.
  ValidationResult getValidation<T>(FormixFieldID<T> fieldId) {
    return validations[fieldId.key] ?? ValidationResult.valid;
  }

  /// Returns `true` if the field has been modified.
  bool isFieldDirty<T>(FormixFieldID<T> fieldId) {
    return dirtyStates[fieldId.key] ?? false;
  }

  /// Returns `true` if the field has been interacted with.
  bool isFieldTouched<T>(FormixFieldID<T> id) {
    return touchedStates[id.key] ?? false;
  }

  /// Returns `true` if the field is pending (e.g. async validation or sync).
  bool isFieldPending<T>(FormixFieldID<T> id) {
    return pendingStates[id.key] ?? false;
  }

  /// Returns a nested representation of the form values.
  ///
  /// This converts flat keys like 'user.name' and 'addresses[0].city' into
  /// nested maps and lists.
  Map<String, dynamic> toNestedMap() {
    final result = <String, dynamic>{};
    for (final entry in values.entries) {
      _setNestedValue(result, entry.key, entry.value);
    }
    return result;
  }

  /// Checks if a specific group of fields is valid.
  ///
  /// A group is identified by its key prefix (e.g., 'user').
  bool isGroupValid(String prefix) {
    return validations.entries.where((e) => e.key.startsWith('$prefix.')).every((e) => e.value.isValid);
  }

  /// Checks if a specific group of fields contains any modifications.
  bool isGroupDirty(String prefix) {
    return dirtyStates.entries.where((e) => e.key.startsWith('$prefix.')).any((e) => e.value);
  }

  void _setNestedValue(Map<String, dynamic> map, String path, dynamic value) {
    // Basic implementation for dot notation.
    // Logic for arrays (brackets) can be added if needed for auto-serialization.
    final parts = path.split('.');
    dynamic current = map;

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i == parts.length - 1) {
        if (current is Map) {
          current[part] = value;
        }
      } else {
        if (current is Map) {
          current = current[part] ??= <String, dynamic>{};
        }
      }
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FormixData) return false;

    // Fast path: check non-collection fields first
    if (isSubmitting != other.isSubmitting ||
        resetCount != other.resetCount ||
        errorCount != other.errorCount ||
        dirtyCount != other.dirtyCount ||
        pendingCount != other.pendingCount ||
        currentStep != other.currentStep) {
      return false;
    }

    // Medium path: check collection identity
    if (identical(values, other.values) &&
        identical(validations, other.validations) &&
        identical(dirtyStates, other.dirtyStates) &&
        identical(touchedStates, other.touchedStates) &&
        identical(pendingStates, other.pendingStates)) {
      return true;
    }

    // Slow path: deep equality
    // We use MapEquality for better performance than DeepCollectionEquality.
    // Note: If users store nested collections in 'values', those will be checked
    // by MapEquality's element comparison, but reference equality will be used for those elements.
    // Given Formix's focus on flat form states, this is a significant optimization.
    const mapEquals = MapEquality();

    return mapEquals.equals(values, other.values) &&
        mapEquals.equals(validations, other.validations) &&
        mapEquals.equals(dirtyStates, other.dirtyStates) &&
        mapEquals.equals(touchedStates, other.touchedStates) &&
        mapEquals.equals(pendingStates, other.pendingStates);
  }

  @override
  int get hashCode {
    const mapEquals = MapEquality();

    return Object.hash(
      mapEquals.hash(values),
      mapEquals.hash(validations),
      mapEquals.hash(dirtyStates),
      mapEquals.hash(touchedStates),
      mapEquals.hash(pendingStates),
      isSubmitting,
      resetCount,
      errorCount,
      dirtyCount,
      pendingCount,
      currentStep,
    );
  }

  /// Converts this state to a map for serialization (restoration).
  Map<String, dynamic> toMap() => {
    'values': values,
    'validations': validations.map((k, v) => MapEntry(k, v.toMap())),
    'dirtyStates': dirtyStates,
    'touchedStates': touchedStates,
    'pendingStates': pendingStates,
    'isSubmitting': isSubmitting,
    'resetCount': resetCount,
    'currentStep': currentStep,
  };

  /// Creates a form state from a map.
  factory FormixData.fromMap(Map<String, dynamic> map) {
    final validationsRaw = map['validations'] as Map<String, dynamic>? ?? {};
    final validations = validationsRaw.map(
      (k, v) => MapEntry(k, ValidationResult.fromMap(v as Map<String, dynamic>)),
    );

    return FormixData.withCalculatedCounts(
      values: Map<String, dynamic>.from(map['values'] as Map? ?? {}),
      validations: validations,
      dirtyStates: Map<String, bool>.from(map['dirtyStates'] as Map? ?? {}),
      touchedStates: Map<String, bool>.from(map['touchedStates'] as Map? ?? {}),
      pendingStates: Map<String, bool>.from(map['pendingStates'] as Map? ?? {}),
      isSubmitting: map['isSubmitting'] as bool? ?? false,
      resetCount: map['resetCount'] as int? ?? 0,
      currentStep: map['currentStep'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'FormixData(values: $values, errorCount: $errorCount, dirtyCount: $dirtyCount, pendingCount: $pendingCount, isSubmitting: $isSubmitting)';
  }
}
