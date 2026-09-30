import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'formix_base_controller.dart';
import 'field_id.dart';
import 'field.dart';
import 'validation.dart';
import '../enums.dart';
import '../persistence/form_persistence.dart';
import '../analytics/form_analytics.dart';
import '../i18n.dart';
import 'batch.dart';

/// The form controller: the object you hold to drive a form.
///
/// State lives in a single [Signal] (see [FormixBaseController]); this class adds
/// fine-grained [Computed] slices ([valueSignal], [validationSignal], …) for
/// surgical widget rebuilds, plus focus/scroll/accessibility helpers and a
/// [ValueNotifier]/[ValueListenable] compatibility layer for non-signal widgets.
class FormixController extends FormixBaseController {
  /// Creates a [FormixController] with optional configuration.
  FormixController({
    Map<String, dynamic> initialValue = const {},
    List<dynamic> fields = const [],
    FormixPersistence? persistence,
    String? formId,
    FormixAnalytics? analytics,
    bool keepAlive = false,
    String? namespace,
    FormixAutovalidateMode autovalidateMode = FormixAutovalidateMode.always,
    FormixData? initialData,
    FormixMessages? messages,
  }) : super(
         FormixParameter(
           initialValue: initialValue,
           messages: messages,
           fields: fields.map<FormixFieldConfig>((f) {
             if (f is FormixFieldConfig) return f;
             if (f is FormixField) {
               return f.toConfig();
             }
             throw ArgumentError('Invalid field type: ${f.runtimeType}');
           }).toList(),
           persistence: persistence,
           formId: formId,
           analytics: analytics,
           keepAlive: keepAlive,
           namespace: namespace,
           autovalidateMode: autovalidateMode,
           initialData: initialData,
         ),
       );

  /// Creates a [FormixController] directly from a [FormixParameter].
  FormixController.fromParameter(super.parameter);

  // --- Reactive slices (surgical rebuilds) ---
  // A widget reading a slice inside a `SignalBuilder` only rebuilds when THAT
  // slice's value changes.
  //
  // Per-field slices are plain [Signal]s kept in sync via the `changedFields`
  // delta in [onStateChanged], so a single field update only touches that field's
  // signals — O(changed) — instead of re-evaluating every mounted watcher.
  // Raw per-field value signals (type-erased), updated via the changedFields
  // delta. Kept dynamic so a field's runtime type can change without a cast error.
  final Map<String, Signal<dynamic>> _valueSignals = {};
  // Typed, type-change-safe views over the raw value signals, cached per (key, T).
  final Map<String, ReadonlySignal<dynamic>> _valueViews = {};
  final Map<String, Signal<ValidationResult>> _validationSignals = {};
  final Map<String, Signal<bool>> _dirtySignals = {};
  final Map<String, Signal<bool>> _touchedSignals = {};
  final Map<String, Signal<bool>> _pendingSignals = {};
  // Group + form-level slices are computed over the whole state (rare, and O(1)
  // to evaluate), so a plain computed is the right tool.
  final Map<String, ReadonlySignal<bool>> _groupValidSignals = {};
  final Map<String, ReadonlySignal<bool>> _groupDirtySignals = {};
  ReadonlySignal<bool>? _isValidSignal;
  ReadonlySignal<bool>? _isDirtySignal;
  ReadonlySignal<bool>? _isSubmittingSignal;
  ReadonlySignal<bool>? _isPendingSignal;
  ReadonlySignal<int>? _currentStepSignal;

  /// Reactive value of a field. Read `.value` inside a [SignalBuilder] for a
  /// rebuild that fires only when this field's value changes.
  ///
  /// Type-change safe: the value is stored type-erased, and this returns a view
  /// typed as `T?` that yields the value when it matches `T` (else null). A field
  /// can therefore change its runtime type without ever throwing a cast error.
  ReadonlySignal<T?> valueSignal<T>(FormixFieldID<T> id) {
    final raw = _valueSignals.putIfAbsent(id.key, () => signal<dynamic>(stateSignal.peek().values[id.key]));
    final viewKey = '${id.key}/$T';
    final existing = _valueViews[viewKey];
    if (existing != null) return existing as ReadonlySignal<T?>;
    final view = computed<T?>(() {
      final v = raw.value;
      return v is T ? v : null;
    });
    _valueViews[viewKey] = view;
    return view;
  }

