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
  bool _primed = false;
  List<Object?>? _lastSig;

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

  /// Subscribes to the dependency signals and recalculates whenever the watched
  /// dependency values (respecting optional selectors) actually change.
  ///
  /// The effect tracks only the dependency values; the recalculation runs
  /// [untracked] so writing the target never re-triggers it. It derives on the
  /// first run (mount) and thereafter only when a selected part changes.
  void _wireEffect() {
    _disposeEffect?.call();
    _primed = false;
    final controller = _controller;
    if (controller == null) return;
    _disposeEffect = effect(() {
      final values = <FormixFieldID<dynamic>, dynamic>{};
      final sig = <Object?>[];
      for (final fieldId in widget.dependencies) {
        final value = controller.valueSignal(fieldId).value;
        values[fieldId] = value;
        final selector = widget.selectors?[fieldId];
        sig.add(selector != null ? selector(value) : value);
      }
      final shouldDerive = !_primed || !listEquals(sig, _lastSig);
      _primed = true;
      _lastSig = sig;
      if (shouldDerive) {
        untracked(() => _recalculate(values));
      }
    });
  }

  void _recalculate(Map<FormixFieldID<dynamic>, dynamic> values) {
    if (_controller == null || !mounted) return;

    try {
      final derivedValue = widget.derive(values);
      final currentValue = _controller!.getValue(widget.targetField);
      if (currentValue != derivedValue) {
        scheduleMicrotask(() {
          if (_controller != null && mounted) {
            _controller!.setValue(widget.targetField, derivedValue);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in field derivation for ${widget.targetField}: $e');
      }
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
        details: 'Error: $_initializationError',
      );
    }
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
      // Per-config baseline so each derivation gates independently and derives on
      // its own first run, then only when a selected dependency part changes.
      var primed = false;
      List<Object?>? lastSig;
      _disposeEffects.add(effect(() {
        final values = <FormixFieldID<dynamic>, dynamic>{};
        final sig = <Object?>[];
        for (final dep in config.dependencies) {
          final value = controller.valueSignal(dep).value;
          values[dep] = value;
          final selector = config.selectors?[dep];
          sig.add(selector != null ? selector(value) : value);
        }
        final shouldDerive = !primed || !listEquals(sig, lastSig);
        primed = true;
        lastSig = sig;
        if (shouldDerive) {
          untracked(() => _recalculate(config, values));
        }
      }));
    }
  }

  void _recalculate(FieldDerivationConfig config, Map<FormixFieldID<dynamic>, dynamic> values) {
    if (_controller == null || !mounted) return;

    try {
      final derivedValue = config.derive(values);
      final currentValue = _controller!.getValue(config.targetField);
      if (currentValue != derivedValue) {
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
        details: 'Error: $_initializationError',
      );
    }
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
