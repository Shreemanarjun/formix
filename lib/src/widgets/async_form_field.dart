import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../../formix.dart';

/// A widget that handles asynchronous values for a form field.
///
/// It waits for either an [asyncValue] (an [AsyncState]) or a [future] to resolve,
/// then populates the form field value and handles validation.
///
/// This is particularly useful for:
/// *   Loading data from an API to populate a field.
/// *   Dependent dropdowns where the second dropdown depends on an async result from the first.
/// *   Initial form data that is fetched asynchronously.
///
/// It also integrates perfectly with standard and asynchronous validators. When the
/// data resolves, the validation cycle is automatically triggered.
///
/// Example:
/// ```dart
/// FormixAsyncField<List<String>>(
///   fieldId: modelField,
///   future: api.fetchModels(selectedMake),
///   builder: (context, state) {
///     return FormixDropdownFormField<String>(
///       fieldId: modelField,
///       items: state.value?.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList() ?? [],
///     );
///   },
///   onData: (context, controller, data) {
///      // Example: Auto-select first item
///      if (data.isNotEmpty) {
///         controller.setValue(modelField, data.first);
///      }
///   },
///   loadingBuilder: (context) => Text('Loading...'),
/// )
/// ```
class FormixAsyncField<T> extends FormixFieldWidget<T> {
  /// Creates a [FormixAsyncField].
  const FormixAsyncField({
    super.key,
    required super.fieldId,
    required this.builder,
    this.asyncValue,
    this.future,
    this.loadingBuilder,
    this.asyncErrorBuilder,
    this.keepPreviousData = false,
    this.debounce,
    this.manual = false,
    this.onRetry,
    this.dependencies,
    this.onData,
    super.validator,
    super.asyncValidator,
    super.initialValue,
    super.initialValueStrategy,
    super.controller,
  }) : assert(
         asyncValue != null || future != null || manual,
         'Must provide asyncValue, future, or be in manual mode',
       );

  /// Whether to keep and display the previous successful data while loading new data.
  /// Useful for preventing UI "flicker" during dependency changes.
  final bool keepPreviousData;

  /// Optional debounce duration before executing the [future].
  final Duration? debounce;

  /// Optional list of objects that trigger a refetch when changed.
  ///
  /// *   **If `null` (default):** The field refetches whenever the [future] instance changes.
  ///     **Warning:** If you create a `Future` inside `build` (e.g., `Future.value(...)`),
  ///     it creates a new instance every time, leading to infinite loops or unwanted refetches.
  /// *   **If empty list `[]`:** The field ignores `future` instance changes and only fetches once
  ///     (unless manually refreshed). Use this when defining futures inline in `build`.
  /// *   **If populated:** The field refetches only when the values in the list change.
  final List<Object?>? dependencies;

  /// If true, the [future] will not be executed automatically.
  /// You must call `state.refresh()` to trigger the loading.
  final bool manual;

  /// An [AsyncState] providing the data (e.g. from an async signal).
  final AsyncState<T>? asyncValue;

  /// A [Future] that resolves to the data.
  final Future<T>? future;

  /// Optional callback to generate a new future when `refresh()` is called.
  /// If provided, this will be used to retry a failed operation.
  final Future<T> Function()? onRetry;

  /// Builder function that is called when data is available.
  final Widget Function(BuildContext context, FormixAsyncFieldState<T> state) builder;

  /// Optional builder shown while the data is loading.
  /// Defaults to a [CircularProgressIndicator].
  final WidgetBuilder? loadingBuilder;

  /// Optional builder shown if an error occurs during data loading.
  final Widget Function(BuildContext context, Object error)? asyncErrorBuilder;

  /// Optional callback executed when data is successfully loaded.
  ///
  /// This is useful for performing side effects, such as updating other fields
  /// based on the loaded data (e.g., auto-selecting the first item).
  ///
  /// The callback is executed in a post-frame callback, so it is safe to
  /// trigger state updates or calls to `FormixController`.
  final void Function(BuildContext context, FormixController controller, T data)? onData;

  @override
  FormixAsyncFieldState<T> createState() => FormixAsyncFieldState<T>();
}