  /// Reactive validation result of a field.
  ReadonlySignal<ValidationResult> validationSignal<T>(FormixFieldID<T> id) => _validationSignals.putIfAbsent(id.key, () => signal(stateSignal.peek().getValidation(id)));

  /// Reactive dirty flag of a field.
  ReadonlySignal<bool> dirtySignal<T>(FormixFieldID<T> id) => _dirtySignals.putIfAbsent(id.key, () => signal(stateSignal.peek().isFieldDirty(id)));

  /// Reactive touched flag of a field.
  ReadonlySignal<bool> touchedSignal<T>(FormixFieldID<T> id) => _touchedSignals.putIfAbsent(id.key, () => signal(stateSignal.peek().isFieldTouched(id)));

  /// Reactive pending (async) flag of a field.
  ReadonlySignal<bool> pendingSignal<T>(FormixFieldID<T> id) => _pendingSignals.putIfAbsent(id.key, () => signal(stateSignal.peek().isFieldPending(id)));

  /// Reactive validity of a field-name group (e.g. `'user'`).
  ReadonlySignal<bool> groupValidSignal(String prefix) => _groupValidSignals.putIfAbsent(prefix, () => computed(() => state.isGroupValid(prefix)));

  /// Reactive dirtiness of a field-name group.
  ReadonlySignal<bool> groupDirtySignal(String prefix) => _groupDirtySignals.putIfAbsent(prefix, () => computed(() => state.isGroupDirty(prefix)));

  /// Reactive form validity.
  ReadonlySignal<bool> get isValidSignal => _isValidSignal ??= computed(() => state.isValid);

  /// Reactive form dirtiness.
  ReadonlySignal<bool> get isDirtySignal => _isDirtySignal ??= computed(() => state.isDirty);

  /// Reactive submitting flag.
  ReadonlySignal<bool> get isSubmittingSignal => _isSubmittingSignal ??= computed(() => state.isSubmitting);

  /// Reactive pending (any async in-flight) flag.
  ReadonlySignal<bool> get isPendingSignal => _isPendingSignal ??= computed(() => state.isPending);

  /// Reactive current step (multi-step forms).
  ReadonlySignal<int> get currentStepSignal => _currentStepSignal ??= computed(() => state.currentStep);

  // --- Derived signals & reactive UI flags (signals-native extras) ---

  final List<ReadonlySignal<dynamic>> _derivedSignals = [];
  final Map<String, Signal<bool>> _enabledSignals = {};
  final Map<String, Signal<bool>> _readOnlySignals = {};
  final Map<String, Signal<bool>> _visibleSignals = {};
  final Map<String, ReadonlySignal<dynamic>> _debouncedSignals = {};
  final List<VoidCallback> _debouncedDisposers = [];

  /// Creates a memoized, read-only signal derived from the whole form [state].
  ///
  /// Read `.value` inside a [SignalBuilder] to rebuild only when the derived
  /// value changes. Example:
  /// ```dart
  /// final total = controller.derived((s) => s.getValue(qtyId)! * s.getValue(priceId)!);
  /// ```
  ReadonlySignal<R> derived<R>(R Function(FormixData state) compute) {
    final c = computed(() => compute(state));
    _derivedSignals.add(c);
    return c;
  }

  /// A debounced view of a field's value: it only emits [duration] after the
  /// field stops changing. Ideal for search-as-you-type. Cached per (field, duration).
  ReadonlySignal<T?> debouncedValueSignal<T>(FormixFieldID<T> id, Duration duration) {
    final key = '${id.key}@${duration.inMicroseconds}';
    final existing = _debouncedSignals[key];
    if (existing != null) return existing as ReadonlySignal<T?>;

    final source = valueSignal(id);
    final out = signal<T?>(source.peek());
    Timer? timer;
    final disposeEffect = effect(() {
      final v = source.value;
      timer?.cancel();
      timer = Timer(duration, () => out.value = v);
    });
    _debouncedSignals[key] = out;
    _debouncedDisposers.add(() {
      timer?.cancel();
      disposeEffect();
      out.dispose();
    });
    return out;
  }

  /// Reactive "enabled" flag for a field (default true). Built-in field widgets
  /// combine this with their own `enabled` property.
  ReadonlySignal<bool> enabledSignal<T>(FormixFieldID<T> id) => _enabledSignals.putIfAbsent(id.key, () => signal(true));

