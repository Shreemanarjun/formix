import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../formix.dart';

/// A widget that asynchronously transforms the value of one field to another in a type-safe way.
///
/// Use this when you have a direct 1-to-1 relationship between fields where
/// one field's value is derived asynchronously from another (e.g., fetching data based on input).
///
/// Supports debouncing to prevent excessive calls during rapid input.
///
/// Example:
/// ```dart
/// FormixFieldAsyncTransformer<String, String>(
///   sourceField: userIdField,
///   targetField: userNameField,
///   debounce: const Duration(milliseconds: 500),
///   transform: (userId) async {
///     if (userId == null) return null;
///     return await fetchUserName(userId);
///   },
/// )
/// ```
class FormixFieldAsyncTransformer<T, S> extends StatefulWidget {
  /// Creates a [FormixFieldAsyncTransformer].
  const FormixFieldAsyncTransformer({
    super.key,
    required this.sourceField,
    required this.targetField,
    required this.transform,
    this.select,
    this.debounce,
    this.retransformOnSubmit = false,
  });

  /// The field to listen to.
  final FormixFieldID<T> sourceField;

  /// The field to update.
  final FormixFieldID<S> targetField;

  /// The asynchronous transformation function.
  final Future<S> Function(T? value) transform;

  /// Optional selector to pick a specific part of the source value.
  final Object? Function(T? value)? select;

  /// Optional debounce duration.
  final Duration? debounce;

  /// Whether to re-run the transformation when the form is submitted.
  final bool retransformOnSubmit;

  @override
  State<FormixFieldAsyncTransformer<T, S>> createState() => _FormixFieldAsyncTransformerState<T, S>();
}

class _FormixFieldAsyncTransformerState<T, S> extends State<FormixFieldAsyncTransformer<T, S>> {
  FormixController? _controller;
  final _inputController = StreamController<T?>.broadcast(sync: true);
  StreamSubscription<T?>? _subscription;
  VoidCallback? _formListenerRemover;
  VoidCallback? _disposeEffect;
  bool _wasSubmitting = false;
  bool _primed = false;
  Object? _lastDep;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    Stream<T?> stream = _inputController.stream;

    if (widget.debounce != null) {
      stream = stream.debounce(widget.debounce!);
    }

    _subscription = stream.listen(_performAsyncTransform);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Formix.controllerOf(context);
    if (newController == null) {
      if (mounted) {
        setState(() {
          _initializationError = 'FormixFieldAsyncTransformer used outside of Formix';
        });
      }
      return;
    }

    if (newController != _controller) {
      _formListenerRemover?.call();
      _formListenerRemover = null;

      _controller = newController;
      if (widget.retransformOnSubmit) {
        _formListenerRemover = _controller!.addFormListener(_onSubmitChanged);
      }
      _wireEffect();
    }
    _initializationError = null;
  }

  /// Subscribes to the source field and feeds the debounce stream whenever the
  /// source value (or its selected part) actually changes.
  ///
  /// The effect tracks ONLY the source value; the side-effect runs [untracked]
  /// so mutating the target does not re-trigger this effect (which would
  /// otherwise cause an infinite transform loop). It transforms on the first run
  /// (initial mount) and thereafter only when the selected part actually changes.
  void _wireEffect() {
    _disposeEffect?.call();
    _primed = false;
    final controller = _controller;
    if (controller == null) return;
    _disposeEffect = effect(() {
      final value = controller.valueSignal(widget.sourceField).value;
      final dep = widget.select != null ? widget.select!(value) : value;
      final shouldTransform = !_primed || dep != _lastDep;
      _primed = true;
      _lastDep = dep;
      if (shouldTransform) {
        untracked(() => _onSourceChanged(value));
      }
    });
  }

  @override
  void didUpdateWidget(FormixFieldAsyncTransformer<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.debounce != widget.debounce) {
      _subscription?.cancel();
      _setupStream();
    }

    if (oldWidget.retransformOnSubmit != widget.retransformOnSubmit) {
      if (widget.retransformOnSubmit) {
        _formListenerRemover = _controller?.addFormListener(_onSubmitChanged);
      } else {
        _formListenerRemover?.call();
        _formListenerRemover = null;
      }
    }

    if (oldWidget.sourceField != widget.sourceField || oldWidget.targetField != widget.targetField) {
      _wireEffect();
    }
  }

  @override
  void dispose() {
    _disposeEffect?.call();
    _subscription?.cancel();
    _inputController.close();
    if (_controller != null) {
      _formListenerRemover?.call();
      // Ensure pending state is cleared when widget is disposed
      // Use microtask to avoid triggering rebuilds during parent disposal
      final controller = _controller!;
      Future.microtask(() {
        if (controller.mounted) {
          controller.setPending(widget.targetField, false);
        }
      });
      _controller = null;
    }
    super.dispose();
  }

  void _onSourceChanged(T? sourceValue) {
    if (!mounted || _controller == null) return;

    // Mark as pending; deferred so it never mutates state during a build phase.
    Future.microtask(() {
      if (mounted && _controller != null) {
        _controller!.setPending(widget.targetField, true);
      }
    });

    // Emit to the (optionally debounced) stream for processing.
    _inputController.add(sourceValue);
  }

  void _onSubmitChanged(FormixData state) {
    if (!widget.retransformOnSubmit) return;

    final isSubmitting = state.isSubmitting;
    if (isSubmitting && !_wasSubmitting) {
      _onSourceChanged(state.getValue(widget.sourceField));
    }
    _wasSubmitting = isSubmitting;
  }

  Future<void> _performAsyncTransform(T? sourceValue) async {
    if (!mounted || _controller == null) return;

    try {
      // Transform
      final S newValue = await widget.transform(sourceValue);

      if (!mounted || _controller == null) return;

      // Get current target value to avoid infinite loops and unnecessary updates
      final dynamic rawTarget = _controller!.getValue(widget.targetField);
      final S? currentTarget = rawTarget as S?;

      if (currentTarget != newValue) {
        // Since we are in an async callback, we might not be in a build phase,
        // but setValue might trigger notifications. Riverpod handles this, but
        // it's good practice to be mindful.
        _controller!.setValue(widget.targetField, newValue);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Error in FormixFieldAsyncTransformer for ${widget.targetField}: $e',
        );
      }
    } finally {
      if (mounted && _controller != null) {
        _controller!.setPending(widget.targetField, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixFieldAsyncTransformer',
        details: 'Error: $_initializationError',
      );
    }
    return const SizedBox.shrink();
  }
}
