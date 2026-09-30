import 'package:flutter/material.dart';
import '../../formix.dart';
import 'ancestor_validator.dart';

/// A sliver widget for managing dynamic lists of items in a form.
///
/// Use [SliverFormixArray] when you need to render a list of fields inside
/// a [CustomScrollView].
class SliverFormixArray<T> extends StatefulWidget {
  /// Creates a sliver form array widget.
  const SliverFormixArray({
    super.key,
    required this.id,
    required this.itemBuilder,
    this.emptyBuilder,
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
  ///
  /// The returned widget will be automatically wrapped in a [SliverToBoxAdapter]
  /// if it is not already a sliver.
  final Widget Function(BuildContext context, FormixScope scope)? emptyBuilder;

  @override
  State<SliverFormixArray<T>> createState() => _SliverFormixArrayState<T>();
}

class _SliverFormixArrayState<T> extends State<SliverFormixArray<T>> {
  FormixController? _controller;
  FormixArrayID<T>? _resolvedId;

  void _onArrayChanged() {
    if (mounted) setState(() {});
  }

  void _bind(FormixController controller, FormixArrayID<T> resolvedId) {
    // A sliver can't be wrapped in a (box-producing) SignalBuilder, so we
    // subscribe to the array field via the controller's field listener and
    // rebuild this element when it changes.
    if (_controller == controller && _resolvedId == resolvedId) return;
    if (_controller != null && _resolvedId != null) {
      _controller!.removeFieldListener(_resolvedId!, _onArrayChanged);
    }
    _controller = controller;
    _resolvedId = resolvedId;
    controller.addFieldListener(resolvedId, _onArrayChanged);
  }

  @override
  void dispose() {
    if (_controller != null && _resolvedId != null) {
      _controller!.removeFieldListener(_resolvedId!, _onArrayChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorWidget = FormixAncestorValidator.validate(
      context,
      widgetName: 'SliverFormixArray',
      requireFormix: false,
    );

    if (errorWidget != null) {
      return SliverToBoxAdapter(child: errorWidget);
    }

    final controller = Formix.controllerOf(context);
    if (controller == null) {
      return const SliverToBoxAdapter(
        child: FormixConfigurationErrorWidget(
          message: 'Failed to initialize SliverFormixArray',
          details: 'SliverFormixArray must be used inside a Formix widget.',
        ),
      );
    }

    final scope = FormixScope(
      context: context,
      controller: controller,
    );

    // Resolve the array ID based on surrounding form groups
    final resolvedId = FormixGroup.resolve(context, widget.id) as FormixArrayID<T>;

    // Subscribe to changes so the sliver rebuilds when the array updates.
    _bind(controller, resolvedId);

    final items = controller.getValue(resolvedId) ?? <T>[];

    if (items.isEmpty && widget.emptyBuilder != null) {
      final child = widget.emptyBuilder!(context, scope);
      return SliverToBoxAdapter(child: child);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final itemId = resolvedId.item(index);
          return FormixGroup(
            prefix: '${widget.id.key}[$index]',
            child: widget.itemBuilder(context, index, itemId, scope),
          );
        },
        childCount: items.length,
      ),
    );
  }
}
