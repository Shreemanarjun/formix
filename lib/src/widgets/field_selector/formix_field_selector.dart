import 'package:formix/formix.dart';
import 'package:flutter/material.dart';
import '../ancestor_validator.dart';

/// A highly optimized, declarative widget that rebuilds only when a specific field changes
/// Provides granular performance and detailed change information
class FormixFieldSelector<T> extends StatefulWidget {
  /// Creates a [FormixFieldSelector].
  const FormixFieldSelector({
    super.key,
    required this.fieldId,
    required this.builder,
    this.controller,
    this.listenToValue = true,
    this.listenToValidation = true,
    this.listenToDirty = true,
    this.select,
    this.child,
  });

  /// The ID of the field to listen to.
  final FormixFieldID<T> fieldId;

  /// Builder function that returns the widget tree based on field changes.
  final Widget Function(
    BuildContext context,
    FieldChangeInfo<T> info,
    Widget? child,
  )
  builder;

  /// Optional controller. If not provided, it will be looked up in the context.
  final FormixController? controller;

  /// Whether to rebuild when the field value changes.
  final bool listenToValue;

  /// Whether to rebuild when the validation result changes.
  final bool listenToValidation;

  /// Whether to rebuild when the dirty state changes.
  final bool listenToDirty;

  /// Optional selector to pick a specific part of the field value.
  /// This is used to avoid unnecessary rebuilds when other parts of
  /// a complex object change. Only affects rebuilds when [listenToValue] is true.
  final Object? Function(T? value)? select;

  /// Optional child widget that is passed to the builder to optimize rebuilds.
  final Widget? child;

  @override
  State<FormixFieldSelector<T>> createState() => _FormixFieldSelectorState<T>();
}

class _FormixFieldSelectorState<T> extends State<FormixFieldSelector<T>> {
  FormixController? _controller;
  late T? _currentValue;
  late ValidationResult _currentValidation;
  late bool _currentIsDirty;
  late bool _hasInitialValueChanged;

  T? _previousValue;
  ValidationResult? _previousValidation;
  bool? _previousIsDirty;

  void _updateController(FormixController? newController) {
    if (newController != _controller) {
      if (_controller != null) {
        _controller!.removeFieldListener(widget.fieldId, _onFieldChanged);
      }
      _controller = newController;

      if (_controller != null) {
        // Initialize current state
        _updateCurrentState();
        // Listen to field changes
        _controller!.addFieldListener(widget.fieldId, _onFieldChanged);
      }
    }
  }

  @override
  void didUpdateWidget(FormixFieldSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final fieldChanged = oldWidget.fieldId != widget.fieldId;
    final selectChanged = oldWidget.select != widget.select;

    if ((fieldChanged || selectChanged) && _controller != null) {
      if (fieldChanged) {
        // Unbind from the old field and rebind to the new one
        _controller!.removeFieldListener(oldWidget.fieldId, _onFieldChanged);
        _updateCurrentState();
        _controller!.addFieldListener(widget.fieldId, _onFieldChanged);
      } else {
        // If only the selector changed, just refresh current state for comparisons
        _updateCurrentState();
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      _controller!.removeFieldListener(widget.fieldId, _onFieldChanged);
    }
    super.dispose();
  }

  void _updateCurrentState() {
    if (_controller == null) return;
    _currentValue = _controller!.getValue(widget.fieldId);
    _currentValidation = _controller!.getValidation(widget.fieldId);
    _currentIsDirty = _controller!.isFieldDirty(widget.fieldId);

    // Check if initial value has changed
    final initialValue = _controller!.initialValue[widget.fieldId.key];
    _hasInitialValueChanged = _currentValue != initialValue;
  }

  void _onFieldChanged() {
    if (!mounted) return;

    // Store previous state
    _previousValue = _currentValue;
    _previousValidation = _currentValidation;
    _previousIsDirty = _currentIsDirty;

    // Update current state
    _updateCurrentState();

    // Check if we should rebuild based on listen flags
    bool shouldRebuild = false;

    if (widget.listenToValue) {
      if (widget.select != null) {
        if (widget.select!(_currentValue) != widget.select!(_previousValue)) {
          shouldRebuild = true;
        }
      } else if (_currentValue != _previousValue) {
        shouldRebuild = true;
      }
    }

    if (widget.listenToValidation && _currentValidation != _previousValidation) {
      shouldRebuild = true;
    }

    if (widget.listenToDirty && _currentIsDirty != _previousIsDirty) {
      shouldRebuild = true;
    }

    if (shouldRebuild) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final FormixController? effectiveController = widget.controller ?? Formix.controllerOf(context);

    // Update the internal _controller (registers/unregisters field listeners).
    _updateController(effectiveController);

    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixFieldSelector',
      requireFormix: true,
      hasExplicitController: widget.controller != null,
    );

    if (errorWidget != null) {
      return errorWidget;
    }

    final info = FieldChangeInfo<T>(
      fieldId: widget.fieldId,
      value: _currentValue,
      validation: _currentValidation,
      isDirty: _currentIsDirty,
      hasInitialValueChanged: _hasInitialValueChanged,
      previousValue: _previousValue,
      previousValidation: _previousValidation,
      previousIsDirty: _previousIsDirty,
    );

    return widget.builder(context, info, widget.child);
  }
}