  /// Reactive "read-only" flag for a field (default false).
  ReadonlySignal<bool> readOnlySignal<T>(FormixFieldID<T> id) => _readOnlySignals.putIfAbsent(id.key, () => signal(false));

  /// Reactive "visible" flag for a field (default true). Watch it (e.g. in a
  /// [FormixBuilder]) to show/hide fields reactively.
  ReadonlySignal<bool> visibleSignal<T>(FormixFieldID<T> id) => _visibleSignals.putIfAbsent(id.key, () => signal(true));

  /// Enable/disable a field reactively.
  void setEnabled<T>(FormixFieldID<T> id, bool enabled) => _enabledSignals.putIfAbsent(id.key, () => signal(true)).value = enabled;

  /// Mark a field read-only (or not) reactively.
  void setReadOnly<T>(FormixFieldID<T> id, bool readOnly) => _readOnlySignals.putIfAbsent(id.key, () => signal(false)).value = readOnly;

  /// Show/hide a field reactively.
  void setVisible<T>(FormixFieldID<T> id, bool visible) => _visibleSignals.putIfAbsent(id.key, () => signal(true)).value = visible;

  /// Adds a listener to be notified when the form state changes.
  VoidCallback addListener(void Function(FormixData) listener, {bool fireImmediately = true}) {
    final removeListenerFunc = addFormListener(listener);
    if (fireImmediately) {
      try {
        listener(state);
      } catch (_) {}
    }
    return removeListenerFunc;
  }

  /// Removes a previously registered listener.
  void removeListener(void Function(FormixData) listener) {
    removeFormListener(listener);
  }

  // Cache notifiers to ensure consistency
  final Map<String, ValueNotifier<dynamic>> _valueNotifiers = {};
  final Map<String, ValueNotifier<ValidationResult>> _validationNotifiers = {};
  final Map<String, ValueNotifier<bool>> _dirtyNotifiers = {};
  final Map<String, ValueNotifier<bool>> _touchedNotifiers = {};

  // Combined notifiers for performance optimization
  final Map<String, _FieldStateNotifier> _combinedFieldNotifiers = {};

  ValueNotifier<bool>? _isDirtyNotifier;
  ValueNotifier<bool>? _isValidNotifier;
  ValueNotifier<bool>? _isSubmittingNotifier;
  ValueNotifier<bool>? _isPendingNotifier;

  /// Pushes the latest state into the per-field signal slices. Uses the
  /// `changedFields` delta for O(changed) updates; falls back to syncing every
  /// live slice when the delta is absent (e.g. reset / initial load).
  void _syncFieldSignals(FormixData state, Set<String>? changedKeys) {
    void sync<T>(Map<String, Signal<T>> signals, T Function(String key) read) {
      if (signals.isEmpty) return;
      final keys = changedKeys != null ? changedKeys.where(signals.containsKey) : signals.keys;
      for (final key in keys) {
        signals[key]!.value = read(key);
      }
    }

    batch(() {
      sync<dynamic>(_valueSignals, (k) => state.values[k]);
      sync<ValidationResult>(_validationSignals, (k) => state.validations[k] ?? ValidationResult.valid);
      sync<bool>(_dirtySignals, (k) => state.dirtyStates[k] ?? false);
      sync<bool>(_touchedSignals, (k) => state.touchedStates[k] ?? false);
      sync<bool>(_pendingSignals, (k) => state.pendingStates[k] ?? false);
    });
  }

