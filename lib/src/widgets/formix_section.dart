import 'package:flutter/material.dart';
import '../../formix.dart'; // For Formix.of
import 'ancestor_validator.dart';

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

class _FormixSectionState extends State<FormixSection> {
  FormixController? _controller;
  Object? _initializationError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initController();
    _registerFields();
  }

  @override
  void didUpdateWidget(FormixSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If fields changed, register the new ones.
    // controller.registerFields handles already-registered fields gracefully.
    _registerFields();
  }

  void _initController() {
    final controller = Formix.controllerOf(context);
    if (controller == null) {
      return;
    }
    _controller = controller;
    _initializationError = null;
  }

  void _registerFields() {
    if (_controller == null) return;
    final controller = _controller!;

    final fieldsToRegister = widget.fields.where((f) => !controller.isFieldRegistered(f.id)).map((f) => f.toField()).toList();

    if (fieldsToRegister.isNotEmpty) {
      controller.registerFields(fieldsToRegister);
    }
  }

  @override
  void dispose() {
    if (!widget.keepAlive && _controller != null) {
      final controller = _controller!;
      final ids = widget.fields.map((f) => f.id).toList();

      // Defer unregistration to avoid issues if state is being updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.unregisterFields(ids);
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

    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixSection',
        details: _initializationError.toString().contains('No ProviderScope found')
            ? 'Missing ProviderScope. Please wrap your application (or this form) in a ProviderScope widget.\n\nExample:\nvoid main() {\n  runApp(ProviderScope(child: MyApp()));\n}'
            : 'Error: $_initializationError',
      );
    }
    return widget.child;
  }
}
