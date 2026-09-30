import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'field.dart';
import 'field_id.dart';
import 'validation.dart';
import 'form_state.dart';
import 'field_config.dart';
import 'formix_controller.dart';
import '../analytics/form_analytics.dart';
import '../i18n.dart';
import '../validators/validation_keys.dart';
import '../enums.dart';
import 'batch.dart';
import '../persistence/form_persistence.dart';
import '../devtools/formix_devtools.dart';

export 'form_state.dart';
export 'field_config.dart';
export 'formix_controller.dart';

/// Core logic for managing form state, powered by [Signal]s.
///
/// This controller is the brain of the form. It coordinates:
/// *   **Field Lifecycle**: Registration and disposal of form fields.
/// *   **Value Management**: Synchronous and asynchronous value updates.
/// *   **Validation Rules**: Per-field (sync/async) and cross-field validation.
/// *   **Dependency Tracking**: Automatically re-calculates fields when their dependencies change.
/// *   **Undo/Redo**: Maintains a history of form states for easy navigation.
/// *   **Persistence**: Integrates with [FormixPersistence] to save/restore data.
///
/// The whole-form state is held in a single [Signal<FormixData>]; widgets watch
/// fine-grained [Computed] slices (see [FormixController]) so a change to one
/// field only rebuilds the widgets that read that field.
///
/// You typically interact with this via [Formix.of(context)] in widgets,
/// or by holding a [FormixController] instance directly.
class FormixBaseController {
  /// The configuration this controller was created with.
  final FormixParameter parameter;

  /// Creates a [FormixBaseController] and initializes its fields and state.
  FormixBaseController([this.parameter = const FormixParameter()]) {
    _initFields();
    _initialize();
  }

  void _initFields() {
    persistence = parameter.persistence;
    formId = parameter.formId;
    analytics = parameter.analytics;
    autovalidateMode = parameter.autovalidateMode;
    _registeredDevToolsId = parameter.formId ?? parameter.namespace;
    messages = parameter.messages ?? formixGlobalMessages.peek();
  }

  /// The reactive source of truth for the entire form state.
  late final Signal<FormixData> _stateSignal;

  /// Disposes the global-message subscription (language changes).
  VoidCallback? _messagesEffectDispose;

  /// Internationalization messages for validation errors
  late FormixMessages messages;

  /// Map of initial values for all registered fields.
  @protected
  final Map<String, dynamic> initialValueMap = {};
  final Map<String, Timer> _debouncers = {};
  Timer? _submitDebounceTimer;
  DateTime? _lastSubmitTime;
  DateTime? _startTime;
  final Map<String, FormixField<dynamic>> _fieldDefinitions = {};
  final Map<String, List<String>> _dependentsMap = {};
  final Map<String, Set<String>> _transitiveDependentsCache = {};

  /// The global autovalidate mode applied to all fields in this form.
  ///
  /// Individual fields may override this with their own [FormixAutovalidateMode].
  late FormixAutovalidateMode autovalidateMode;

  /// Returns the number of registered fields (for testing).
  @visibleForTesting
  int get registeredFieldsCount => _fieldDefinitions.length;

  // Undo/Redo History
  List<FormixData> _history = [];
  int _historyIndex = -1;
  bool _isRestoringHistory = false;
  static const int _maxHistoryLength = 50;

  /// Returns the number of history states (for testing).
  @visibleForTesting
  int get historyCount => _history.length;

  bool _hasSubmittedSuccessfully = false;

  final Map<String, StreamSubscription> _bindings = {};

  final Map<String, Duration> _validationDurations = {};

  /// Get validation durations for DevTools
  Map<String, Duration> get validationDurations => Map.unmodifiable(_validationDurations);

  /// Get the dependency map for DevTools
  Map<String, List<String>> get dependentsMap => Map.unmodifiable(_dependentsMap);

  /// Get the field definitions for DevTools
  Map<String, FormixField<dynamic>> get formFieldDefinitions => Map.unmodifiable(_fieldDefinitions);

  /// Returns the number of active bindings (for testing).
  @visibleForTesting
  int get activeBindingsCount => _bindings.length;

  /// Stream controller for broadcasting state changes to external listeners
  final _stateController = StreamController<FormixData>.broadcast(sync: true);

  /// Stream of form state changes.
  Stream<FormixData> get stream => _stateController.stream;

  /// Registered listeners for form state changes
  @protected
  final List<void Function(FormixData)> formListeners = [];

  /// Whether this controller is still active (not disposed).
  bool _isDisposed = false;

  /// Whether this controller is still active (not disposed).
  bool get mounted => !_isDisposed;

  /// Add a listener that will be called whenever the form state changes.
  VoidCallback addFormListener(void Function(FormixData state) listener) {
    formListeners.add(listener);
    return () => removeFormListener(listener);
  }

  /// Remove a previously added listener
  void removeFormListener(void Function(FormixData state) listener) {
    formListeners.remove(listener);
  }

  /// Notify all listeners and stream subscribers of state changes
  void _notifyFormListeners() {
    if (!mounted) return;

    if (!_stateController.isClosed) {
      _stateController.add(state);
    }

    // Notify callback listeners
    for (final listener in formListeners.toList()) {
      try {
        listener(state);
      } catch (e) {
        debugPrint('Error in form listener: $e');
      }
    }
  }

  /// Replaces the whole-form state, recording it in the undo/redo history.
  set state(FormixData value) {
    if (_isRestoringHistory) {
      _applyState(value);
      return;
    }

    final valuesChanged = _history.isEmpty || !const MapEquality().equals(_history[_historyIndex].values, value.values);
    final resetOccurred = _history.isNotEmpty && _history[_historyIndex].resetCount != value.resetCount;

    if (valuesChanged || resetOccurred) {
      // If we are at the end, just add. If we are in the middle, truncate.
      if (_historyIndex < _history.length - 1) {
        _history = _history.sublist(0, _historyIndex + 1);
      }

      _history.add(value);
      if (_history.length > _maxHistoryLength) {
        _history.removeAt(0);
      } else {
        _historyIndex++;
      }
    }

    _applyState(value);
  }

  /// Internal helper to push a new state into the reactive [Signal].
  void _applyState(FormixData value) {
    if (!mounted) return;

    // We only reach here when the state genuinely changed (mutations build a new
    // instance and batch updates return early on no-op), so force the write to
    // skip the O(n) FormixData equality check Signal.value would otherwise run
    // on every keystroke.
    _stateSignal.set(value, force: true);

    // We notify AFTER setting the state to ensure that listeners (and getValue calls) see the new state.
    onStateChanged(value);
  }

  /// The current whole-form state. Reading this inside a [SignalBuilder] (or any
  /// reactive context) subscribes to every form change; prefer the fine-grained
  /// slices on [FormixController] for surgical rebuilds.
  FormixData get state => _stateSignal.value;

  /// The whole-form state as a read-only [Signal], for callers that need to
  /// subscribe explicitly (e.g. [FormixScope.watchState]).
  ReadonlySignal<FormixData> get stateSignal => _stateSignal;

  /// Hook for subclasses (like [FormixController]) to react to state changes.
  @protected
  void onStateChanged(FormixData state) {
    _notifyFormListeners();
  }

  static FormixData _createInitialState(
    Map<String, dynamic> initialValues,
    List<FormixField> fields,
    FormixAutovalidateMode globalMode,
  ) {
    final values = {...initialValues};
    final validations = <String, ValidationResult>{};
    final dirtyStates = <String, bool>{};
    final touchedStates = <String, bool>{};

    for (final field in fields) {
      final key = field.id.key;
      if (field.initialValue != null || !values.containsKey(key)) {
        values[key] = field.initialValue;
      }
      dirtyStates[key] = false;
      touchedStates[key] = false;

      final val = values[key];
      final rawMode = field.validationMode;
      final effectiveMode = rawMode == FormixAutovalidateMode.auto ? globalMode : rawMode;
      final validator = field.wrappedValidator;

      if (effectiveMode == FormixAutovalidateMode.always) {
        if (validator != null && val != null) {
          try {
            final result = validator(val);
            validations[key] = result != null ? ValidationResult(isValid: false, errorMessage: result) : ValidationResult.valid;
          } catch (e) {
            validations[key] = ValidationResult(
              isValid: false,
              errorMessage: 'Validation error: $e',
            );
          }
        } else {
          validations[key] = ValidationResult.valid;
        }
      }
    }

    return FormixData.withCalculatedCounts(
      values: Map.unmodifiable(values),
      validations: validations,
      dirtyStates: dirtyStates,
      touchedStates: touchedStates,
      changedFields: values.keys.toSet(),
    );
  }

