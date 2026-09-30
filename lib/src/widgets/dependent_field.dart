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
  FormixController? _controller;
  VoidCallback? _disposeEffect;
  T? _value;
  Object? _lastDep;
  bool _primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = widget.controller ?? Formix.controllerOf(context);
    if (controller != _controller) {
      _controller = controller;
      _wire();
    }
  }

  @override
  void didUpdateWidget(FormixDependentField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = widget.controller ?? Formix.controllerOf(context);
    if (controller != _controller || oldWidget.fieldId != widget.fieldId) {
      _controller = controller;
      _wire();
    }
  }

  /// Tracks the field value via an effect and rebuilds only when the selected
  /// projection actually changes (deterministic gating, independent of computed
  /// equality). The whole value is always kept for the builder.
  void _wire() {
    _disposeEffect?.call();
    _disposeEffect = null;
    _primed = false;
    final controller = _controller;
    if (controller == null) return;
    _disposeEffect = effect(() {
      final value = controller.valueSignal(widget.fieldId).value;
      final dep = widget.select != null ? widget.select!(value) : value;
      final firstRun = !_primed;
      final changed = firstRun || dep != _lastDep;
      _primed = true;
      _lastDep = dep;
      _value = value; // always keep the latest raw value for the builder
      if (changed && !firstRun && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _disposeEffect?.call();
    super.dispose();
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

    if (_controller == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixDependentField',
        details: 'FormixDependentField must be used inside a Formix widget or given an explicit controller.',
      );
    }

    return widget.builder(context, _value);
  }
}
