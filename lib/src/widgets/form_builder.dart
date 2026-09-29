import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../../formix.dart';
import 'ancestor_validator.dart';

/// A comprehensive toolset for interacting with [Formix] state and logic.
///
/// [FormixScope] provides reactive accessors (for watching changes) and
/// action methods (for triggering logic). The `watch*` accessors read the
/// controller's [Signal]/[Computed] slices, so — when called inside a
/// [FormixBuilder] (which builds within a [SignalBuilder]) — the widget rebuilds
/// only when the specific slice you read changes.
class FormixScope {
  /// The [BuildContext] of the widget.
  final BuildContext context;

  /// The [FormixController] instance for the current form.
  final FormixController controller;

  /// Creates a [FormixScope].
  FormixScope({
    required this.context,
    required this.controller,
  });

  // --- Reactive Accessors (read signal slices; reactive inside a SignalBuilder) ---

  /// Watch a specific field's value.
  ///
  /// Only rebuilds the widget when this specific field's value changes.
  T? watchValue<T>(FormixFieldID<T> id) => controller.valueSignal(id).value;

  /// Watch a specific field's validation state.
  ValidationResult watchValidation<T>(FormixFieldID<T> id) => controller.validationSignal(id).value;

  /// Watch only the error message of a field. Returns null if valid.
  ///
  /// More efficient than [watchValidation] if you only need the message.
  String? watchError<T>(FormixFieldID<T> id) => controller.validationSignal(id).value.errorMessage;

  /// Watch if a field is currently being validated (async).
  bool watchIsValidating<T>(FormixFieldID<T> id) => controller.validationSignal(id).value.isValidating;

  /// Watch if a specific field is valid.
  bool watchFieldIsValid<T>(FormixFieldID<T> id) => controller.validationSignal(id).value.isValid;

  /// Watch if a specific field is dirty (its value differs from initial).
  bool watchIsDirty<T>(FormixFieldID<T> id) => controller.dirtySignal(id).value;

  /// Watch if a specific field has been touched (focused or modified).
  bool watchIsTouched<T>(FormixFieldID<T> id) => controller.touchedSignal(id).value;

  /// Watch if a specific field is pending (optimistic update or async).
  bool watchIsPending<T>(FormixFieldID<T> id) => controller.pendingSignal(id).value;

  /// Watch the overall validity of the form.
  bool get watchIsValid => controller.isValidSignal.value;

  /// Watch if the form has any modifications at all.
  bool get watchIsFormDirty => controller.isDirtySignal.value;

  /// Watch if the form is currently submitting or performing async validation.
  bool get watchIsSubmitting => controller.isSubmittingSignal.value;

  /// Watch the current step in a multi-step form.
  int get watchCurrentStep => controller.currentStepSignal.value;

  /// Get the current form state (watches the entire state object).
  ///
  /// WARNING: Using this will cause the widget to rebuild whenever ANY field
  /// in the form changes. For better performance, use field-specific watchers
  /// like [watchValue] or [watchValidation].
  FormixData get watchState => controller.state;

  /// Watch if a specific group of fields is valid.
  bool watchGroupIsValid(String prefix) => controller.groupValidSignal(prefix).value;

  /// Watch if a specific group of fields contains any modifications.
  bool watchGroupIsDirty(String prefix) => controller.groupDirtySignal(prefix).value;

  // --- Action Methods (Non-reactive) ---

  /// Returns a nested representation of the current form values.
  Map<String, dynamic> toNestedMap() => controller.currentState.toNestedMap();

  /// Checks if a specific group of fields is valid (non-reactive).
  bool isGroupValid(String prefix) => controller.currentState.isGroupValid(prefix);

  /// Checks if a specific group of fields is dirty (non-reactive).
  bool isGroupDirty(String prefix) => controller.currentState.isGroupDirty(prefix);

  /// Update a field's value and trigger validation.
  void setValue<T>(FormixFieldID<T> id, T value) => controller.setValue(id, value);

  /// Mark a field as touched (usually called when a field loses focus).
  void markAsTouched<T>(FormixFieldID<T> id) => controller.markAsTouched(id);

  /// Checks if a field is pending (non-reactive).
  bool isFieldPending<T>(FormixFieldID<T> id) => controller.currentState.isFieldPending(id);

  /// Request focus for a specific field.
  void focusField<T>(FormixFieldID<T> id) => controller.focusField(id);