  /// Updates the messages used for validation errors.
  ///
  /// This will trigger re-validation of all fields to update error messages.
  void updateMessages(FormixMessages? newMessages) {
    final effectiveMessages = newMessages ?? const DefaultFormixMessages();
    if (messages == effectiveMessages) return;
    messages = effectiveMessages;

    // Defer validation if we are mid-frame (e.g. called from didUpdateWidget or
    // during a build) to avoid mutating a signal that is being read by a builder.
    bool isPersistent = false;
    try {
      isPersistent = WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;
    } catch (_) {}

    if (isPersistent) {
      Future.microtask(() {
        if (mounted) validate();
      });
    } else {
      validate();
    }
  }

  /// Get the validation mode for a specific field.
  FormixAutovalidateMode getValidationMode(FormixFieldID fieldId) {
    final fieldMode = _fieldDefinitions[fieldId.key]?.validationMode ?? FormixAutovalidateMode.auto;
    if (fieldMode == FormixAutovalidateMode.auto) {
      return autovalidateMode;
    }
    return fieldMode;
  }

  /// The persistence handler for this form
  late FormixPersistence? persistence;

  /// Unique identifier for this form (required for persistence)
  late String? formId;

  /// Optional analytics hook
  late FormixAnalytics? analytics;

  late String? _registeredDevToolsId;

  /// Builds the initial state, registers fields, and wires reactive listeners.
  /// Called once from the constructor.
  void _initialize() {
    _startTime = DateTime.now();
    analytics?.onFormStarted(formId);
    initialValueMap.addAll(parameter.initialValue);

    final fields = parameter.fields.map((f) => f.toField()).toList();
    final initialState = parameter.initialData ?? _createInitialState(parameter.initialValue, fields, parameter.autovalidateMode);

    // Initial Definitions setup
    for (final field in fields) {
      final key = field.id.key;
      _fieldDefinitions[key] = field;
      _validationDurations[key] = Duration.zero;
      for (final dep in field.dependsOn) {
        _dependentsMap.putIfAbsent(dep.key, () => []).add(key);
      }
      if (field.initialValue != null || !initialValueMap.containsKey(key)) {
        initialValueMap[key] = field.initialValue;
      }
    }

    _stateSignal = signal(
      initialState,
      options: SignalOptions(name: _registeredDevToolsId ?? 'formixState'),
    );

    // Set history
    _history = [initialState];
    _historyIndex = 0;

    // React to global message (language) changes unless overridden per-form.
    if (parameter.messages == null) {
      _messagesEffectDispose = effect(() {
        final next = formixGlobalMessages.value;
        untracked(() => updateMessages(next));
      });
    }

    // Schedule load persisted state
    Future.microtask(() => _loadPersistedState());

    if (_registeredDevToolsId != null) {
      FormixDevToolsService.registerController(_registeredDevToolsId!, this);
    }
  }

  // --- Array Manipulation ---

  /// Adds an item to a form array (defined by [FormixArrayID]).
  ///
  /// This will trigger a state update and re-validation of the array field.
  void addArrayItem<T>(FormixArrayID<T> id, T item) {
    final currentList = getValue(id) ?? [];
    final newList = List<T>.from(currentList)..add(item);
    setValue(id, newList);
  }

  /// Removes an item at a specific index from a form array
  void removeArrayItemAt<T>(FormixArrayID<T> id, int index) {
    final currentList = getValue(id);
    if (currentList == null || index < 0 || index >= currentList.length) return;

    final newList = List<T>.from(currentList)..removeAt(index);
    setValue(id, newList);
  }

  /// Replaces an item at a specific index in a form array
  void replaceArrayItem<T>(FormixArrayID<T> id, int index, T item) {
    final currentList = getValue(id);
    if (currentList == null || index < 0 || index >= currentList.length) return;

    final newList = List<T>.from(currentList);
    newList[index] = item;
    setValue(id, newList);
  }

  /// Reorders items in a form array.
  ///
  /// Moves the item at [oldIndex] to [newIndex].
  void moveArrayItem<T>(FormixArrayID<T> id, int oldIndex, int newIndex) {
    final currentList = getValue(id);
    if (currentList == null || oldIndex < 0 || oldIndex >= currentList.length || newIndex < 0 || newIndex >= currentList.length) {
      return;
    }

    final newList = List<T>.from(currentList);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    setValue(id, newList);
  }

  /// Clears all items from a form array
  void clearArray<T>(FormixArrayID<T> id) {
    setValue(id, <T>[]);
  }

  // --- Debug & Testing ---

  /// Fills registered fields with dummy data based on their types.
  /// Primarily intended for use in DevTools or automated testing.
  void debugFillDummyData() {
    final updates = <String, dynamic>{};
    for (final field in _fieldDefinitions.values) {
      final key = field.id.key;
      final initial = field.initialValue;

      if (initial is String) {
        updates[key] = 'Sample Text';
      } else if (initial is int) {
        updates[key] = 42;
      } else if (initial is double) {
        updates[key] = 3.14;
      } else if (initial is bool) {
        updates[key] = true;
      } else if (initial is DateTime) {
        updates[key] = DateTime.now();
      }
    }
    _batchUpdate(updates);
  }

  /// Forces a form submission, bypassing synchronous validation.
  /// Asynchronous validation may still be waited for if [waitForPending] is true.
  Future<void> debugForceSubmit({
    required Future<void> Function(Map<String, dynamic> values) onValid,
    bool waitForPending = true,
  }) async {
    setSubmitting(true);
    try {
      if (waitForPending) {
        while (state.isPending) {
          await stream.first;
          await Future<void>.delayed(Duration.zero);
        }
      }
      await onValid(state.values);
    } finally {
      setSubmitting(false);
    }
  }

  // --- Internals ---
  /// Internal helper to update initial value from subclasses
  @protected
  void setInitialValueInternal(String key, dynamic value) {
    initialValueMap[key] = value;
  }

  /// Get the current state of the form.
  FormixData get currentState => state;

  Future<void> _loadPersistedState() async {
    if (persistence != null && formId != null) {
      final savedValues = await persistence!.getSavedState(formId!);
      if (savedValues != null && mounted) {
        final newValues = {...state.values};
        newValues.addAll(savedValues);

        final newValidations = {...state.validations};
        final newDirtyStates = {...state.dirtyStates};

        for (final key in savedValues.keys) {
          if (_fieldDefinitions.containsKey(key)) {
            final field = _fieldDefinitions[key]!;
            final value = savedValues[key];

            final initial = initialValueMap[key];
            final isDirty = initial == null ? value != null : value != initial;
            newDirtyStates[key] = isDirty;

            if (field.validator != null) {
              try {
                final res = field.validator!(value);
                newValidations[key] = res != null ? ValidationResult(isValid: false, errorMessage: res) : ValidationResult.valid;
              } catch (_) {}
            }
          } else {
            newDirtyStates[key] = true;
          }
        }

        state = state.copyWith(
          values: newValues,
          validations: newValidations,
          dirtyStates: newDirtyStates,
          // A persisted load can touch many fields; clear the delta so every live
          // reactive slice re-syncs from the loaded state.
          clearChangedFields: true,
        );
      }
    }
  }

  /// Get the initial form value
  Map<String, dynamic> get initialValue => Map.unmodifiable(initialValueMap);

  /// Whether the form is currently being submitted.
  ///
  /// This is true while the `onValid` callback provided to [submit] is executing.
  // coverage:ignore-line — always overridden by FormixController; base getter never invoked directly
  bool get isSubmitting => state.isSubmitting;

  /// Map of all current field keys to their error messages.
  // coverage:ignore-line — always overridden by FormixController; base getter never invoked directly
  Map<String, String> get errors => state.errors;

  /// List of all current validation error messages.
  // coverage:ignore-line — always overridden by FormixController; base getter never invoked directly
  List<String> get errorMessages => state.errorMessages;

  /// Check if a field is registered
  /// Returns true if a field with [fieldId] is currently registered.
  bool isFieldRegistered<T>(FormixFieldID<T> fieldId) {
    return _fieldDefinitions.containsKey(fieldId.key);
  }