  @override
  void onStateChanged(FormixData state) {
    super.onStateChanged(state);
    // Optimization: If changedFields is present, only update notifiers for those keys.
    // If null, we fall back to checking all cached notifiers (e.g. initial load).
    final changedKeys = state.changedFields;

    // Sync the per-field reactive slices from the delta, coalesced into a single
    // batch so dependent widgets rebuild at most once per state change.
    _syncFieldSignals(state, changedKeys);

    // Helper to update a specific notifier map
    void updateNotifiers<T>(
      Map<String, ValueNotifier<T>> notifiers,
      T Function(String key) getValue,
    ) {
      if (notifiers.isEmpty) return;

      // If we have a delta, only check relevant keys that we are actually listening to
      final keysToCheck = changedKeys != null ? changedKeys.where((k) => notifiers.containsKey(k)) : notifiers.keys;

      for (final key in keysToCheck) {
        final notifier = notifiers[key];
        if (notifier == null) continue;

        final newValue = getValue(key);
        if (notifier.value != newValue) {
          notifier.value = newValue;
        }
      }
    }

    // Update value notifiers
    updateNotifiers(_valueNotifiers, (key) => state.values[key]);

    // Update validation notifiers
    updateNotifiers(
      _validationNotifiers,
      (key) => state.validations[key] ?? ValidationResult.valid,
    );

    // Update dirty notifiers
    updateNotifiers(_dirtyNotifiers, (key) => state.dirtyStates[key] ?? false);

    // Update touched notifiers
    updateNotifiers(
      _touchedNotifiers,
      (key) => state.touchedStates[key] ?? false,
    );

    // Update global notifiers
    if (_isDirtyNotifier != null && _isDirtyNotifier!.value != state.isDirty) {
      _isDirtyNotifier!.value = state.isDirty;
    }
    if (_isValidNotifier != null && _isValidNotifier!.value != state.isValid) {
      _isValidNotifier!.value = state.isValid;
    }
    if (_isSubmittingNotifier != null && _isSubmittingNotifier!.value != state.isSubmitting) {
      _isSubmittingNotifier!.value = state.isSubmitting;
    }
    if (_isPendingNotifier != null && _isPendingNotifier!.value != state.isPending) {
      _isPendingNotifier!.value = state.isPending;
    }

    // Call legacy listeners
    // Optimization: Only notify listeners for fields that actually changed
    // If changedKeys is null (e.g. initial), notify all.
    if (changedKeys != null) {
      for (final key in changedKeys) {
        final listeners = _fieldListeners[key];
        if (listeners != null) {
          for (final listener in listeners) {
            listener();
          }
        }
      }
    } else {
      // Notify all
      for (final listeners in _fieldListeners.values) {
        for (final listener in listeners) {
          listener();
        }
      }
    }
    for (final listener in _dirtyListeners) {
      listener(state.isDirty);
    }
  }

  /// Whether the form is currently being submitted.
  @override
  bool get isSubmitting => state.isSubmitting;

  /// Whether any field in the form has been modified.
  bool get isDirty => state.isDirty;

  /// Map of all current field keys to their values.
  Map<String, dynamic> get values => state.values;

  /// Map of all current field keys to their error messages.
  @override
  Map<String, String> get errors => state.errors;

  /// List of all current validation error messages.
  @override
  List<String> get errorMessages => state.errorMessages;

  /// Resets the form to its initial state.
  @override
  void reset({
    ResetStrategy strategy = ResetStrategy.initialValues,
    bool clearErrors = false,
  }) {
    super.reset(strategy: strategy, clearErrors: clearErrors);
  }

  /// Submits the form with automatic focus support on validation failure.
  @override
  Future<void> submit({
    required Future<void> Function(Map<String, dynamic> values) onValid,
    void Function(Map<String, ValidationResult> errors)? onError,
    Duration? debounce,
    Duration? throttle,
    bool optimistic = false,
    bool autoFocusOnInvalid = true,
    bool waitForPending = true,
  }) async {
    await super.submit(
      onValid: onValid,
      onError: (errors) {
        if (autoFocusOnInvalid) {
          focusFirstError();
        }
        announceErrors();
        onError?.call(errors);
      },
      debounce: debounce,
      throttle: throttle,
      optimistic: optimistic,
      waitForPending: waitForPending,
    );
  }

