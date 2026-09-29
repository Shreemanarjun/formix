import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../formix.dart';
import 'ancestor_validator.dart';

/// A widget that rebuilds when a dependent field's value changes.
///
/// Use [FormixDependentField] to conditionally show or hide parts of your UI
/// based on the current value of another field. This is highly optimized and
/// only rebuilds when the specific dependent field changes.
///
/// Example:
/// ```dart
/// FormixDependentField<bool>(
///   fieldId: hasPetField,
///   builder: (context, hasPet) {
///     if (hasPet == true) {
///       return FormixTextFormField(fieldId: petNameField);
///     }
///     return const SizedBox.shrink();
///   },
/// )
/// ```
class FormixDependentField<T> extends StatefulWidget {
  /// Creates a dependent field widget.
  const FormixDependentField({
    super.key,
    required this.fieldId,
    required this.builder,
    this.select,
    this.controller,
  });

  /// The ID of the field to watch for changes.
  final FormixFieldID<T> fieldId;

  /// Builder function that receives the current [value] of the dependent field.
  final Widget Function(BuildContext context, T? value) builder;

  /// Optional selector to pick a specific part of the field value.
  /// This is used to avoid unnecessary rebuilds when other parts of
  /// a complex object change.
  final Object? Function(T? value)? select;

  /// Optional explicit controller. If null, it looks up the nearest [Formix].
  final FormixController? controller;

  @override
  State<FormixDependentField<T>> createState() => _FormixDependentFieldState<T>();
}

class _FormixDependentFieldState<T> extends State<FormixDependentField<T>> {
  Computed<Object?>? _selected;
  FormixController? _computedController;

  @override
  void dispose() {
    _selected?.dispose();
    super.dispose();
  }

  Computed<Object?> _selectComputed(FormixController controller) {
    if (_selected == null || _computedController != controller) {
      _selected?.dispose();
      _computedController = controller;
      _selected = computed(() => widget.select!(controller.valueSignal(widget.fieldId).value));
    }
    return _selected!;
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixDependentField',
      explicitController: widget.controller,
      requireFormix: false,
    );

    if (errorWidget != null) return errorWidget;

    final controller = widget.controller ?? Formix.controllerOf(context);
    if (controller == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixDependentField',
        details: 'FormixDependentField must be used inside a Formix widget or given an explicit controller.',
      );
    }

    return SignalBuilder(
      builder: (context) {
        final T? value;
        if (widget.select != null) {
          // Subscribe only to the selected part, but pass the whole value to the builder.
          _selectComputed(controller).value;
          value = controller.valueSignal(widget.fieldId).peek();
        } else {
          value = controller.valueSignal(widget.fieldId).value;
        }
        return widget.builder(context, value);
      },
    );
  }
}
