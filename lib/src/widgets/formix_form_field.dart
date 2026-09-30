import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../formix.dart';

/// Bridges a Formix field into a native Flutter [Form].
///
/// Drop this inside an ordinary `Form` and the field participates in
/// `Form.of(context).validate()`, `.save()` and `.reset()` while a
/// [FormixController] remains the source of truth. Formix validation (sync +
/// cross-field) drives the Flutter [FormFieldState.errorText]; the displayed
/// value is the controller's, kept reactive via a [SignalBuilder].
///
/// Example:
/// ```dart
/// Form(
///   key: flutterFormKey,
///   child: Formix(
///     child: FormixFormField<String>(
///       fieldId: emailField,
///       builder: (context, value, error, onChanged) => TextField(
///         onChanged: onChanged,
///         decoration: InputDecoration(errorText: error, labelText: 'Email'),
///       ),
///     ),
///   ),
/// )
/// // flutterFormKey.currentState!.validate() now runs Formix validation.
/// ```
class FormixFormField<T> extends StatefulWidget {
  /// Creates a [FormixFormField].
  const FormixFormField({
    super.key,
    required this.fieldId,
    required this.builder,
    this.controller,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  /// The Formix field this adapter is bound to.
  final FormixFieldID<T> fieldId;

  /// Optional explicit controller; falls back to the nearest [Formix] ancestor.
  final FormixController? controller;

  /// Builds the input UI. Receives the current [value], the current [errorText]
  /// (null when valid), and an [onChanged] to push edits back into Formix.
  final Widget Function(BuildContext context, T? value, String? errorText, ValueChanged<T?> onChanged) builder;

  /// Called by [FormState.save] with the current value.
  final FormFieldSetter<T>? onSaved;

  /// When to auto-validate this Flutter [FormField].
  final AutovalidateMode autovalidateMode;

  @override
  State<FormixFormField<T>> createState() => _FormixFormFieldState<T>();
}

class _FormixFormFieldState<T> extends State<FormixFormField<T>> with FormixControllerHost<FormixFormField<T>> {
  @override
  FormixController? get explicitController => widget.controller;

  @override
  String get formixWidgetName => 'FormixFormField';

  @override
  void onControllerChanged(FormixController controller) {}

  /// Runs Formix validation for this field and returns its error message (or
  /// null when valid). Delegated to by the Flutter [FormField.validator].
  String? _validate(FormixController controller, T? value) {
    // `value is T` accepts null only for nullable T, avoiding a cast error when
    // an unset non-nullable field is validated.
    if (value is T) controller.setValue(widget.fieldId, value);
    controller.validate(fields: [widget.fieldId]);
    final result = controller.getValidation(widget.fieldId);
    return result.isValid ? null : result.errorMessage;
  }

  @override
  Widget build(BuildContext context) {
    final err = formixErrorOrNull();
    if (err != null) return err;
    final controller = this.controller;

    // Rebuild the FormField whenever the controller's value or validation for
    // this field changes, so display + errorText stay in sync with Formix.
    return SignalBuilder(
      builder: (context) {
        final value = controller.valueSignal(widget.fieldId).value;
        controller.validationSignal(widget.fieldId).value; // subscribe to errors

        return FormField<T>(
          initialValue: value,
          autovalidateMode: widget.autovalidateMode,
          onSaved: widget.onSaved,
          validator: (v) => _validate(controller, v),
          builder: (field) {
            // Keep the Flutter FormField's own value aligned with Formix so
            // save()/validate() see the latest without extra plumbing.
            if (field.value != value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (field.mounted) field.didChange(value);
              });
            }
            return widget.builder(context, value, field.errorText, (v) {
              field.didChange(v);
              if (v is T) controller.setValue(widget.fieldId, v);
            });
          },
        );
      },
    );
  }
}