  /// If true, this controller will not be disposed when [dispose] is called.
  /// This is useful when the controller is managed externally and passed to Formix
  /// with keepAlive: true.
  bool preventDisposal = false;

  /// Disposes resources used by this controller.
  void dispose() {
    if (_isDisposed || preventDisposal) return;
    _isDisposed = true;
    if (_registeredDevToolsId != null) {
      FormixDevToolsService.unregisterController(_registeredDevToolsId!);
    }
    if (!_hasSubmittedSuccessfully) {
      final duration = DateTime.now().difference(_startTime ?? DateTime.now());
      analytics?.onFormAbandoned(formId, duration);
    }
    for (var timer in _debouncers.values) {
      timer.cancel();
    }
    _submitDebounceTimer?.cancel();
    for (var sub in _bindings.values) {
      sub.cancel();
    }
    _bindings.clear();
    _messagesEffectDispose?.call();
    _stateController.close();
    formListeners.clear();
    _stateSignal.dispose();
  }

  /// Retrieves the current value of a field in a type-safe way.
  ///
  /// This method is "smart": if the field is not yet registered but was
  /// provided in the [initialValue] map during controller creation, it
  /// will return that initial value.
  ///
  /// Returns the value of type [T]. If [T] is non-nullable and the value
  /// is missing or null, this will throw a [TypeError] or [StateError].
  T? getValue<T>(FormixFieldID<T> fieldId) {
    // 1. Check current form state (most up-to-date)
    if (state.values.containsKey(fieldId.key)) {
      return state.getValue(fieldId);
    }

    // 2. Fallback for non-registered fields: check initial value map
    final initial = initialValueMap[fieldId.key];
    if (initial is T) return initial;

    // 3. Check registered field definitions (last resort for initial values)
    // coverage:ignore-start — unreachable: registerField always mirrors a field's initialValue into initialValueMap, so branch 2 above catches it first
    final field = _fieldDefinitions[fieldId.key];
    if (field != null && field.initialValue is T) {
      return field.initialValue as T;
    }
    // coverage:ignore-end

    return null;
  }

  /// Retrieves the current value of a field and ensures it is not null.
  ///
  /// Throws a [StateError] if the field value is null.
  T requireValue<T>(FormixFieldID<T> fieldId) {
    final value = getValue(fieldId);
    if (value == null) {
      throw StateError('Field "${fieldId.key}" is required but found null.');
    }
    return value;
  }

  /// Retrieves the [FormixField] definition for a given [fieldId].
  FormixField? getField(FormixFieldID<dynamic> fieldId) {
    return _fieldDefinitions[fieldId.key];
  }

  /// Updates the value of a field and triggers validation.
  ///
  /// This method:
  /// 1.  Applies any transformations defined for the field.
  /// 2.  Updates the field's value and dirty state.
  /// 3.  Triggers synchronous validation for the field and its dependents.
  /// 4.  Triggers asynchronous validation (if applicable).
  /// 5.  Saves the state if persistence is enabled.
  ///
  /// Throws an [ArgumentError] if the value type doesn't match the field's
  /// expected type (based on initial value).
  void setValue<T>(FormixFieldID<T> fieldId, T value) {
    _batchUpdate({fieldId: value}, strict: true);
  }

  /// Updates multiple field values at once in a single state update.
  ///
  /// This is highly efficient for bulk operations (e.g. loading from API) as it
  /// performs only one round of dependency collection and validation, and
  /// triggers only one UI rebuild.
  ///
  /// Set [strict] to true to throw an [ArgumentError] on type mismatch.
  /// Otherwise, it returns a [FormixBatchResult] with error details.
  FormixBatchResult setValues(
    Map<FormixFieldID, dynamic> updates, {
    bool strict = false,
  }) {
    return _batchUpdate(updates, strict: strict);
  }

  /// Updates multiple field values using a type-safe [FormixBatch].
  FormixBatchResult applyBatch(FormixBatch batch, {bool strict = false}) {
    return _batchUpdate(batch.updates, strict: strict);
  }

