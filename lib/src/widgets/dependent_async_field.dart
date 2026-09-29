import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../formix.dart';
import 'ancestor_validator.dart';

/// A simplified version of [FormixAsyncField] that automatically manages dependencies.
///
/// It watches the [dependency] field and:
/// 1. Re-executes [future] when the dependency changes.
/// 2. Clears the [resetField] value when the dependency changes (optional).
/// 3. Passes the dependency value to the [future] builder.
///
/// This reduces boilerplate for common parent-child field relationships (e.g. Country -> City).
///
/// Example:
/// ```dart
/// FormixDependentAsyncField<List<String>, String>(
///   fieldId: cityOptionsField,
///   dependency: countryField,
///   resetField: cityField, // Clear selected city when country changes
///   future: (country) => fetchCities(country),
///   builder: (context, state) {
///     // ... build dropdown
///   },
/// )
/// ```
class FormixDependentAsyncField<T, D> extends StatefulWidget {
  /// Creates a [FormixDependentAsyncField].
  const FormixDependentAsyncField({
    super.key,
    required this.fieldId,
    required this.dependency,
    required this.future,
    required this.builder,
    this.resetField,
    this.keepPreviousData = false,
    this.loadingBuilder,
    this.asyncErrorBuilder,
    this.debounce,
    this.initialValue,
    this.initialValueStrategy,
    this.select,
    this.manual = false,
    this.onData,
  });

  /// The ID of this field (used to store the async state/result).
  final FormixFieldID<T> fieldId;

  /// The ID of the dependency field to watch.
  final FormixFieldID<D> dependency;

  /// Optional field to reset (set to null) when the dependency changes.
  /// Typically this is the field that consumes the options produced by this widget.
  final FormixFieldID<dynamic>? resetField;

  /// Function to create the future based on the dependency value.
  final Future<T> Function(D? dependencyValue) future;

  /// A builder function that is called when data is available.
  final Widget Function(BuildContext context, FormixAsyncFieldState<T> state) builder;

  /// Whether to keep the previous data while loading the new data.
  final bool keepPreviousData;

  /// Optional builder for the loading state.
  final WidgetBuilder? loadingBuilder;

  /// Optional builder for the error state.
  final Widget Function(BuildContext context, Object error)? asyncErrorBuilder;

  /// Debounce duration for the future.
  final Duration? debounce;

  /// Initial value for the field.
  final T? initialValue;

  /// If true, the field must be manually refreshed.
  final bool manual;

  /// Strategy for handling initial values.
  final FormixInitialValueStrategy? initialValueStrategy;

  /// Optional selector to pick a specific part of the dependency value.
  /// This ensures the future only re-runs when the selected part changes.
  final Object? Function(D? value)? select;

  /// Optional callback executed when data is successfully loaded.
  final void Function(BuildContext context, FormixController controller, T data)? onData;

  @override
  State<FormixDependentAsyncField<T, D>> createState() => _FormixDependentAsyncFieldState<T, D>();
}

class _FormixDependentAsyncFieldState<T, D> extends State<FormixDependentAsyncField<T, D>> {
  D? _lastDependencyValue;
  Future<T>? _currentFuture;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixDependentAsyncField',
      requireFormix: false,
    );

    if (errorWidget != null) return errorWidget;

    final controller = Formix.controllerOf(context);
    if (controller == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixDependentAsyncField',
        details: 'FormixDependentAsyncField must be used inside a Formix widget.',
      );
    }

    // Rebuild reactively whenever the dependency value changes.
    return SignalBuilder(
      builder: (context) {
        final D? dependencyValue = controller.valueSignal(widget.dependency).value;

        // Detect a change (respecting the optional selector) to recreate the
        // future and reset the related field.
        final bool changed = !_initialized ||
            (widget.select != null
                ? widget.select!(dependencyValue) != widget.select!(_lastDependencyValue)
                : dependencyValue != _lastDependencyValue);

        if (changed) {
          final bool wasInitialized = _initialized;
          _lastDependencyValue = dependencyValue;
          _currentFuture = widget.future(dependencyValue);
          _initialized = true;

          // Reset the dependent field when the dependency actually changes
          // (not on the first build).
          if (wasInitialized && widget.resetField != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && controller.mounted) {
                controller.resetFields(
                  [widget.resetField!],
                  strategy: ResetStrategy.clear,
                );
              }
            });
          }
        }

        return FormixAsyncField<T>(
          fieldId: widget.fieldId,
          // Pass the cached future
          future: _currentFuture,
          // Use the dependency value as the 'dependencies' list for FormixAsyncField
          // This tells FormixAsyncField to re-execute the future when this value changes
          dependencies: [dependencyValue],
          // Define retry logic (same as initial fetch)
          onRetry: () {
            // Force update the current future on retry
            final future = widget.future(dependencyValue);
            setState(() {
              _currentFuture = future;
            });
            return future;
          },
          builder: widget.builder,
          loadingBuilder: widget.loadingBuilder,
          asyncErrorBuilder: widget.asyncErrorBuilder,
          keepPreviousData: widget.keepPreviousData,
          debounce: widget.debounce,
          initialValue: widget.initialValue,
          initialValueStrategy: widget.initialValueStrategy,
          manual: widget.manual,
          onData: widget.onData,
        );
      },
    );
  }
}