  /// Disposes all created notifiers and listeners.
  @override
  void dispose() {
    if (preventDisposal) return;
    for (final notifier in _valueNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _validationNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _dirtyNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _touchedNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _combinedFieldNotifiers.values) {
      notifier.dispose();
    }
    _isDirtyNotifier?.dispose();
    _isValidNotifier?.dispose();
    _isSubmittingNotifier?.dispose();
    _isPendingNotifier?.dispose();

    // Tear down debounced-signal timers/effects first.
    for (final d in _debouncedDisposers) {
      d();
    }
    _debouncedDisposers.clear();
    _debouncedSignals.clear();

    // Dispose reactive slices (per-field signals + group/form-level computeds +
    // derived signals + reactive UI-flag signals).
    for (final ReadonlySignal<dynamic>? c in <ReadonlySignal<dynamic>?>[
      ..._valueSignals.values,
      ..._valueViews.values,
      ..._validationSignals.values,
      ..._dirtySignals.values,
      ..._touchedSignals.values,
      ..._pendingSignals.values,
      ..._groupValidSignals.values,
      ..._groupDirtySignals.values,
      ..._derivedSignals,
      ..._enabledSignals.values,
      ..._readOnlySignals.values,
      ..._visibleSignals.values,
      _isValidSignal,
      _isDirtySignal,
      _isSubmittingSignal,
      _isPendingSignal,
      _currentStepSignal,
    ]) {
      c?.dispose();
    }

    _focusNodes.clear();
    _contexts.clear();

    super.dispose();
  }

  /// Returns a [ValueNotifier] for the value of the specified field.
  ValueNotifier<T?> getFieldNotifier<T>(FormixFieldID<T> fieldId) {
    if (_valueNotifiers.containsKey(fieldId.key)) {
      return _valueNotifiers[fieldId.key] as ValueNotifier<T?>;
    }
    final notifier = ValueNotifier<T?>(getValue(fieldId));
    _valueNotifiers[fieldId.key] = notifier;
    return notifier;
  }

  /// Returns a [ValueListenable] for the value of the specified field.
  ValueListenable<T?> fieldValueListenable<T>(FormixFieldID<T> fieldId) {
    return getFieldNotifier(fieldId);
  }

  /// Returns a [ValueNotifier] for the validation result of the specified field.
  ValueNotifier<ValidationResult> fieldValidationNotifier<T>(
    FormixFieldID<T> fieldId,
  ) {
    if (_validationNotifiers.containsKey(fieldId.key)) {
      return _validationNotifiers[fieldId.key]!;
    }
    final notifier = ValueNotifier<ValidationResult>(getValidation(fieldId));
    _validationNotifiers[fieldId.key] = notifier;
    return notifier;
  }

  /// Returns a [ValueNotifier] for the dirty status of the specified field.
  ValueNotifier<bool> fieldDirtyNotifier<T>(FormixFieldID<T> fieldId) {
    if (_dirtyNotifiers.containsKey(fieldId.key)) {
      return _dirtyNotifiers[fieldId.key]!;
    }
    final notifier = ValueNotifier<bool>(isFieldDirty(fieldId));
    _dirtyNotifiers[fieldId.key] = notifier;
    return notifier;
  }

  /// Returns a [ValueNotifier] for the touched status of the specified field.
  ValueNotifier<bool> fieldTouchedNotifier<T>(FormixFieldID<T> fieldId) {
    if (_touchedNotifiers.containsKey(fieldId.key)) {
      return _touchedNotifiers[fieldId.key]!;
    }
    final notifier = ValueNotifier<bool>(isFieldTouched(fieldId));
    _touchedNotifiers[fieldId.key] = notifier;
    return notifier;
  }

  /// A [ValueNotifier] that tracks whether the form is dirty.
  ValueNotifier<bool> get isDirtyNotifier {
    _isDirtyNotifier ??= ValueNotifier(state.isDirty);
    return _isDirtyNotifier!;
  }

  /// A [ValueNotifier] that tracks whether the form is valid.
  ValueNotifier<bool> get isValidNotifier {
    _isValidNotifier ??= ValueNotifier(state.isValid);
    return _isValidNotifier!;
  }

  /// A [ValueNotifier] that tracks whether the form is submitting.
  ValueNotifier<bool> get isSubmittingNotifier {
    _isSubmittingNotifier ??= ValueNotifier(state.isSubmitting);
    return _isSubmittingNotifier!;
  }

  /// A [ValueNotifier] that tracks whether any field is in a pending state.
  ValueNotifier<bool> get isPendingNotifier {
    _isPendingNotifier ??= ValueNotifier(state.isPending);
    return _isPendingNotifier!;
  }

  // Focus Management
  final Map<String, FocusNode> _focusNodes = {};

  /// Registers a [FocusNode] to be associated with a specific field.
  /// Typically called by field widgets in their `initState`.
  void registerFocusNode<T>(FormixFieldID<T> fieldId, FocusNode node) {
    _focusNodes[fieldId.key] = node;
  }

