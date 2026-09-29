import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../formix.dart';

/// A widget that automatically derives field values based on other field changes.
///
/// This widget allows you to declaratively define field dependencies and
/// transformation logic, making it easy to create computed or derived fields.
///
/// Example usage:
/// ```dart
/// FormixFieldDerivation(
///   dependencies: [dobField],
///   derive: (values) {
///     final dob = values[dobField] as DateTime?;
///     if (dob == null) return null;
///
///     final now = DateTime.now();
///     int age = now.year - dob.year;
///     if (now.month < dob.month ||
///         (now.month == dob.month && now.day < dob.day)) {
///       age--;
///     }
///     return age;
///   },
///   targetField: ageField,
/// )
/// ```
class FormixFieldDerivation extends StatefulWidget {
  /// Creates a field derivation widget.
  ///
  /// [dependencies] - List of fields this derivation depends on
  /// [derive] - Function that computes the derived value from dependency values
  /// [targetField] - The field to update with the derived value
  /// [key] - Optional widget key
  const FormixFieldDerivation({
    super.key,
    required this.dependencies,
    required this.derive,
    required this.targetField,
    this.selectors,
  });

  /// The fields that this derivation depends on.
  /// When any of these fields change, the derivation will be recalculated.
  final List<FormixFieldID<dynamic>> dependencies;

  /// Optional selectors for specific dependencies.
  /// If provided, the derivation only recalculates when the selected part
  /// of the dependency value changes.
  final Map<FormixFieldID<dynamic>, Object? Function(dynamic value)>? selectors;

  /// Function that computes the derived value.
  /// Receives a map of current field values and returns the computed value.
  final dynamic Function(Map<FormixFieldID<dynamic>, dynamic>) derive;

  /// The field to update with the derived value.
  final FormixFieldID<dynamic> targetField;

  @override
  State<FormixFieldDerivation> createState() => _FormixFieldDerivationState();
}

class _FormixFieldDerivationState extends State<FormixFieldDerivation> {
  FormixController? _controller;
  Object? _initializationError;
  VoidCallback? _disposeEffect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Formix.controllerOf(context);
    if (newController == null) {
      if (mounted) {
        setState(() {
          _initializationError = 'FormixFieldDerivation used outside of Formix';
        });
      }
      return;
    }

    if (newController != _controller) {
      _controller = newController;
      _wireEffect();
    }
    _initializationError = null;
  }

  /// Subscribes to the dependency signals; the effect re-runs (and recalculates)
  /// whenever any watched dependency value changes.
  void _wireEffect() {
    _disposeEffect?.call();
    final controller = _controller;
    if (controller == null) return;
    _disposeEffect = effect(() {
      // Read (subscribe to) each dependency, respecting the optional selector.
      for (final fieldId in widget.dependencies) {
        final value = controller.valueSignal(fieldId).value;
        final selector = widget.selectors?[fieldId];
        if (selector != null) selector(value);
      }
      _recalculate();
    });
  }

  void _recalculate() {
    if (_controller == null || !mounted) return;

    try {
      // Get current values of all dependencies
      final values = <FormixFieldID<dynamic>, dynamic>{};
      for (final fieldId in widget.dependencies) {
        values[fieldId] = _controller!.getValue(fieldId);
      }

      // Compute the derived value
      final derivedValue = widget.derive(values);

      // Only update if the value has actually changed to avoid infinite loops
      final currentValue = _controller!.getValue(widget.targetField);
      if (currentValue != derivedValue) {
        // Defer the update to avoid modifying provider during widget building
        scheduleMicrotask(() {
          if (_controller != null && mounted) {
            _controller!.setValue(widget.targetField, derivedValue);
          }
        });
      }
    } catch (e) {
      // Log error in debug mode
      if (kDebugMode) {
        debugPrint('Error in field derivation for ${widget.targetField}: $e');
      }
      // In production, we silently ignore errors to prevent crashes
    }
  }

  @override
  void didUpdateWidget(FormixFieldDerivation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if dependencies or target field changed
    if (!listEquals(oldWidget.dependencies, widget.dependencies) || oldWidget.targetField != widget.targetField) {
      // Rewire the effect (and recalculate) with the new dependencies.
      _wireEffect();
    }
  }

  @override
  void dispose() {
    _disposeEffect?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixFieldDerivation',
        details: _initializationError.toString().contains('No ProviderScope found')
            ? 'Missing ProviderScope. Please wrap your application (or this form) in a ProviderScope widget.'
            : 'Error: $_initializationError',
      );
    }

    // Reactivity is handled by the effect wired in didChangeDependencies.
    // This widget doesn't render anything visible.
    return const SizedBox.shrink();
  }
}

