import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../formix.dart';

/// A widget that transforms the value of one field to another in a type-safe way.
///
/// Use this when you have a direct 1-to-1 relationship between fields where
/// one field's value is derived strictly from another.
///
/// Example:
/// ```dart
/// FormixFieldTransformer<String, int>(
///   sourceField: textField,
///   targetField: lengthField,
///   transform: (text) => text?.length ?? 0,
/// )
/// ```
class FormixFieldTransformer<T, S> extends StatefulWidget {
  /// Creates a [FormixFieldTransformer].
  const FormixFieldTransformer({
    super.key,
    required this.sourceField,
    required this.targetField,
    required this.transform,
    this.select,
  });

  /// The field to listen to.
  final FormixFieldID<T> sourceField;

  /// The field to update.
  final FormixFieldID<S> targetField;

  /// The transformation function.
  final S Function(T? value) transform;

  /// Optional selector to pick a specific part of the source value.
  /// This is used to avoid unnecessary transformations when other parts of
  /// a complex object change.
  final Object? Function(T? value)? select;

  @override
  State<FormixFieldTransformer<T, S>> createState() => _FormixFieldTransformerState<T, S>();
}

class _FormixFieldTransformerState<T, S> extends State<FormixFieldTransformer<T, S>> {
  FormixController? _controller;
  Object? _initializationError;
  VoidCallback? _disposeEffect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Formix.controllerOf(context);
    if (newController == null) {
      if (mounted) {
        setState(() {
          _initializationError = 'FormixFieldTransformer used outside of Formix';
        });
      }
      return;
    }

    if (newController != _controller) {
      _controller = newController;
      _wireEffect();
    }
    _initializationError = null;
  }

  /// Subscribes to the source field; the effect re-runs (and re-transforms)
  /// whenever the source value (or its selected part) changes.
  void _wireEffect() {
    _disposeEffect?.call();
    final controller = _controller;
    if (controller == null) return;
    _disposeEffect = effect(() {
      final value = controller.valueSignal(widget.sourceField).value;
      if (widget.select != null) widget.select!(value);
      _transformValue();
    });
  }

  void _transformValue() {
    if (!mounted || _controller == null) return;

    try {
      // Get source value
      final dynamic rawValue = _controller!.getValue(widget.sourceField);
      final T? sourceValue = rawValue as T?;

      // Transform
      final S newValue = widget.transform(sourceValue);

      // Get current target value to avoid infinite loops
      final dynamic rawTarget = _controller!.getValue(widget.targetField);
      final S? currentTarget = rawTarget as S?;

      if (currentTarget != newValue) {
        scheduleMicrotask(() {
          if (mounted && _controller != null) {
            _controller!.setValue(widget.targetField, newValue);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Error in FormixFieldTransformer for ${widget.targetField}: $e',
        );
      }
    }
  }

  @override
  void didUpdateWidget(FormixFieldTransformer<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if source or target field changed
    if (oldWidget.sourceField != widget.sourceField || oldWidget.targetField != widget.targetField) {
      // Rewire the effect (and re-transform) with the new fields.
      _wireEffect();
    }
  }

  @override
  void dispose() {
    _disposeEffect?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixFieldTransformer',
        details: _initializationError.toString().contains('No ProviderScope found')
            ? 'Missing ProviderScope. Please wrap your application (or this form) in a ProviderScope widget.'
            : 'Error: $_initializationError',
      );
    }

    // Reactivity is handled by the effect wired in didChangeDependencies.
    return const SizedBox.shrink();
  }
}