  /// Requests focus for the specified field.
  void focusField<T>(FormixFieldID<T> id) {
    _focusNodes[id.key]?.requestFocus();
  }

  /// Focuses the next registered field relative to the current one.
  void focusNextField<T>(FormixFieldID<T> currentId) {
    final keys = _focusNodes.keys.toList();
    final currentIndex = keys.indexOf(currentId.key);
    if (currentIndex != -1 && currentIndex < keys.length - 1) {
      _focusNodes[keys[currentIndex + 1]]?.requestFocus();
    }
  }

  final Map<String, BuildContext> _contexts = {};

  /// Registers a [BuildContext] for a field, primarily for programmatic scrolling.
  void registerContext<T>(FormixFieldID<T> id, BuildContext context) {
    _contexts[id.key] = context;
  }

  /// Scrolls the UI to ensure the specified field is visible.
  void scrollToField<T>(
    FormixFieldID<T> id, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double alignment = 0.5,
    ScrollPositionAlignmentPolicy alignmentPolicy = ScrollPositionAlignmentPolicy.explicit,
    ScrollController? scrollController,
  }) {
    final context = _contexts[id.key];
    if (context != null && context.mounted) {
      if (scrollController != null && scrollController.hasClients) {
        scrollController.position.ensureVisible(
          context.findRenderObject()!,
          duration: duration,
          curve: curve,
          alignment: alignment,
          alignmentPolicy: alignmentPolicy,
        );
      } else {
        Scrollable.ensureVisible(
          context,
          duration: duration,
          curve: curve,
          alignment: alignment,
          alignmentPolicy: alignmentPolicy,
        );
      }
    }
  }

  /// Focuses the first field that currently has a validation error.
  /// Also scrolls to make the field visible if a context is registered.
  void focusFirstError({
    Duration scrollDuration = const Duration(milliseconds: 300),
    Curve scrollCurve = Curves.easeInOut,
    double alignment = 0.2, // Show field near top for better visibility
    ScrollPositionAlignmentPolicy alignmentPolicy = ScrollPositionAlignmentPolicy.explicit,
    ScrollController? scrollController,
  }) {
    for (final entry in state.validations.entries) {
      if (!entry.value.isValid) {
        // Scroll to the field first
        scrollToField(
          FormixFieldID<dynamic>(entry.key),
          duration: scrollDuration,
          curve: scrollCurve,
          alignment: alignment,
          alignmentPolicy: alignmentPolicy,
          scrollController: scrollController,
        );

        // Then focus it
        _focusNodes[entry.key]?.requestFocus();
        return;
      }
    }
  }

  /// Announces the first validation error to assistive technologies.
  ///
  /// This is important for accessibility (a11y) so that screen reader users
  /// are notified when a form submission fails due to validation errors.
  void announceErrors() {
    final firstErrorKey = state.validations.entries.where((e) => !e.value.isValid).firstOrNull?.key;

    if (firstErrorKey != null) {
      final error = state.validations[firstErrorKey]?.errorMessage;
      final context = _contexts[firstErrorKey];

      if (error != null && context != null && context.mounted) {
        final view = View.of(context);
        final directionality = Directionality.of(context);

        SemanticsService.sendAnnouncement(
          view,
          error,
          directionality,
          assertiveness: Assertiveness.assertive,
        );
      }
    }
  }

  /// Returns an unmodifiable map of all current field values.
  Map<String, dynamic> toMap() => Map.unmodifiable(state.values);

  /// Returns a map containing only the values of fields that have been changed.
  Map<String, dynamic> getChangedValues() {
    final result = <String, dynamic>{};
    for (final entry in state.dirtyStates.entries) {
      if (entry.value) {
        result[entry.key] = state.values[entry.key];
      }
    }
    return result;
  }

  /// Updates multiple field values at once.
  /// This triggers validation for updated fields and is more efficient than
  /// multiple [setValue] calls.
  @override
  FormixBatchResult setValues(
    Map<FormixFieldID, dynamic> updates, {
    bool strict = false,
  }) {
    return super.setValues(updates, strict: strict);
  }

  /// Updates multiple field values using a type-safe [FormixBatch].
  @override
  FormixBatchResult applyBatch(FormixBatch batch, {bool strict = false}) {
    return super.applyBatch(batch, strict: strict);
  }

  /// Updates multiple field values from a raw map.
  FormixBatchResult updateFromMap(Map<String, dynamic> data) {
    final updates = <FormixFieldID, dynamic>{};
    for (final entry in data.entries) {
      final fieldId = FormixFieldID<dynamic>(entry.key);
      if (isFieldRegistered(fieldId)) {
        updates[fieldId] = entry.value;
      }
    }
    return setValues(updates);
  }

  /// Resets specific fields to their initial values or clears them.
  @override
  void resetFields(
    List<FormixFieldID> fieldIds, {
    ResetStrategy strategy = ResetStrategy.initialValues,
    bool clearErrors = false,
  }) {
    super.resetFields(fieldIds, strategy: strategy, clearErrors: clearErrors);
  }

  /// Resets the form and sets a new set of initial values.
  /// This clears all dirty and touched states.
  @override
  void resetToValues(Map<String, dynamic> data, {bool clearErrors = false}) {
    super.resetToValues(data, clearErrors: clearErrors);
  }

  // Listener management for compatibility
  final _fieldListeners = <String, List<VoidCallback>>{};
  final _dirtyListeners = <void Function(bool)>{};

  /// Adds a listener that will be called whenever any field value changes.
  void addFieldListener<T>(FormixFieldID<T> fieldId, VoidCallback listener) {
    if (!_fieldListeners.containsKey(fieldId.key)) {
      _fieldListeners[fieldId.key] = [];
    }
    _fieldListeners[fieldId.key]!.add(listener);
  }

  /// Removes a field listener.
  void removeFieldListener<T>(FormixFieldID<T> fieldId, VoidCallback listener) {
    if (_fieldListeners.containsKey(fieldId.key)) {
      _fieldListeners[fieldId.key]!.remove(listener);
      if (_fieldListeners[fieldId.key]!.isEmpty) {
        _fieldListeners.remove(fieldId.key);
      }
    }
  }

  /// Adds a listener specifically for changes to the form's dirty state.
  void addDirtyListener(void Function(bool) listener) {
    _dirtyListeners.add(listener);
  }

  /// Removes a dirty state listener.
  void removeDirtyListener(void Function(bool) listener) {
    _dirtyListeners.remove(listener);
  }

  /// Returns a combined [Listenable] that notifies when any field state changes.
  ///
  /// This is more efficient than merging multiple listenables in AnimatedBuilder.
  /// It combines validation, touched, dirty, and submitting state into a single notifier.
  Listenable getFieldStateNotifier<T>(FormixFieldID<T> fieldId) {
    if (_combinedFieldNotifiers.containsKey(fieldId.key)) {
      return _combinedFieldNotifiers[fieldId.key]!;
    }

    final notifier = _FieldStateNotifier(
      validationNotifier: fieldValidationNotifier(fieldId),
      touchedNotifier: fieldTouchedNotifier(fieldId),
      dirtyNotifier: fieldDirtyNotifier(fieldId),
      submittingNotifier: isSubmittingNotifier,
    );

    _combinedFieldNotifiers[fieldId.key] = notifier;
    return notifier;
  }

  @override
  String toString() {
    return 'FormixController(fields: ${state.values.keys.toList()}, isValid: ${state.isValid}, isDirty: ${state.isDirty})';
  }
}

/// A combined notifier that listens to multiple field state notifiers.
///
/// This reduces the overhead of merging multiple listenables in AnimatedBuilder.
class _FieldStateNotifier extends ChangeNotifier {
  _FieldStateNotifier({
    required this.validationNotifier,
    required this.touchedNotifier,
    required this.dirtyNotifier,
    required this.submittingNotifier,
  }) {
    validationNotifier.addListener(_notify);
    touchedNotifier.addListener(_notify);
    dirtyNotifier.addListener(_notify);
    submittingNotifier.addListener(_notify);
  }

  final ValueNotifier<ValidationResult> validationNotifier;
  final ValueNotifier<bool> touchedNotifier;
  final ValueNotifier<bool> dirtyNotifier;
  final ValueNotifier<bool> submittingNotifier;

  void _notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    validationNotifier.removeListener(_notify);
    touchedNotifier.removeListener(_notify);
    dirtyNotifier.removeListener(_notify);
    submittingNotifier.removeListener(_notify);
    super.dispose();
  }
}