  FormixBatchResult _batchUpdate(
    Map<dynamic, dynamic> updates, {
    bool strict = false,
    Map<String, bool>? touchedStates,
  }) {
    if (updates.isEmpty && (touchedStates == null || touchedStates.isEmpty)) {
      return const FormixBatchResult(success: true);
    }
    if (!mounted) {
      return const FormixBatchResult(success: false);
    }

    final typeMismatches = <String, String>{};
    final missingFields = <String>{};
    final validUpdates = <String, dynamic>{};

    for (final entry in updates.entries) {
      final dynamic rawKey = entry.key;
      final String key = rawKey is FormixFieldID ? rawKey.key : rawKey as String;
      final value = entry.value;
      final FormixFieldID? fieldIdFromUpdate = rawKey is FormixFieldID ? rawKey : null;

      final fieldDef = _fieldDefinitions[key];
      if (fieldDef == null) {
        missingFields.add(key);
      }

      // Type validation
      bool isTypeValid = true;
      String? expectedTypeName;

      if (fieldDef != null) {
        isTypeValid = fieldDef.isTypeValid(value);
        expectedTypeName = fieldDef.id.type.toString();
      } else {
        final expectedInitialValue = initialValueMap[key];
        if (fieldIdFromUpdate != null) {
          // 1. Check if value matches ID
          isTypeValid = fieldIdFromUpdate.isTypeValid(value);
          expectedTypeName = fieldIdFromUpdate.type.toString();

          // 2. Consistent with already inferred type from initial value map?
          if (isTypeValid && expectedInitialValue != null) {
            final initialMatches = fieldIdFromUpdate.isTypeValid(expectedInitialValue);
            if (!initialMatches) {
              // Mismatch between initial value and the typed ID.
              // We're lenient in one specific case: "Upgrading" from a raw String (e.g. from JSON)
              // to a custom Object (like ProfilePhoto) when a typed ID is provided.
              final isNewValuePrimitive = value is num || value is bool || value is String || value is DateTime;
              final isOldValueString = expectedInitialValue is String;

              if (isOldValueString && !isNewValuePrimitive) {
                // Allow this transition as it's likely a raw-to-typed conversion
              } else {
                isTypeValid = false;
                expectedTypeName = 'compatible with initial value (${expectedInitialValue.runtimeType} -> ${fieldIdFromUpdate.type})';
              }
            }
          }
        } else if (expectedInitialValue != null && value != null) {
          // Fallback to runtimeType equality if NO FormixFieldID is provided (raw string keys)
          isTypeValid = value.runtimeType == expectedInitialValue.runtimeType || (value is num && expectedInitialValue is num);

          if (!isTypeValid) {
            // Inheritance support for raw string keys:
            // If both are custom objects (non-primitives), allow the transition.
            final isNewPrimitive = value is num || value is bool || value is String || value is DateTime;
            final isOldPrimitive = expectedInitialValue is num || expectedInitialValue is bool || expectedInitialValue is String || expectedInitialValue is DateTime;

            if (!isNewPrimitive && !isOldPrimitive) {
              isTypeValid = true;
            }
          }
          expectedTypeName = expectedInitialValue.runtimeType.toString();
        }
      }

      if (!isTypeValid) {
        final error = 'Type mismatch for field $key: expected $expectedTypeName, got ${value?.runtimeType}';
        if (strict) throw ArgumentError(error);
        typeMismatches[key] = error;
        continue;
      }
      validUpdates[key] = value;
    }

    if (validUpdates.isEmpty && (touchedStates == null || touchedStates.isEmpty)) {
      return FormixBatchResult(
        success: typeMismatches.isEmpty && missingFields.isEmpty,
        typeMismatches: typeMismatches,
        missingFields: missingFields,
      );
    }

    Map<String, dynamic>? newValues;
    Map<String, bool>? newDirtyStates;
    Map<String, bool>? newTouchedStates = (touchedStates != null && touchedStates.isNotEmpty) ? {...state.touchedStates, ...touchedStates} : null;
    Map<String, ValidationResult>? newValidations;
    final fieldsToValidate = <String>{};
    final changedFieldsInThisUpdate = <String>{};

    int newDirtyCount = state.dirtyCount;
    int newErrorCount = state.errorCount;
    int newPendingCount = state.pendingCount;

    final keysToProcess = {
      ...validUpdates.keys,
      if (newTouchedStates != null) ...newTouchedStates.keys,
    };

    final visitedDependentsInBatch = <String>{};
    for (final key in keysToProcess) {
      final hasNewValue = validUpdates.containsKey(key);
      dynamic value = hasNewValue ? validUpdates[key] : state.values[key];

      if (hasNewValue) {
        final fieldDef = _fieldDefinitions[key];
        final transformer = fieldDef?.transformer;
        if (transformer != null) {
          value = transformer(value);
        }

        final oldValue = newValues != null ? newValues[key] : state.values[key];
        if (value != oldValue) {
          newValues ??= {...state.values};
          newValues[key] = value;
          changedFieldsInThisUpdate.add(key);
          analytics?.onFieldChanged(formId, key, value);
        }
      }

      final isDirty = initialValueMap[key] == null ? value != null : value != initialValueMap[key];

      final currentDirty = newDirtyStates != null ? (newDirtyStates[key] ?? false) : (state.dirtyStates[key] ?? false);

      if (currentDirty != isDirty) {
        newDirtyStates ??= {...state.dirtyStates};
        newDirtyStates[key] = isDirty;
        newDirtyCount += isDirty ? 1 : -1;
      }

      final fieldDef = _fieldDefinitions[key];
      final rawMode = fieldDef?.validationMode ?? FormixAutovalidateMode.auto;
      final mode = rawMode == FormixAutovalidateMode.auto ? autovalidateMode : rawMode;

      final isTouched = (newTouchedStates != null ? newTouchedStates[key] : state.touchedStates[key]) ?? false;
      final wasValidated = state.validations.containsKey(key);

      if (mode == FormixAutovalidateMode.always ||
          (mode == FormixAutovalidateMode.onUserInteraction && (isDirty || isTouched || wasValidated)) ||
          (mode == FormixAutovalidateMode.onBlur && (isTouched || wasValidated))) {
        fieldsToValidate.add(key);
      }

      final transitiveDependents = _collectTransitiveDependents(key);
      if (transitiveDependents.isNotEmpty) {
        for (final depKey in transitiveDependents) {
          if (!visitedDependentsInBatch.add(depKey)) continue;

          final depDef = _fieldDefinitions[depKey];
          if (depDef != null) {
            final rawDepMode = depDef.validationMode;
            final depMode = rawDepMode == FormixAutovalidateMode.auto ? autovalidateMode : rawDepMode;
            final isDepTouched = (newTouchedStates != null ? newTouchedStates[depKey] : state.touchedStates[depKey]) ?? false;
            final depVal = newValues != null ? newValues[depKey] : state.values[depKey];
            final isDepDirty = initialValueMap[depKey] == null ? depVal != null : depVal != initialValueMap[depKey];
            final wasDepValidated = state.validations.containsKey(depKey);

            if (depMode == FormixAutovalidateMode.always ||
                (depMode == FormixAutovalidateMode.onUserInteraction && (isDepDirty || isDepTouched || wasDepValidated)) ||
                (depMode == FormixAutovalidateMode.onBlur && (isDepTouched || wasDepValidated))) {
              fieldsToValidate.add(depKey);
            }
          }
        }
      }
    }

    final asyncToTrigger = <String, dynamic>{};

    if (fieldsToValidate.isNotEmpty) {
      FormixData? validationContext;

      for (final key in fieldsToValidate) {
        final val = newValues != null ? newValues[key] : state.values[key];
        final effectiveValidations = newValidations ?? state.validations;
        final oldRes = effectiveValidations[key] ?? ValidationResult.valid;

        final syncRes = _performSyncValidation(
          key,
          val,
          validationContext?.values ?? (newValues ?? state.values),
          currentValidations: effectiveValidations,
          validationState: validationContext,
        );

        final fieldDef = _fieldDefinitions[key];
        ValidationResult finalRes = syncRes;
        if (syncRes.isValid && fieldDef?.wrappedAsyncValidator != null) {
          finalRes = ValidationResult.validating;
          asyncToTrigger[key] = val;
        }

        final wasValidatedInPreviousState = state.validations.containsKey(key);
        if (oldRes != finalRes || !wasValidatedInPreviousState) {
          if (newValidations == null) {
            newValidations = Map<String, ValidationResult>.from(
              state.validations,
            );
            // Re-create context once the map is cloned so it uses the new mutable reference
            validationContext = FormixData(
              values: newValues ?? state.values,
              validations: newValidations,
              dirtyStates: newDirtyStates ?? state.dirtyStates,
              touchedStates: newTouchedStates ?? state.touchedStates,
            );
          }
          newValidations[key] = finalRes;

          // Update error count
          if (oldRes.isValid && !finalRes.isValid) {
            newErrorCount++;
          } else if (!oldRes.isValid && finalRes.isValid) {
            newErrorCount--;
          }

          // Update pending count
          if (!oldRes.isValidating && finalRes.isValidating) {
            newPendingCount++;
          } else if (oldRes.isValidating && !finalRes.isValidating) {
            newPendingCount--;
          }
        }
      }
    }

    if (newValues != null || newDirtyStates != null || newValidations != null || newTouchedStates != null) {
      state = state.copyWith(
        values: newValues,
        dirtyStates: newDirtyStates,
        touchedStates: newTouchedStates,
        validations: newValidations,
        dirtyCount: newDirtyCount,
        errorCount: newErrorCount,
        pendingCount: newPendingCount,
        changedFields: {...changedFieldsInThisUpdate, ...fieldsToValidate},
      );

      // Trigger actual timers after state update to avoid race conditions
      if (asyncToTrigger.isNotEmpty) {
        asyncToTrigger.forEach(_startAsyncValidationTimer);
      }

      if (persistence != null && formId != null && newValues != null) {
        persistence!.saveFormState(formId!, newValues);
      }
    }

    return FormixBatchResult(
      success: typeMismatches.isEmpty && missingFields.isEmpty,
      updatedFields: validUpdates.keys.toSet(),
      typeMismatches: typeMismatches,
      missingFields: missingFields,
    );
  }

  ValidationResult _performSyncValidation(
    String key,
    dynamic value,
    Map<String, dynamic> currentValues, {
    Map<String, ValidationResult>? currentValidations,
    FormixData? validationState,
  }) {
    final sw = kDebugMode ? (Stopwatch()..start()) : null;
    final fieldDef = _fieldDefinitions[key];
    if (fieldDef == null) return ValidationResult.valid;

    ValidationResult? finalResult;

    // 1. Per-field Validator
    final validator = fieldDef.wrappedValidator;
    if (validator != null) {
      try {
        final String? error = validator(value);
        if (error != null) {
          finalResult = ValidationResult(
            isValid: false,
            errorMessage: _resolveErrorMessage(error, {
              'label': fieldDef.label ?? key,
              'value': value,
            }),
          );
        }
      } catch (e) {
        finalResult = ValidationResult(
          isValid: false,
          errorMessage: 'Validation error: ${e.toString()}',
        );
      }
    }

    // 2. Cross-field Validator
    if (finalResult == null) {
      final crossValidator = fieldDef.wrappedCrossFieldValidator;
      if (crossValidator != null) {
        try {
          // Reuse provided state or create a temporary one (O(1) wrapper)
          final tempState =
              validationState ??
              FormixData(
                values: currentValues,
                validations: currentValidations ?? state.validations,
                dirtyStates: state.dirtyStates,
                touchedStates: state.touchedStates,
              );
          final String? error = crossValidator(value, tempState);
          if (error != null) {
            finalResult = ValidationResult(
              isValid: false,
              errorMessage: _resolveErrorMessage(error, {
                'label': fieldDef.label ?? key,
                'value': value,
              }),
            );
          }
        } catch (e) {
          finalResult = ValidationResult(
            isValid: false,
            errorMessage: 'Cross-field validation error: ${e.toString()}',
          );
        }
      }
    }

    finalResult ??= ValidationResult.valid;

    if (sw != null) {
      sw.stop();
      _validationDurations[key] = sw.elapsed;
    }

    return finalResult;
  }

