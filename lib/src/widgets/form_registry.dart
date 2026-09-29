import 'package:flutter/material.dart';
import '../../formix.dart';

/// A widget that dynamically registers and unregisters fields for a specific part of the form.
///
/// This is used to implement "Lazy Step Initialization". By wrapping step content in
/// [FormixFieldRegistry], fields are only registered (and validated) when the step is active/mounted.
/// When the step is unmounted (e.g., scrolled away in a PageView), fields are unregistered
/// to save memory and processing power, but their data is PRESERVED in the form state.
///
/// Example:
/// ```dart
/// PageView(
///   children: [
///     FormixFieldRegistry(
///       fields: [step1Field],
///       child: Step1Form(),
///     ),
///      FormixFieldRegistry(
///       fields: [step2Field],
///       child: Step2Form(),
///     ),
///   ]
/// )
/// ```
class FormixFieldRegistry extends StatefulWidget {
  /// Creates a [FormixFieldRegistry].
  const FormixFieldRegistry({
    super.key,
    required this.fields,
    required this.child,
    this.preserveStateOnDispose = true,
  });

  /// The fields to manage for this subtree.
  final List<FormixFieldConfig<dynamic>> fields;

  /// The widget subtree.
  final Widget child;

  /// Whether to keep field values in the form state when this widget is disposed.
  ///
  /// Defaults to `true`, which implements the "Lazy/Sleep" pattern:
  /// unloading the logic/validators but keeping the data.
  final bool preserveStateOnDispose;

  @override
  State<FormixFieldRegistry> createState() => _FormixFieldRegistryState();
}

class _FormixFieldRegistryState extends State<FormixFieldRegistry> {
  FormixController? _controller;
  Object? _initializationError;

  @override
  void didUpdateWidget(FormixFieldRegistry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fields != oldWidget.fields) {
      _updateFields(oldWidget.fields);
    }
  }

  void _updateFields(List<FormixFieldConfig<dynamic>> oldFields) {
    if (_controller == null || !mounted) return;

    final oldIds = oldFields.map((f) => f.id).toList();
    final newIds = widget.fields.map((f) => f.id).toList();

    // Find fields to unregister (removed from new list)
    final idsToRemove = oldIds.where((id) => !newIds.contains(id)).toList();
    if (idsToRemove.isNotEmpty) {
      Future.microtask(() {
        if (mounted && _controller != null && _controller!.mounted) {
          _controller!.unregisterFields(
            idsToRemove,
            preserveState: widget.preserveStateOnDispose,
          );
        }
      });
    }

    // Register new fields
    _registerFields();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Formix.controllerOf(context);
    if (newController == null) {
      if (mounted) {
        setState(() {
          _initializationError = 'FormixFieldRegistry used outside of Formix';
        });
      }
      return;
    }

    if (newController != _controller) {
      _controller = newController;
      _registerFields();
    }
    _initializationError = null;
  }

  void _registerFields() {
    if (_controller == null || !mounted) return;

    final fieldsToRegister = widget.fields.where((f) => !_controller!.isFieldRegistered(f.id)).map((f) => f.toField()).toList();

    if (fieldsToRegister.isNotEmpty) {
      _controller!.registerFields(fieldsToRegister);
    }
  }

  @override
  void dispose() {
    if (_controller != null && _controller!.mounted) {
      final controller = _controller!;
      final fieldIds = widget.fields.map((f) => f.id).toList();
      final preserve = widget.preserveStateOnDispose;

      Future.microtask(() {
        // Double check mounting before updating
        if (controller.mounted) {
          controller.unregisterFields(fieldIds, preserveState: preserve);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixFieldRegistry',
        details: _initializationError.toString().contains('No ProviderScope found')
            ? 'Missing ProviderScope. Please wrap your application (or this form) in a ProviderScope widget.'
            : 'Error: $_initializationError',
      );
    }
    return widget.child;
  }
}