  /// Scroll to a specific field.
  void scrollToField<T>(
    FormixFieldID<T> id, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double alignment = 0.5,
  }) {
    controller.scrollToField(
      id,
      duration: duration,
      curve: curve,
      alignment: alignment,
    );
  }

  /// Focus the first field that currently has a validation error.
  void focusFirstError() => controller.focusFirstError();

  /// Manually trigger form-wide validation. Returns true if all fields are valid.
  bool validate() => controller.validate();

  /// Reset the form to its initial values and clear all error states.
  void reset() => controller.reset();

  /// Sets the current step in a multi-step form.
  void goToStep(int step) => controller.goToStep(step);

  /// Increments the current step if the provided [fields] (or all current fields) are valid.
  bool nextStep({List<FormixFieldID>? fields, int? targetStep}) => controller.nextStep(fields: fields, targetStep: targetStep);

  /// Decrements the current step.
  void previousStep({int? targetStep}) => controller.previousStep(targetStep: targetStep);

  /// Validates a specific step by checking the validity of a list of fields.
  bool validateStep(List<FormixFieldID> fields) => controller.validateStep(fields);

  /// Get current values (non-reactive). useful for submissions.
  Map<String, dynamic> get values => controller.currentState.values;

  // --- Array Helpers ---

  /// Watch a form array.
  List<T> watchArray<T>(FormixArrayID<T> id) => watchValue(id) ?? <T>[];

  /// Add an item to a form array.
  void addArrayItem<T>(FormixArrayID<T> id, T item) => controller.addArrayItem(id, item);

  /// Remove an item at index from a form array.
  void removeArrayItemAt<T>(FormixArrayID<T> id, int index) => controller.removeArrayItemAt(id, index);

  /// Replace an item at index in a form array.
  void replaceArrayItem<T>(FormixArrayID<T> id, int index, T item) => controller.replaceArrayItem(id, index, item);

  /// Move an item in a form array.
  void moveArrayItem<T>(FormixArrayID<T> id, int oldIndex, int newIndex) => controller.moveArrayItem(id, oldIndex, newIndex);

  /// Clear a form array.
  void clearArray<T>(FormixArrayID<T> id) => controller.clearArray(id);

  /// High-level helper for form submission.
  ///
  /// workflow:
  /// 1. Runs [validate()].
  /// 2. If valid, sets [isSubmitting] to true.
  /// 3. Executes [onValid] with current form values.
  /// 4. Resets [isSubmitting] when finished.
  /// 5. If invalid, executes [onError].
  Future<void> submit({
    required Future<void> Function(Map<String, dynamic> values) onValid,
    void Function(Map<String, ValidationResult> errors)? onError,
    Duration? debounce,
    Duration? throttle,
    bool optimistic = false,
  }) async {
    return controller.submit(
      onValid: onValid,
      onError: onError,
      debounce: debounce,
      throttle: throttle,
      optimistic: optimistic,
    );
  }
}

/// A builder widget that provides a [FormixScope] for easy form interaction.
///
/// This is the preferred way to build custom form controls or status displays
/// without creating a separate class.
///
/// **Performance Note:** By default, [FormixBuilder] does *not* rebuild when
/// form values change. It only provides the [FormixScope]. You must use
/// [FormixScope.watchValue] or similar methods to subscribe to specific
/// updates, or provide a [select] callback to watch a derived value.
///
/// Example:
/// ```dart
/// FormixBuilder(
///   builder: (context, scope) {
///     final isSubmitting = scope.watchIsSubmitting;
///     final isValid = scope.watchIsValid;
///
///     return ElevatedButton(
///       onPressed: (isValid && !isSubmitting)
///         ? () => scope.submit(onValid: (values) => save(values))
///         : null,
///       child: isSubmitting ? CircularProgressIndicator() : Text('Submit'),
///     );
///   },
/// )
/// ```
class FormixBuilder extends StatefulWidget {
  /// Creates a [FormixBuilder].
  const FormixBuilder({super.key, required this.builder, this.select});

  /// The builder function that receives the [FormixScope].
  final Widget Function(BuildContext context, FormixScope scope) builder;

  /// Optional selector to pick a specific part of the form state.
  /// If provided, this widget will only rebuild when the selected part changes.
  final Object? Function(FormixData state)? select;

  @override
  State<FormixBuilder> createState() => _FormixBuilderState();
}

class _FormixBuilderState extends State<FormixBuilder> {
  FormixScope? _scope;
  FormixController? _previousController;
  Computed<Object?>? _selected;

  @override
  void dispose() {
    _selected?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixBuilder',
    );

    if (errorWidget != null) return errorWidget;

    final controller = Formix.of(context)!;

    if (_scope == null || _previousController != controller) {
      _scope = FormixScope(context: context, controller: controller);
      _previousController = controller;
      _selected?.dispose();
      _selected = widget.select != null ? computed(() => widget.select!(controller.state)) : null;
    }

    return SignalBuilder(
      builder: (context) {
        // Subscribe to the selected slice (if provided); scope.watch* calls
        // inside the builder add their own fine-grained subscriptions.
        _selected?.value;
        return widget.builder(context, _scope!);
      },
    );
  }
}

/// A base class for creating modular, reusable form components.
///
/// By extending [FormixWidget], you get safe, easy access to the form's
/// [FormixScope] without manually looking up the controller or state.
///
/// Example:
/// ```dart
/// class ErrorSummary extends FormixWidget {
///   const ErrorSummary({super.key});
///
///   @override
///   Widget buildForm(BuildContext context, FormixScope scope) {
///     if (scope.watchIsValid) return const SizedBox.shrink();
///
///     return Text(
///       'Please fix the errors before submitting.',
///       style: TextStyle(color: Colors.red),
///     );
///   }
/// }
/// ```
abstract class FormixWidget extends StatefulWidget {
  /// Creates a [FormixWidget].
  const FormixWidget({super.key, this.select});

  /// Optional selector to pick a specific part of the form state.
  /// If provided, this widget will only rebuild when the selected part changes.
  final Object? Function(FormixData state)? select;

  @override
  State<FormixWidget> createState() => _FormixWidgetState();

  /// Build the widget based on the provided [FormixScope].
  Widget buildForm(BuildContext context, FormixScope scope);
}

class _FormixWidgetState extends State<FormixWidget> {
  FormixScope? _scope;
  FormixController? _previousController;
  Computed<Object?>? _selected;

  @override
  void dispose() {
    _selected?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: widget.runtimeType.toString(),
    );

    if (errorWidget != null) return errorWidget;

    final controller = Formix.of(context)!;

    if (_scope == null || _previousController != controller) {
      _scope = FormixScope(context: context, controller: controller);
      _previousController = controller;
      _selected?.dispose();
      _selected = widget.select != null ? computed(() => widget.select!(controller.state)) : null;
    }

    return SignalBuilder(
      builder: (context) {
        _selected?.value;
        return widget.buildForm(context, _scope!);
      },
    );
  }
}
