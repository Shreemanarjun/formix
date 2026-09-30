import 'package:flutter/material.dart';
import '../../formix.dart';
import 'ancestor_validator.dart';

/// A widget that listens to form state changes and performs side effects.
///
/// [FormixListener] can be used either internally (within a [Formix] tree)
/// or externally (via a [GlobalKey]). It is highly optimized and allows
/// for granular listening via the [select] property.
///
/// Example (Side effects on form validity):
/// ```dart
/// FormixListener(
///   select: (state) => state.isValid,
///   listener: (context, state) {
///     if (state.isValid) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         const SnackBar(content: Text('Form is now valid!'))
///       );
///     }
///   },
///   child: MyFormContent(),
/// )
/// ```
///
/// Example (External listening via key):
/// ```dart
/// FormixListener(
///   formKey: myFormKey,
///   listener: (context, state) => print('Form updated'),
///   child: Container(),
/// )
/// ```
class FormixListener extends StatefulWidget {
  /// Creates a [FormixListener].
  const FormixListener({
    super.key,
    this.formKey,
    this.select,
    required this.listener,
    required this.child,
  });

  /// The GlobalKey of the [Formix] widget to listen to.
  /// If null, the listener will look for the nearest [Formix] ancestor.
  final GlobalKey<FormixState>? formKey;

  /// Optional selector to pick a specific part of the form state.
  /// The [listener] will only be called when the selected value changes.
  final Object? Function(FormixData state)? select;

  /// Callback called whenever the form state (or the selected part) changes.
  final void Function(BuildContext context, FormixData state) listener;

  /// The child widget.
  final Widget child;

  @override
  State<FormixListener> createState() => _FormixListenerState();
}

class _FormixListenerState extends State<FormixListener> {
  VoidCallback? _removeListener;
  Object? _initializationError;
  FormixData? _previousState;
  Object? _previousSelectedValue;

  @override
  void initState() {
    super.initState();
    // Defer to allow context to be fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _subscribe();
    });
  }

  @override
  void didUpdateWidget(FormixListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.formKey != oldWidget.formKey) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    try {
      final controller = _resolveController();

      if (controller != null) {
        _previousState = controller.currentState;
        _previousSelectedValue = widget.select?.call(_previousState!);

        _removeListener = controller.addFormListener(_onStateChanged);

        if (mounted && _initializationError != null) {
          setState(() {
            _initializationError = null;
          });
        }
      } else if (widget.formKey != null) {
        // External key provided but not yet available
        setState(() {
          _initializationError = 'Formix not found at provided GlobalKey';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializationError = e;
        });
      }
    }
  }

  FormixController? _resolveController() {
    if (widget.formKey != null) {
      return widget.formKey!.currentState?.controller;
    }
    return Formix.controllerOf(context);
  }

  void _onStateChanged(FormixData state) {
    if (!mounted) return;

    bool shouldNotify = false;
    if (widget.select != null) {
      final selected = widget.select!(state);
      if (selected != _previousSelectedValue) {
        shouldNotify = true;
        _previousSelectedValue = selected;
      }
    } else {
      shouldNotify = true;
    }

    if (shouldNotify) {
      widget.listener(context, state);
    }
    _previousState = state;
  }

  void _unsubscribe() {
    _removeListener?.call();
    _removeListener = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Validate ancestor once ready
    if (widget.formKey == null) {
      final errorWidget = FormixAncestorValidator.validate(
        context,
        widgetName: 'FormixListener',
      );
      if (errorWidget != null) return errorWidget;
    }

    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixListener',
        details: 'Error: $_initializationError',
      );
    }
    return widget.child;
  }
}