  String _resolveErrorMessage(String error, Map<String, dynamic> params) {
    if (error.startsWith('formix_key_')) {
      final parts = error.split(':');
      final key = parts[0];
      final param = parts.length > 1 ? parts[1] : null;

      final label = params['label']?.toString() ?? 'Field';

      switch (key) {
        case FormixValidationKeys.required:
          return messages.required(label);
        case FormixValidationKeys.invalidFormat:
          return messages.invalidFormat();
        case FormixValidationKeys.invalidEmail:
          // Fallback to invalidFormat if specific email message missing
          return messages.invalidFormat();
        case FormixValidationKeys.minLength:
          if (param != null) {
            return messages.minLength(label, int.tryParse(param) ?? 0);
          }
          break;
        case FormixValidationKeys.maxLength:
          if (param != null) {
            return messages.maxLength(label, int.tryParse(param) ?? 0);
          }
          break;
        case FormixValidationKeys.min:
          if (param != null) {
            return messages.minValue(label, num.tryParse(param) ?? 0);
          }
          break;
        case FormixValidationKeys.max:
          if (param != null) {
            return messages.maxValue(label, num.tryParse(param) ?? 0);
          }
          break;
      }
    }
    return messages.format(error, params);
  }

  void _startAsyncValidationTimer(String key, dynamic value) {
    final fieldDef = _fieldDefinitions[key];
    if (fieldDef == null) return;

    final asyncValidator = fieldDef.wrappedAsyncValidator;
    if (asyncValidator == null) return;

    _debouncers[key]?.cancel();

    _debouncers[key] = Timer(
      fieldDef.debounceDuration ?? const Duration(milliseconds: 300),
      () async {
        if (!mounted) return;
        final sw = kDebugMode ? (Stopwatch()..start()) : null;
        try {
          final error = await asyncValidator(value);
          if (sw != null) {
            sw.stop();
            _validationDurations[key] = sw.elapsed;
          }

          if (!mounted) return;

          final latestValidations = Map<String, ValidationResult>.from(
            state.validations,
          );
          final oldRes = latestValidations[key] ?? ValidationResult.valid;
          final newRes = error != null ? ValidationResult(isValid: false, errorMessage: error) : ValidationResult.valid;

          int newErrorCount = state.errorCount;
          if (oldRes.isValid && !newRes.isValid) {
            newErrorCount++;
          } else if (!oldRes.isValid && newRes.isValid) {
            // coverage:ignore-line — unreachable: a field awaiting async validation is in the `validating` (isValid=true) state, so oldRes is never invalid here
            newErrorCount--;
          }

          int newPendingCount = state.pendingCount;
          if (oldRes.isValidating) {
            newPendingCount--;
          }

          latestValidations[key] = newRes;

          state = state.copyWith(
            validations: latestValidations,
            errorCount: newErrorCount,
            pendingCount: newPendingCount,
            changedFields: {key},
          );
        } catch (e) {
          if (sw != null) {
            sw.stop();
            _validationDurations[key] = sw.elapsed;
          }

          if (!mounted) return;
          final latestValidations = Map<String, ValidationResult>.from(
            state.validations,
          );
          final oldRes = latestValidations[key] ?? ValidationResult.valid;
          final newRes = ValidationResult(
            isValid: false,
            errorMessage: 'Async validation error: $e',
          );

          int newErrorCount = state.errorCount;
          if (oldRes.isValid && !newRes.isValid) {
            newErrorCount++;
          }

          int newPendingCount = state.pendingCount;
          if (oldRes.isValidating) {
            newPendingCount--;
          }

          latestValidations[key] = newRes;
          state = state.copyWith(
            validations: latestValidations,
            errorCount: newErrorCount,
            pendingCount: newPendingCount,
            changedFields: {key},
          );
        }
      },
    );
  }

  /// Recursively collects all fields that depend on the source field.
  /// Implement BFS queue to handle deep chains and cycle detection.
  Set<String> _collectTransitiveDependents(String sourceKey) {
    final cached = _transitiveDependentsCache[sourceKey];
    if (cached != null) return cached;

    final result = <String>{};
    final queue = [sourceKey];
    final visited = {sourceKey};
    int head = 0;

    while (head < queue.length) {
      final currentKey = queue[head++];
      final directDependents = _dependentsMap[currentKey];
      if (directDependents == null) continue;

      for (final depKey in directDependents) {
        if (visited.add(depKey)) {
          result.add(depKey);
          queue.add(depKey);
        }
      }
    }
    _transitiveDependentsCache[sourceKey] = result;
    return result;
  }

  int _calculateErrorCount(Map<String, ValidationResult> validations) {
    int count = 0;
    for (final v in validations.values) {
      if (!v.isValid) count++;
    }
    return count;
  }

  int _calculateDirtyCount(Map<String, bool> dirtyStates) {
    int count = 0;
    for (final d in dirtyStates.values) {
      if (d) count++;
    }
    return count;
  }

  int _calculatePendingCount(
    Map<String, bool> pendingStates,
    Map<String, ValidationResult> validations,
  ) {
    int count = 0;
    for (final p in pendingStates.values) {
      if (p) count++;
    }
    for (final v in validations.values) {
      if (v.isValidating) count++;
    }
    return count;
  }

  /// Register multiple fields at once
  void registerFields(List<FormixField> fields) {
    if (fields.isEmpty) return;
    _transitiveDependentsCache.clear();
    final isNewMap = <String, bool>{};

    for (final field in fields) {
      final key = field.id.key;
      final isNew = !_fieldDefinitions.containsKey(key);
      isNewMap[key] = isNew;

      // Update dependency graph: Cleanup old dependencies
      if (_fieldDefinitions.containsKey(key)) {
        final oldField = _fieldDefinitions[key]!;
        for (final dep in oldField.dependsOn) {
          _dependentsMap[dep.key]?.remove(key);
        }
      }

      _validationDurations[key] = Duration.zero;

      _fieldDefinitions[key] = field;

      // Update dependency graph: Add new dependencies
      for (final dep in field.dependsOn) {
        _dependentsMap.putIfAbsent(dep.key, () => []).add(key);
      }

      if (isNew || field.initialValue != null) {
        if (field.initialValue != null || !initialValueMap.containsKey(key)) {
          initialValueMap[key] = field.initialValue;
        }
      }
    }

    void updateState() {
      if (!mounted) return;

      final newValues = {...state.values};
      final newValidations = {...state.validations};
      final newDirtyStates = {...state.dirtyStates};
      final newTouchedStates = {...state.touchedStates};

      for (final field in fields) {
        final key = field.id.key;

        // If it's a new field (or re-registering) and has an initial value,
        // we might want to apply it.
        // But we must respect if the user has already modified the value (dirty).
        // If the value exists and is DIRTY, we preserve it.
        // If the value exists and is CLEAN (or doesn't exist), we overwrite it with the new initial value.
        // This handles both "Override Global Initial Value" (Clean Global -> Local)
        // AND "Preserve Lazy State" (Dirty User Value -> Kept).
        final strategy = field.initialValueStrategy;
        final isNew = isNewMap[key] ?? false;

        if (field.initialValue != null) {
          final isDirty = newDirtyStates[key] ?? false;

          bool shouldAdopt = false;
          if (strategy == FormixInitialValueStrategy.preferLocal) {
            shouldAdopt = !newValues.containsKey(key) || !isDirty;
          } else {
            shouldAdopt = isNew;
          }

          if (shouldAdopt) {
            newValues[key] = field.initialValue;
          }
        }

        if (!newDirtyStates.containsKey(key)) {
          newDirtyStates[key] = false;
        }
        if (!newTouchedStates.containsKey(key)) {
          newTouchedStates[key] = false;
        }

        final rawMode = field.validationMode;
        final effectiveMode = rawMode == FormixAutovalidateMode.auto ? autovalidateMode : rawMode;

        if (effectiveMode == FormixAutovalidateMode.always) {
          newValidations[key] = _performSyncValidation(
            key,
            newValues[key],
            newValues,
            currentValidations: newValidations,
          );
        }
      }

      state = state.copyWith(
        values: newValues,
        validations: newValidations,
        dirtyStates: newDirtyStates,
        touchedStates: newTouchedStates,
        errorCount: _calculateErrorCount(newValidations),
        dirtyCount: _calculateDirtyCount(newDirtyStates),
        pendingCount: _calculatePendingCount(
          state.pendingStates,
          newValidations,
        ),
        changedFields: fields.map((f) => f.id.key).toSet(),
      );
    }

    bool isPersistent = false;
    try {
      final scheduler = WidgetsBinding.instance;
      isPersistent = scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks;
    } catch (_) {}

    if (isPersistent && _history.isNotEmpty) {
      Future.microtask(updateState);
    } else {
      updateState();
    }
  }