/// State for [FormixAsyncField].
class FormixAsyncFieldState<T> extends FormixFieldWidgetState<T> {
  AsyncState<T> _asyncState = AsyncState.loading();

  /// The current state of the asynchronous operation.
  AsyncState<T> get asyncState => _asyncState;

  int _activeFutureVersion = 0;
  Timer? _debounceTimer;
  Future<T>? _currentFuture;

  /// Force a re-execution (if using [future]) or refresh (if using [asyncValue]).
  Future<void> refresh() async {
    final widget = this.widget as FormixAsyncField<T>;
    if (widget.onRetry != null) {
      _currentFuture = widget.onRetry!();
    }
    _initAsyncState(force: true);
  }

  @override
  void initState() {
    super.initState();
    final widget = this.widget as FormixAsyncField<T>;
    _currentFuture = widget.future;

    // Ensure initial state is correctly set if asyncValue is provided
    if (widget.asyncValue != null) {
      _asyncState = widget.asyncValue!;
    }

    if (!widget.manual) {
      _initAsyncState();
    }
  }

  void _initAsyncState({bool force = false}) {
    final widget = this.widget as FormixAsyncField<T>;

    if (widget.asyncValue != null) {
      _asyncState = widget.asyncValue!;
      _syncValue();
      return;
    }

    if (_currentFuture != null) {
      if (widget.debounce != null && !force) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(widget.debounce!, () => _executeFuture());
      } else {
        _executeFuture();
      }
    } else {
      // If there's no future, ensure we're not stuck in pending
      _updatePendingState(false);
    }
  }

  void _executeFuture() {
    final widget = this.widget as FormixAsyncField<T>; // Still needed for keepPreviousData
    if (_currentFuture == null) return;

    final version = ++_activeFutureVersion;

    if (!widget.keepPreviousData || !_asyncState.hasValue) {
      setState(() {
        _asyncState = AsyncState.loading();
      });
      _updatePendingState(true);
    }

    _currentFuture!
        .then((data) {
          if (mounted && version == _activeFutureVersion) {
            setState(() {
              _asyncState = AsyncState.data(data);
            });
            _updatePendingState(false);
            _syncValue();
          }
        })
        .catchError((e, st) {
          if (mounted && version == _activeFutureVersion) {
            setState(() {
              _asyncState = AsyncState.error(e, st);
            });
            _updatePendingState(false);
          }
        });
  }

  void _updatePendingState(bool isPending) {
    if (hasController) {
      // Use microtask to avoid "Tried to modify a provider while the widget tree was building"
      // during initState/didUpdateWidget.
      Future.microtask(() {
        if (mounted && hasController) {
          controller.setPending(widget.fieldId, isPending);
        }
      });
    }
  }

  @override
  void didUpdateWidget(FormixAsyncField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final widget = this.widget as FormixAsyncField<T>;
    if (widget.asyncValue != oldWidget.asyncValue) {
      if (!widget.manual) {
        _initAsyncState();
      }
    } else if (widget.future != oldWidget.future) {
      final changed =
          widget.dependencies == null ||
          !const ListEquality().equals(
            widget.dependencies,
            oldWidget.dependencies,
          );

      if (changed) {
        // Update current future if the widget's future changed
        _currentFuture = widget.future;

        if (!widget.manual) {
          _initAsyncState();
        }
      }
    }
  }

  void _syncValue() {
    if (_asyncState.hasValue && !_asyncState.isLoading && !_asyncState.hasError) {
      final val = _asyncState.value as T;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Trigger the user's onData callback
          final widget = this.widget as FormixAsyncField<T>;
          if (widget.onData != null && hasController) {
            widget.onData!(context, controller, val);
          }

          if (!const DeepCollectionEquality().equals(value, val)) {
            didChange(val);
          }
        }
      });
    }
  }

  @override
  void onReset() {
    final widget = this.widget as FormixAsyncField<T>;
    if (!widget.manual) {
      refresh();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget as FormixAsyncField<T>;

    return _asyncState.map(
      data: (_) => widget.builder(context, this),
      error: (e, [_]) => widget.asyncErrorBuilder?.call(context, e) ?? Text('Error: $e'),
      loading: () => widget.loadingBuilder?.call(context) ?? const Center(child: CircularProgressIndicator()),
    );
  }
}
