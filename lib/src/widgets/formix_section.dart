import 'package:flutter/material.dart';
import '../../formix.dart'; // For Formix.of
import 'ancestor_validator.dart';
import 'formix_controller_host.dart';

/// A widget that registers a specific set of fields with the parent [Formix].
///
/// This is useful for:
/// 1. Organizing large forms into logical sections
/// 2. Lazy loading/registering fields (only when this section is built)
/// 3. Modularizing form definitions
///
/// Example:
/// ```dart
/// Formix(
///   child: ListView(
///     children: [
///       FormixSection(
///         fields: [ConfigA, ConfigB],
///         child: SectionA(),
///       ),
///       // SectionB fields are not registered until scrolled into view
///       FormixSection(
///         fields: [ConfigC, ConfigD],
///         child: SectionB(),
///       ),
///     ],
///   ),
/// )
/// ```
class FormixSection extends StatefulWidget {
  /// Creates a [FormixSection].
  const FormixSection({
    super.key,
    required this.fields,
    required this.child,
    this.keepAlive = true,
  });

  /// The fields to register when this section is built
  final List<FormixFieldConfig<dynamic>> fields;

  /// The child widget containing the form fields
  final Widget child;

  /// Whether to keep the field values/state when this section is disposed.
  /// Defaults to true (standard form behavior).
  /// If set to false, fields will be unregistered (and data potentially lost)
  /// when this widget is removed from the tree.
  final bool keepAlive;

  @override
  State<FormixSection> createState() => _FormixSectionState();
}

class _FormixSectionState extends State<FormixSection> with FormixControllerHost<FormixSection> {
  @override
  String get formixWidgetName => 'FormixSection';

  @override
  void onControllerChanged(FormixController controller) => _registerFields();

  @override
  void didUpdateWidget(FormixSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If fields changed, register the new ones.
    // registerFields handles already-registered fields gracefully.
    _registerFields();
  }

  void _registerFields() {
    if (!hasController) return;
    final fieldsToRegister = widget.fields.where((f) => !controller.isFieldRegistered(f.id)).map((f) => f.toField()).toList();
    if (fieldsToRegister.isNotEmpty) {
      controller.registerFields(fieldsToRegister);
    }
  }

  @override
  void dispose() {
    if (!widget.keepAlive && hasController) {
      final c = controller;
      final ids = widget.fields.map((f) => f.id).toList();
      // Defer unregistration to avoid issues if state is being updated.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.mounted) {
          c.unregisterFields(ids);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixSection',
    );
    if (errorWidget != null) return errorWidget;
    return widget.child;
  }
}
