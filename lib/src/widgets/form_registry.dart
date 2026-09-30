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

class _FormixFieldRegistryState extends State<FormixFieldRegistry> with FormixControllerHost<FormixFieldRegistry> {
  @override
  String get formixWidgetName => 'FormixFieldRegistry';

  @override
  void onControllerChanged(FormixController controller) => _registerFields();

  @override
  void didUpdateWidget(FormixFieldRegistry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fields != oldWidget.fields) {
      _updateFields(oldWidget.fields);
    }
  }

  void _updateFields(List<FormixFieldConfig<dynamic>> oldFields) {
    if (!hasController || !mounted) return;

    final oldIds = oldFields.map((f) => f.id).toList();
    final newIds = widget.fields.map((f) => f.id).toList();

    // Unregister fields removed from the new list.
    final idsToRemove = oldIds.where((id) => !newIds.contains(id)).toList();
    if (idsToRemove.isNotEmpty) {
      Future.microtask(() {
        if (mounted && hasController && controller.mounted) {
          controller.unregisterFields(idsToRemove, preserveState: widget.preserveStateOnDispose);
        }
      });
    }

    _registerFields();
  }

  void _registerFields() {
    if (!hasController || !mounted) return;
    final fieldsToRegister = widget.fields.where((f) => !controller.isFieldRegistered(f.id)).map((f) => f.toField()).toList();
    if (fieldsToRegister.isNotEmpty) {
      controller.registerFields(fieldsToRegister);
    }
  }

  @override
  void dispose() {
    if (hasController && controller.mounted) {
      final c = controller;
      final fieldIds = widget.fields.map((f) => f.id).toList();
      final preserve = widget.preserveStateOnDispose;
      Future.microtask(() {
        if (c.mounted) {
          c.unregisterFields(fieldIds, preserveState: preserve);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return formixErrorOrNull() ?? widget.child;
  }
}