  /// Register a field
  void registerField<T>(FormixField<T> field) {
    registerFields([field]);
  }

  /// Unregister multiple fields at once
  void unregisterFields(
    List<FormixFieldID> fieldIds, {
    bool preserveState = false,
  }) {
    if (fieldIds.isEmpty) return;
    _transitiveDependentsCache.clear();

    final newValues = {...state.values};
    final newValidations = {...state.validations};
    final newDirtyStates = {...state.dirtyStates};
    final newTouchedStates = {...state.touchedStates};

    for (final fieldId in fieldIds) {
      final key = fieldId.key;

      // Update graph
      final oldField = _fieldDefinitions[key];
      if (oldField != null) {
        for (final dep in oldField.dependsOn) {
          _dependentsMap[dep.key]?.remove(key);
        }
      }
      _dependentsMap.remove(key);

      _fieldDefinitions.remove(key);
      newValidations.remove(key);

      if (!preserveState) {
        newValues.remove(key);
        newDirtyStates.remove(key);
        newTouchedStates.remove(key);
      }
    }

    state = state.copyWith(
      values: newValues,
      validations: newValidations,
      dirtyStates: newDirtyStates,
      touchedStates: newTouchedStates,
      errorCount: _calculateErrorCount(newValidations),
      dirtyCount: _calculateDirtyCount(newDirtyStates),
      pendingCount: _calculatePendingCount(state.pendingStates, newValidations),
      changedFields: fieldIds.map((e) => e.key).toSet(),
    );

    if (persistence != null && formId != null) {
      persistence!.saveFormState(formId!, newValues);
    }
  }

  /// Unregister a field
  void unregisterField<T>(
    FormixFieldID<T> fieldId, {
    bool preserveState = false,
  }) {
    final key = fieldId.key;
    _transitiveDependentsCache.clear();

    // Update graph
    final oldField = _fieldDefinitions[key];
    if (oldField != null) {
      for (final dep in oldField.dependsOn) {
        _dependentsMap[dep.key]?.remove(key);
      }
    }
    _dependentsMap.remove(key);

    _fieldDefinitions.remove(key);

    final newValues = {...state.values};
    final newValidations = {...state.validations};
    final newDirtyStates = {...state.dirtyStates};
    final newTouchedStates = {...state.touchedStates};

    newValidations.remove(key);

    if (!preserveState) {
      newValues.remove(key);
      newDirtyStates.remove(key);
      newTouchedStates.remove(key);
    }

    state = state.copyWith(
      values: newValues,
      validations: newValidations,
      dirtyStates: newDirtyStates,
      touchedStates: newTouchedStates,
      errorCount: _calculateErrorCount(newValidations),
      dirtyCount: _calculateDirtyCount(newDirtyStates),
      pendingCount: _calculatePendingCount(state.pendingStates, newValidations),
      changedFields: {key},
    );

    if (persistence != null && formId != null) {
      persistence!.saveFormState(formId!, newValues);
    }
  }

  /// Reset form to initial state or clear it
  void reset({
    ResetStrategy strategy = ResetStrategy.initialValues,
    bool clearErrors = false,
  }) {
    final Map<String, dynamic> newValues;
    if (strategy == ResetStrategy.initialValues) {
      newValues = {...initialValueMap};
    } else {
      newValues = {};
      for (final entry in _fieldDefinitions.entries) {
        newValues[entry.key] = entry.value.emptyValue ?? _getDefaultEmptyValue(entry.value);
      }
    }

    final newValidations = <String, ValidationResult>{};
    final newDirtyStates = <String, bool>{};

    for (final key in _fieldDefinitions.keys) {
      newDirtyStates[key] = false;
      if (clearErrors) {
        newValidations.remove(key);
      } else {
        newValidations[key] = _performSyncValidation(
          key,
          newValues[key],
          newValues,
        );
      }
    }

    final newTouchedStates = <String, bool>{};
    for (final key in _fieldDefinitions.keys) {
      newTouchedStates[key] = false;
    }

    // Cancel all pending async validations
    for (var timer in _debouncers.values) {
      timer.cancel();
    }
    _debouncers.clear();

    state = state.copyWith(
      values: newValues,
      validations: newValidations,
      dirtyStates: newDirtyStates,
      touchedStates: newTouchedStates,
      pendingStates: const {},
      isSubmitting: false,
      errorCount: _calculateErrorCount(newValidations),
      dirtyCount: _calculateDirtyCount(newDirtyStates),
      pendingCount: 0,
      resetCount: state.resetCount + 1,
      clearChangedFields: true,
    );

    if (persistence != null && formId != null) {
      persistence!.saveFormState(formId!, newValues);
    }
  }

  /// Resets the form and sets a new set of initial values.
  /// This clears all dirty and touched states.
  void resetToValues(Map<String, dynamic> data, {bool clearErrors = false}) {
    for (final entry in data.entries) {
      setInitialValueInternal(entry.key, entry.value);
    }
    reset(strategy: ResetStrategy.initialValues, clearErrors: clearErrors);
  }

  /// Reset specific fields
  void resetFields(
    List<FormixFieldID> fieldIds, {
    ResetStrategy strategy = ResetStrategy.initialValues,
    bool clearErrors = false,
  }) {
    final newValues = {...state.values};
    final newValidations = {...state.validations};
    final newDirtyStates = {...state.dirtyStates};
    final newTouchedStates = {...state.touchedStates};

    for (final fieldId in fieldIds) {
      final key = fieldId.key;
      final fieldDef = _fieldDefinitions[key];
      if (fieldDef == null) continue;

      final dynamic newValue;
      if (strategy == ResetStrategy.initialValues) {
        newValue = initialValueMap[key];
      } else {
        newValue = fieldDef.emptyValue ?? _getDefaultEmptyValue(fieldDef);
      }

      newValues[key] = newValue;
      newDirtyStates[key] = false;
      newTouchedStates[key] = false;

      // Cancel pending async validation for this field
      _debouncers[key]?.cancel();
      _debouncers.remove(key);

      if (clearErrors) {
        newValidations.remove(key);
      } else {
        newValidations[key] = _performSyncValidation(key, newValue, newValues);
      }
    }

    // Re-validate dependents of the reset fields
    final fieldsToRevalidate = <String>{};
    for (final fieldId in fieldIds) {
      fieldsToRevalidate.addAll(_collectTransitiveDependents(fieldId.key));
    }

    // Filter out fields that were already reset (and potentially cleared)
    final resetKeys = fieldIds.map((id) => id.key).toSet();
    fieldsToRevalidate.removeWhere((key) => resetKeys.contains(key));

    for (final key in fieldsToRevalidate) {
      final fieldDef = _fieldDefinitions[key];
      if (fieldDef == null) continue;

      final mode = getValidationMode(fieldDef.id);
      final isTouched = newTouchedStates[key] ?? false;
      final isDirty = newDirtyStates[key] ?? false;
      final wasValidated = newValidations.containsKey(key);

      if (mode == FormixAutovalidateMode.always ||
          (mode == FormixAutovalidateMode.onUserInteraction && (isDirty || isTouched || wasValidated)) ||
          (mode == FormixAutovalidateMode.onBlur && (isTouched || wasValidated))) {
        newValidations[key] = _performSyncValidation(
          key,
          newValues[key],
          newValues,
          currentValidations: newValidations,
        );
      }
    }

    state = state.copyWith(
      values: newValues,
      validations: newValidations,
      dirtyStates: newDirtyStates,
      touchedStates: newTouchedStates,
      errorCount: _calculateErrorCount(newValidations),
      dirtyCount: _calculateDirtyCount(newDirtyStates),
      pendingCount: _calculatePendingCount(state.pendingStates, newValidations),
      changedFields: fieldIds.map((id) => id.key).toSet(),
    );
  }

