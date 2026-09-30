import 'package:flutter/material.dart';

import '../../formix.dart';

/// Rebuilds [builder] whenever a single field's value changes — a
/// [ValueListenableBuilder]-style shorthand for the common "react to one field"
/// case (no `FormixBuilder` + `scope.watchValue` needed).
///
/// ```dart
/// FormixValue(emailField, builder: (context, value) => Text(value ?? ''));
/// ```
class FormixValue<T> extends StatelessWidget {
  /// Creates a [FormixValue] bound to [fieldId].
  const FormixValue(this.fieldId, {super.key, required this.builder, this.controller});

  /// The field to watch.
  final FormixFieldID<T> fieldId;

  /// Builds UI from the field's current value.
  final Widget Function(BuildContext context, T? value) builder;

  /// Optional explicit controller; falls back to the nearest [Formix] ancestor.
  final FormixController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? Formix.maybeOf(context);
    if (c == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixValue',
        details: 'FormixValue must be used inside a Formix widget or given an explicit controller.',
      );
    }
    return SignalBuilder(builder: (context) => builder(context, c.valueSignal(fieldId).value));
  }
}

/// A submit button that is automatically disabled while the form is invalid or
/// submitting, and shows a progress indicator during submission.
///
/// ```dart
/// FormixSubmitButton(
///   onValid: (values) => api.save(values),
///   child: const Text('Save'),
/// );
/// ```
/// Provide [builder] for a fully custom button; it receives an `onPressed` that
/// is null when the button should be disabled, plus the current `submitting` state.
class FormixSubmitButton extends StatelessWidget {
  /// Creates a [FormixSubmitButton].
  const FormixSubmitButton({
    super.key,
    required this.onValid,
    this.child,
    this.builder,
    this.onError,
    this.controller,
    this.disableWhenInvalid = true,
    this.disableWhenSubmitting = true,
    this.optimistic = false,
    this.loadingIndicator,
    this.style,
  }) : assert(child != null || builder != null, 'Provide either child or builder');

  /// Called with the form values when submission validates.
  final Future<void> Function(Map<String, dynamic> values) onValid;

  /// Called with the validation errors when submission fails.
  final void Function(Map<String, ValidationResult> errors)? onError;

  /// The button label (used by the default [ElevatedButton]). Ignored if [builder] is set.
  final Widget? child;

  /// Fully custom button builder. `onPressed` is null when disabled.
  final Widget Function(BuildContext context, VoidCallback? onPressed, bool submitting)? builder;

  /// Optional explicit controller; falls back to the nearest [Formix] ancestor.
  final FormixController? controller;

  /// Disable the button while the form is invalid (default true).
  final bool disableWhenInvalid;

  /// Disable the button while a submission is in flight (default true).
  final bool disableWhenSubmitting;

  /// Pass-through to [FormixController.submit].
  final bool optimistic;

  /// Widget shown in place of [child] while submitting (default: a small spinner).
  final Widget? loadingIndicator;

  /// Style for the default [ElevatedButton].
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? Formix.maybeOf(context);
    if (c == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixSubmitButton',
        details: 'FormixSubmitButton must be used inside a Formix widget or given an explicit controller.',
      );
    }

    return SignalBuilder(
      builder: (context) {
        final submitting = c.isSubmittingSignal.value;
        final valid = c.isValidSignal.value;
        final disabled = (disableWhenSubmitting && submitting) || (disableWhenInvalid && !valid);
        void submit() => c.submit(onValid: onValid, onError: onError, optimistic: optimistic);

        if (builder != null) {
          return builder!(context, disabled ? null : submit, submitting);
        }
        return ElevatedButton(
          style: style,
          onPressed: disabled ? null : submit,
          child: submitting
              ? (loadingIndicator ?? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : child!,
        );
      },
    );
  }
}
