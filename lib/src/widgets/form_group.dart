import 'package:flutter/widgets.dart';
import '../../formix.dart';

/// A widget that provides a namespace for form fields.
///
/// Any [FormixFieldID] used within a [FormixGroup] can have the group's
/// prefix automatically prepended if they are resolved via the context.
/// This allows for easy nesting of form sections.
///
/// Example:
/// ```dart
/// FormixGroup(
///   prefix: 'user',
///   child: Column(
///     children: [
///       FormixTextFormField(fieldId: FormixFieldID('name')), // Resolves to 'user.name'
///       FormixGroup(
///         prefix: 'address',
///         child: FormixTextFormField(fieldId: FormixFieldID('city')), // Resolves to 'user.address.city'
///       ),
///     ],
///   ),
/// )
/// ```
class FormixGroup extends StatefulWidget {
  /// Creates a form group.
  const FormixGroup({super.key, required this.prefix, required this.child});

  /// The prefix for this group.
  final String prefix;

  /// The widget subtree.
  final Widget child;

  @override
  State<FormixGroup> createState() => _FormixGroupState();

  /// Get the current combined prefix for the given [context].
  static String? prefixOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FormixGroupScope>();
    return scope?.fullPrefix;
  }

  /// Resolves a [FormixFieldID] by applying any prefixes.
  static FormixFieldID<T> resolve<T>(
    BuildContext context,
    FormixFieldID<T> id,
  ) {
    final prefix = prefixOf(context);
    if (prefix == null) return id;
    return id.withPrefix(prefix);
  }
}

class _FormixGroupState extends State<FormixGroup> {
  @override
  Widget build(BuildContext context) {
    final parent = context.dependOnInheritedWidgetOfExactType<_FormixGroupScope>();
    final fullPrefix = parent == null ? widget.prefix : '${parent.fullPrefix}.${widget.prefix}';

    return _FormixGroupScope(
      prefix: widget.prefix,
      fullPrefix: fullPrefix,
      child: widget.child,
    );
  }
}

class _FormixGroupScope extends InheritedWidget {
  const _FormixGroupScope({
    required this.prefix,
    required this.fullPrefix,
    required super.child,
  });

  final String prefix;
  final String fullPrefix;

  @override
  bool updateShouldNotify(_FormixGroupScope oldWidget) => prefix != oldWidget.prefix || fullPrefix != oldWidget.fullPrefix;
}