  /// Validate entire form
  /// Validate form (or specific fields)
  bool validate({List<FormixFieldID>? fields}) {
    final newValidations = Map<String, ValidationResult>.from(
      state.validations,
    );
    final newTouchedStates = Map<String, bool>.from(state.touchedStates);
    final values = state.values;
    final keysToValidate = (fields?.map((f) => f.key) ?? _fieldDefinitions.keys).toList();

    int newErrorCount = state.errorCount;
    int newPendingCount = state.pendingCount;
    final asyncToTrigger = <String, dynamic>{};

    for (final key in keysToValidate) {
      if (!_fieldDefinitions.containsKey(key)) continue;
      newTouchedStates[key] = true;
      final value = values[key];
      final oldRes = newValidations[key] ?? ValidationResult.valid;
      final syncRes = _performSyncValidation(
        key,
        value,
        values,
        currentValidations: newValidations,
      );

      final fieldDef = _fieldDefinitions[key];
      ValidationResult finalRes = syncRes;
      if (syncRes.isValid && fieldDef?.wrappedAsyncValidator != null) {
        finalRes = ValidationResult.validating;
        asyncToTrigger[key] = value;
      }

      if (oldRes != finalRes) {
        newValidations[key] = finalRes;

        // Update error count
        if (oldRes.isValid && !finalRes.isValid) {
          newErrorCount++;
        } else if (!oldRes.isValid && finalRes.isValid) {
          newErrorCount--;
        }

        // Update pending count
        if (!oldRes.isValidating && finalRes.isValidating) {
          newPendingCount++;
        } else if (oldRes.isValidating && !finalRes.isValidating) {
          newPendingCount--;
        }
      }
    }

    state = state.copyWith(
      validations: newValidations,
      touchedStates: newTouchedStates,
      errorCount: newErrorCount,
      pendingCount: newPendingCount,
      changedFields: keysToValidate.toSet(),
    );

    // Trigger timers after state update
    if (asyncToTrigger.isNotEmpty) {
      asyncToTrigger.forEach(_startAsyncValidationTimer);
    }

    if (fields != null) {
      return fields.every((f) => state.validations[f.key]?.isValid ?? true);
    }
    return state.isValid;
  }

  /// Sets the current step in a multi-step form.
  void goToStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  /// Increments the current step if the provided [fields] (or all current fields) are valid.
  ///
  /// Returns `true` if the transition was successful.
  bool nextStep({List<FormixFieldID>? fields, int? targetStep}) {
    final isValid = validate(fields: fields);
    if (isValid) {
      state = state.copyWith(currentStep: targetStep ?? (state.currentStep + 1));
      return true;
    }
    return false;
  }

  /// Decrements the current step.
  void previousStep({int? targetStep}) {
    state = state.copyWith(currentStep: targetStep ?? (state.currentStep - 1));
  }

  /// Validates a specific step by checking the validity of a list of fields.
  ///
  /// This is an alias for [validate] with specific fields.
  bool validateStep(List<FormixFieldID> fields) {
    return validate(fields: fields);
  }

  /// Sets a manual error for a specific field.
  ///
  /// This is highly useful for displaying backend validation errors or
  /// specialized business logic errors that cannot be defined in a static validator.
  void setFieldError<T>(FormixFieldID<T> fieldId, String? error) {
    if (!mounted) return;
    final key = fieldId.key;
    final currentValidations = {...state.validations};

    final oldRes = currentValidations[key] ?? ValidationResult.valid;
    final newRes = error != null ? ValidationResult(isValid: false, errorMessage: error) : ValidationResult.valid;

    currentValidations[key] = newRes;

    int newErrorCount = state.errorCount;
    if (oldRes.isValid && !newRes.isValid) {
      newErrorCount++;
    } else if (!oldRes.isValid && newRes.isValid) {
      newErrorCount--;
    }

    state = state.copyWith(
      validations: currentValidations,
      errorCount: newErrorCount,
      changedFields: {key},
    );
  }

  /// Applies a batch of backend/server validation errors in a single update.
  ///
  /// Keys are field keys ([FormixFieldID.key]); values are the error messages to
  /// display. This is the idiomatic way to surface API validation failures:
  /// ```dart
  /// try {
  ///   await api.save(controller.state.values);
  /// } on ApiValidationException catch (e) {
  ///   controller.applyServerErrors(e.fieldErrors); // {'email': 'Already taken'}
  /// }
  /// ```
  void applyServerErrors(Map<String, String> errors) {
    if (!mounted || errors.isEmpty) return;
    final currentValidations = {...state.validations};
    int newErrorCount = state.errorCount;

    for (final entry in errors.entries) {
      final oldRes = currentValidations[entry.key] ?? ValidationResult.valid;
      currentValidations[entry.key] = ValidationResult(isValid: false, errorMessage: entry.value);
      if (oldRes.isValid) newErrorCount++;
    }

    state = state.copyWith(
      validations: currentValidations,
      errorCount: newErrorCount,
      changedFields: errors.keys.toSet(),
    );
  }

  /// Manually set the validating state of a field.
  void setFieldValidating<T>(
    FormixFieldID<T> fieldId, {
    bool isValidating = true,
  }) {
    if (!mounted) return;
    final key = fieldId.key;
    final currentValidations = {...state.validations};

    final oldRes = currentValidations[key] ?? ValidationResult.valid;
    final newRes = isValidating ? ValidationResult.validating : (oldRes.isValidating ? ValidationResult.valid : oldRes);

    currentValidations[key] = newRes;

    int newErrorCount = state.errorCount;
    if (oldRes.isValid && !newRes.isValid) {
      // coverage:ignore-line — unreachable: newRes here is either `validating` (isValid=true) or a copy of oldRes, never valid->invalid
      newErrorCount++;
    } else if (!oldRes.isValid && newRes.isValid) {
      newErrorCount--;
    }

    int newPendingCount = state.pendingCount;
    if (!oldRes.isValidating && newRes.isValidating) {
      newPendingCount++;
    } else if (oldRes.isValidating && !newRes.isValidating) {
      newPendingCount--;
    }

    state = state.copyWith(
      validations: currentValidations,
      errorCount: newErrorCount,
      pendingCount: newPendingCount,
      changedFields: {key},
    );
  }

  /// Get validation result for field
  ValidationResult getValidation<T>(FormixFieldID<T> fieldId) {
    return state.getValidation(fieldId);
  }

  /// Check if field is dirty
  bool isFieldDirty<T>(FormixFieldID<T> fieldId) {
    return state.isFieldDirty(fieldId);
  }

  /// Check if field is touched
  bool isFieldTouched<T>(FormixFieldID<T> fieldId) {
    return state.isFieldTouched(fieldId);
  }

  /// Mark a field as touched
  void markAsTouched(FormixFieldID<dynamic> fieldId) {
    if (!isFieldRegistered(fieldId)) return;

    analytics?.onFieldTouched(formId, fieldId.key);

    if (state.touchedStates[fieldId.key] == true) return;

    _batchUpdate({}, touchedStates: {fieldId.key: true});
  }