/// A more advanced version that supports multiple derivations and more complex logic.
class FormixFieldDerivations extends StatefulWidget {
  /// Creates multiple field derivations.
  ///
  /// [derivations] - List of derivation configurations
  /// [key] - Optional widget key
  const FormixFieldDerivations({super.key, required this.derivations});

  /// List of derivation configurations.
  final List<FieldDerivationConfig> derivations;

  @override
  State<FormixFieldDerivations> createState() => _FormixFieldDerivationsState();
}

class _FormixFieldDerivationsState extends State<FormixFieldDerivations> {
  FormixController? _controller;
  Object? _initializationError;
  final List<VoidCallback> _disposeEffects = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Formix.controllerOf(context);
    if (newController == null) {
      if (mounted) {
        setState(() {
          _initializationError = 'FormixFieldDerivations used outside of Formix';
        });
      }
      return;
    }

    if (newController != _controller) {
      _controller = newController;
      _wireEffects();
    }
    _initializationError = null;
  }

  /// Wires one effect per derivation so each recalculates independently when
  /// its own dependencies change.
  void _wireEffects() {
    for (final d in _disposeEffects) {
      d();
    }
    _disposeEffects.clear();

    final controller = _controller;
    if (controller == null) return;

    for (final config in widget.derivations) {
      _disposeEffects.add(effect(() {
        for (final dep in config.dependencies) {
          final value = controller.valueSignal(dep).value;
          final selector = config.selectors?[dep];
          if (selector != null) selector(value);
        }
        _recalculate(config);
      }));
    }
  }

  void _recalculate(FieldDerivationConfig config) {
    if (_controller == null || !mounted) return;

    try {
      // Get current values of all dependencies
      final values = <FormixFieldID<dynamic>, dynamic>{};
      for (final fieldId in config.dependencies) {
        values[fieldId] = _controller!.getValue(fieldId);
      }

      // Compute the derived value
      final derivedValue = config.derive(values);

      // Only update if the value has actually changed to avoid infinite loops
      final currentValue = _controller!.getValue(config.targetField);
      if (currentValue != derivedValue) {
        // Defer the update to avoid modifying provider during widget building
        scheduleMicrotask(() {
          if (_controller != null && mounted) {
            _controller!.setValue(config.targetField, derivedValue);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in field derivation for ${config.targetField}: $e');
      }
    }
  }

  @override
  void didUpdateWidget(FormixFieldDerivations oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if derivations changed
    if (!listEquals(oldWidget.derivations, widget.derivations)) {
      // Rewire effects (and recalculate) with the new derivations.
      _wireEffects();
    }
  }

  @override
  void dispose() {
    for (final d in _disposeEffects) {
      d();
    }
    _disposeEffects.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return FormixConfigurationErrorWidget(
        message: _initializationError is String ? _initializationError as String : 'Failed to initialize FormixFieldDerivations',
        details: _initializationError.toString().contains('No ProviderScope found')
            ? 'Missing ProviderScope. Please wrap your application (or this form) in a ProviderScope widget.'
            : 'Error: $_initializationError',
      );
    }

    // Reactivity is handled by the effects wired in didChangeDependencies.
    return const SizedBox.shrink();
  }
}

/// Configuration for a single field derivation.
class FieldDerivationConfig {
  /// Creates a field derivation configuration.
  ///
  /// [dependencies] - Fields this derivation depends on
  /// [derive] - Function to compute the derived value
  /// [targetField] - Field to update with the result
  const FieldDerivationConfig({
    required this.dependencies,
    required this.derive,
    required this.targetField,
    this.selectors,
  });

  /// The fields that this derivation depends on.
  final List<FormixFieldID<dynamic>> dependencies;

  /// Optional selectors for specific dependencies.
  final Map<FormixFieldID<dynamic>, Object? Function(dynamic value)>? selectors;

  /// Function that computes the derived value from dependency values.
  final dynamic Function(Map<FormixFieldID<dynamic>, dynamic>) derive;

  /// The field to update with the derived value.
  final FormixFieldID<dynamic> targetField;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FieldDerivationConfig && listEquals(dependencies, other.dependencies) && targetField == other.targetField;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(dependencies), targetField);
}
