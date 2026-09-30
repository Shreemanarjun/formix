import 'package:flutter/material.dart';
import '../../formix.dart';
import 'ancestor_validator.dart';

/// A widget for managing dynamic lists of items in a form.
///
/// Use [FormixArray] when you need to render a list of fields that can be
/// dynamically added or removed.
class FormixArray<T> extends StatefulWidget {
  /// Creates a form array widget.
  const FormixArray({
    super.key,
    required this.id,
    required this.itemBuilder,
    this.emptyBuilder,
    this.scrollable = false,
  });

  /// The unique identifier for this array.
  final FormixArrayID<T> id;

  /// Builder function for individual items.
  ///
  /// Receives the [index] and a unique [itemId] that can be used for
  /// [FormixTextFormField] or other field widgets.
  final Widget Function(
    BuildContext context,
    int index,
    FormixFieldID<T> itemId,
    FormixScope scope,
  )
  itemBuilder;

  /// Optional builder when the array is empty.
  final Widget Function(BuildContext context, FormixScope scope)? emptyBuilder;

  /// Whether to use a [ListView] instead of a [Column].
  final bool scrollable;

  @override
  State<FormixArray<T>> createState() => _FormixArrayState<T>();
}

class _FormixArrayState<T> extends State<FormixArray<T>> {
  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'FormixArray',
      requireFormix: false,
    );

    if (errorWidget != null) return errorWidget;

    final controller = Formix.controllerOf(context);
    if (controller == null) {
      return const FormixConfigurationErrorWidget(
        message: 'Failed to initialize FormixArray',
        details: 'FormixArray must be used inside a Formix widget.',
      );
    }

    final scope = FormixScope(
      context: context,
      controller: controller,
    );

    // Resolve the array ID based on surrounding form groups
    final resolvedId = FormixGroup.resolve(context, widget.id) as FormixArrayID<T>;

    // Watch the array value reactively inside a SignalBuilder so this rebuilds
    // only when the array length/content changes.
    return SignalBuilder(
      builder: (context) {
        final items = scope.watchArray(resolvedId);

        if (items.isEmpty && widget.emptyBuilder != null) {
          return widget.emptyBuilder!(context, scope);
        }

        Widget buildItem(int index) {
          final itemId = resolvedId.item(index);
          return FormixGroup(
            prefix: '${widget.id.key}[$index]',
            child: widget.itemBuilder(context, index, itemId, scope),
          );
        }

        if (widget.scrollable) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) => buildItem(index),
          );
        }

        return Column(
          children: List.generate(items.length, (index) {
            return buildItem(index);
          }),
        );
      },
    );
  }
}