  /// Submits the form with optional throttling and debouncing.
  /// Submits the form, performing validation and error handling.
  ///
  /// This method:
  /// 1.  Runs all synchronous and asynchronous validators.
  /// 2.  If [optimistic] is true, it calls [onValid] immediately if sync
  ///     validation passes, without waiting for async validators.
  /// 3.  If valid, calls [onValid] with the current form values.
  /// 4.  If invalid, calls [onError] with the validation failures.
  /// 5.  Handles [debounce] and [throttle] to prevent multiple submissions.
  ///
  /// Example:
  /// ```dart
  /// controller.submit(
  ///   onValid: (values) async {
  ///     await api.saveUser(values);
  ///     print('Saved!');
  ///   },
  ///   onError: (errors) => print('Fix these: $errors'),
  /// );
  /// ```
  Future<void> submit({
    required Future<void> Function(Map<String, dynamic> values) onValid,
    void Function(Map<String, ValidationResult> errors)? onError,
    Duration? debounce,
    Duration? throttle,
    bool optimistic = false,
    bool waitForPending = true,
  }) async {
    // 1. Throttling
    if (throttle != null) {
      final now = DateTime.now();
      if (_lastSubmitTime != null && now.difference(_lastSubmitTime!) < throttle) {
        return; // Too soon
      }
      _lastSubmitTime = now;
    }

    // 2. Debouncing
    if (debounce != null) {
      _submitDebounceTimer?.cancel();
      final completer = Completer<void>();

      _submitDebounceTimer = Timer(debounce, () async {
        try {
          await _performSubmit(
            onValid,
            onError,
            optimistic,
            waitForPending: waitForPending,
          );
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      });

      return completer.future;
    }

    // 3. Immediate execution
    await _performSubmit(
      onValid,
      onError,
      optimistic,
      waitForPending: waitForPending,
    );
  }

  Future<void> _performSubmit(
    Future<void> Function(Map<String, dynamic> values) onValid,
    void Function(Map<String, ValidationResult> errors)? onError,
    bool optimistic, {
    bool waitForPending = true,
  }) async {
    analytics?.onSubmitAttempt(formId, state.values);

    if (validate()) {
      setSubmitting(true);

      // Wait for any pending async validations or fields
      while (state.isPending) {
        await stream.first;
        // Yield to prevent "Controller already firing" error if stream is sync
        await Future<void>.delayed(Duration.zero);
      }

      // Re-validate after async completions
      if (!state.isValid) {
        setSubmitting(false);
        if (onError != null) {
          onError(state.validations);
        }
        analytics?.onSubmitFailure(formId, state.validations);
        return;
      }

      Map<String, dynamic>? previousInitialValues;
      FormixData? previousState;

      if (optimistic) {
        previousInitialValues = Map.from(initialValueMap);
        previousState = state;
        // Optimistically set the form to "pristine" by syncing initial values
        resetToValues(state.values);
        // resetToValues resets isSubmitting to false, so we enable it again
        setSubmitting(true);
      }

      try {
        await onValid(state.values);
        _hasSubmittedSuccessfully = true;
        analytics?.onSubmitSuccess(formId);
      } catch (e) {
        if (optimistic && previousInitialValues != null && previousState != null) {
          // Revert optimistic changes
          initialValueMap.clear();
          initialValueMap.addAll(previousInitialValues);
          state = previousState.copyWith(isSubmitting: false);
        }
        rethrow;
      } finally {
        setSubmitting(false);
      }
    } else {
      if (onError != null) {
        onError(state.validations);
      }
      analytics?.onSubmitFailure(formId, state.validations);
    }
  }

  /// Set submitting state
  void setSubmitting(bool submitting) {
    state = state.copyWith(isSubmitting: submitting);
  }

  dynamic _getDefaultEmptyValue(FormixField<dynamic> field) {
    final initialValue = field.initialValue;
    if (initialValue is String) return '';
    if (initialValue is num) return 0;
    if (initialValue is bool) return false;
    if (initialValue is List) return [];
    if (initialValue is Map) return {};
    return null;
  }

  // --- Undo / Redo ---

  /// Whether undo is currently possible
  bool get canUndo => _historyIndex > 0;

  /// Whether redo is currently possible
  bool get canRedo => _historyIndex < _history.length - 1;

  /// Undo the last change
  void undo() {
    if (!canUndo) return;

    _isRestoringHistory = true;
    try {
      _historyIndex--;
      state = _history[_historyIndex];
    } finally {
      _isRestoringHistory = false;
    }
  }

  /// Redo the previously undone change
  void redo() {
    if (!canRedo) return;

    _isRestoringHistory = true;
    try {
      _historyIndex++;
      state = _history[_historyIndex];
    } finally {
      _isRestoringHistory = false;
    }
  }

  // --- Optimistic Updates ---

  /// Manually set the pending state of a field
  void setPending<T>(FormixFieldID<T> fieldId, bool isPending) {
    if (!mounted) return;

    final newPendingStates = Map<String, bool>.from(state.pendingStates);
    final oldPending = newPendingStates[fieldId.key] ?? false;
    newPendingStates[fieldId.key] = isPending;

    int newPendingCount = state.pendingCount;
    if (!oldPending && isPending) {
      newPendingCount++;
    } else if (oldPending && !isPending) {
      newPendingCount--;
    }

    state = state.copyWith(
      pendingStates: newPendingStates,
      pendingCount: newPendingCount,
      changedFields: {fieldId.key},
    );
  }

  /// Perform an optimistic update.
  ///
  /// 1. Updates the field value immediately.
  /// 2. Sets field to pending.
  /// 3. Executes [action].
  /// 4. If [action] fails, reverts the value (optional).
  Future<void> optimisticUpdate<T>({
    required FormixFieldID<T> fieldId,
    required T value,
    required Future<void> Function() action,
    bool revertOnError = true,
  }) async {
    final previousValue = getValue(fieldId);

    // 1. Update immediately
    setValue(fieldId, value);

    // 2. Set pending
    setPending(fieldId, true);

    try {
      // 3. Execute action
      await action();
    } catch (e) {
      // 4. Revert if needed
      if (revertOnError && previousValue != null) {
        setValue(fieldId, previousValue);
      }
      rethrow;
    } finally {
      if (mounted) {
        setPending(fieldId, false);
      }
    }
  }

  // --- Multi-Form Synchronization ---

  /// Binds a field in this form to a field in another form controller.
  ///
  /// Changes in [sourceController]'s [sourceField] will automatically update
  /// [targetField] in this form.
  ///
  /// Returns a function to unbind.
  VoidCallback bindField<T>(
    FormixFieldID<T> targetField, {
    required FormixBaseController sourceController,
    required FormixFieldID<T> sourceField,
    bool twoWay = false,
  }) {
    final subKey = '${targetField.key}_bound_to_${sourceField.key}';

    // Unbind existing if any
    _bindings[subKey]?.cancel();

    // Subscribe to source
    _bindings[subKey] = sourceController.stream.listen((sourceState) {
      final sourceValue = sourceState.getValue(sourceField);
      final currentTargetValue = getValue(targetField);

      if (sourceValue != currentTargetValue) {
        setValue(targetField, sourceValue);
      }
    });

    // Add two-way binding if requested (be careful of infinite loops!)
    // We avoid loops by checking value equality before setting.
    if (twoWay) {
      final reverseSubKey = '${subKey}_reverse';
      _bindings[reverseSubKey] = stream.listen((targetState) {
        final targetValue = targetState.getValue(targetField);
        final currentSourceValue = sourceController.getValue(sourceField);

        if (targetValue != currentSourceValue) {
          sourceController.setValue(sourceField, targetValue);
        }
      });
    }

    return () {
      _bindings[subKey]?.cancel();
      _bindings.remove(subKey);
      if (twoWay) {
        _bindings['${subKey}_reverse']?.cancel();
        _bindings.remove('${subKey}_reverse');
      }
    };
  }
}

/// Immutable configuration used to create a [FormixController].
@immutable
class FormixParameter {
  /// Creates a [FormixParameter] for form initialization.
  const FormixParameter({
    this.initialValue = const {},
    this.fields = const [],
    this.persistence,
    this.formId,
    this.analytics,
    this.keepAlive = false,
    this.namespace,
    this.autovalidateMode = FormixAutovalidateMode.always,
    this.initialData,
    this.messages,
  });

  /// Optional custom messages for validation errors.
  final FormixMessages? messages;

  /// Initial values for the form fields.
  final Map<String, dynamic> initialValue;

  /// List of field configurations.
  final List<FormixFieldConfig> fields;

  /// Optional persistence provider.
  final FormixPersistence? persistence;

  /// Optional unique identifier for the form.
  final String? formId;

  /// Optional analytics provider.
  final FormixAnalytics? analytics;

  /// Whether to keep the provider alive even when not watched.
  final bool keepAlive;

  /// Optional namespace for persistence.
  final String? namespace;

  /// Global validation mode for the form.
  final FormixAutovalidateMode autovalidateMode;

  /// Optional initial state for the form.
  final FormixData? initialData;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FormixParameter) return false;

    // Use deep equality for maps and initial data
    const deepEquals = DeepCollectionEquality();

    return formId == other.formId &&
        namespace == other.namespace &&
        messages == other.messages &&
        autovalidateMode == other.autovalidateMode &&
        keepAlive == other.keepAlive &&
        deepEquals.equals(initialData, other.initialData) &&
        (formId != null ? true : deepEquals.equals(initialValue, other.initialValue)) &&
        ((formId != null || namespace != null) ? true : deepEquals.equals(fields, other.fields));
  }

  @override
  int get hashCode {
    const deepEquals = DeepCollectionEquality();
    return Object.hash(
      formId,
      namespace,
      messages,
      autovalidateMode,
      keepAlive,
      formId != null ? null : deepEquals.hash(initialValue),
      (formId != null || namespace != null) ? null : deepEquals.hash(fields),
      deepEquals.hash(initialData),
    );
  }

  @override
  String toString() {
    return 'FormixParameter(formId: $formId, namespace: $namespace, keepAlive: $keepAlive, autovalidateMode: $autovalidateMode, initialValue: $initialValue)';
  }
}
