import 'dart:async';
import 'package:meta/meta.dart';
import 'validation_keys.dart';

/// A fluent API for creating field validators.
/// Inspired by Zod and other schema validation libraries.
class FormixValidators {
  /// Start a validator chain for a String field.
  static StringValidator string() => StringValidator([]);

  /// Start a validator chain for a Numeric field.
  static NumberValidator<T> number<T extends num>() => NumberValidator<T>([]);

  /// Start a validator chain for a [DateTime] field.
  static DateTimeValidator date() => DateTimeValidator([]);

  /// Start a validator chain for any type.
  static GenericValidator<T> any<T>() => GenericValidator<T>([]);
}

/// Base class for validator chains including async support.
abstract class ValidatorChain<T, Self extends ValidatorChain<T, Self>> {
  /// Synchronous validators in the chain.
  @protected
  final List<String? Function(T?)> syncValidators;

  /// Asynchronous validators in the chain.
  @protected
  final List<Future<String?> Function(T?)> asyncValidators = [];

  /// Optional debounce duration for asynchronous validation.
  Duration? debounceDuration;

  /// Creates a [ValidatorChain].
  ValidatorChain(this.syncValidators);

  Self _add(String? Function(T?) validator) {
    syncValidators.add(validator);
    return this as Self;
  }

  /// Mark the field as required.
  Self required([String? message]) {
    return _add((val) {
      if (val == null) return message ?? FormixValidationKeys.required;
      if (val is String && val.trim().isEmpty) {
        return message ?? FormixValidationKeys.required;
      }
      return null;
    });
  }

  /// Add a custom validation rule.
  Self custom(String? Function(T?) validator) => _add(validator);

  /// Add an asynchronous validation rule.
  Self async(Future<String?> Function(T?) validator) {
    asyncValidators.add(validator);
    return this as Self;
  }

  /// Sets the debounce duration for asynchronous validation.
  Self debounce(Duration duration) {
    debounceDuration = duration;
    return this as Self;
  }

  /// Builds the combined synchronous validator.
  String? Function(T?) build() {
    return (T? value) {
      for (final validator in syncValidators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  /// Builds the combined asynchronous validator.
  Future<String?> Function(T?) buildAsync() {
    return (T? value) async {
      // Async validators only run if sync validators pass
      final syncError = build()(value);
      if (syncError != null) return null;

      for (final validator in asyncValidators) {
        final error = await validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}

/// Validator chain specifically for [String] types.
class StringValidator extends ValidatorChain<String, StringValidator> {
  /// Creates a [StringValidator].
  StringValidator(super.syncValidators);

  /// Validates that the string is a valid email address.
  StringValidator email([String? message]) {
    return _add((val) {
      if (val == null || val.isEmpty) return null;
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(val)) {
        return message ?? FormixValidationKeys.invalidEmail;
      }
      return null;
    });
  }

  /// Validates that the string has at least [length] characters.
  StringValidator minLength(int length, [String? message]) {
    return _add((val) {
      if (val == null || val.isEmpty) return null;
      if (val.length < length) {
        return message ??
            FormixValidationKeys.withParam(
              FormixValidationKeys.minLength,
              length,
            );
      }
      return null;
    });
  }

  /// Validates that the string has at most [length] characters.
  StringValidator maxLength(int length, [String? message]) {
    return _add((val) {
      if (val == null || val.isEmpty) return null;
      if (val.length > length) {
        return message ??
            FormixValidationKeys.withParam(
              FormixValidationKeys.maxLength,
              length,
            );
      }
      return null;
    });
  }

  /// Validates that the string matches the given [regex].
  StringValidator pattern(RegExp regex, [String? message]) {
    return _add((val) {
      if (val == null || val.isEmpty) return null;
      if (!regex.hasMatch(val)) {
        return message ?? FormixValidationKeys.invalidFormat;
      }
      return null;
    });
  }
}

/// Validator chain specifically for numeric types.
class NumberValidator<T extends num> extends ValidatorChain<T, NumberValidator<T>> {
  /// Creates a [NumberValidator].
  NumberValidator(super.syncValidators);

  /// Validates that the numeric value is at least [min].
  NumberValidator<T> min(T min, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (val < min) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.min, min);
      }
      return null;
    });
  }

  /// Validates that the numeric value is at most [max].
  NumberValidator<T> max(T max, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (val > max) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.max, max);
      }
      return null;
    });
  }

  /// Validates that the numeric value is positive.
  NumberValidator<T> positive([String? message]) => min(
    0 as T,
    message ?? FormixValidationKeys.withParam(FormixValidationKeys.min, 0),
  );

  /// Validates that the numeric value is within `[min, max]` (inclusive).
  NumberValidator<T> between(T min, T max, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (val < min) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.min, min);
      }
      if (val > max) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.max, max);
      }
      return null;
    });
  }
}

/// Validator chain specifically for [DateTime] types.
class DateTimeValidator extends ValidatorChain<DateTime, DateTimeValidator> {
  /// Creates a [DateTimeValidator].
  DateTimeValidator(super.syncValidators);

  /// Validates that the date is on or after [min].
  DateTimeValidator after(DateTime min, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (val.isBefore(min)) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.minDate, min.millisecondsSinceEpoch);
      }
      return null;
    });
  }

  /// Validates that the date is on or before [max].
  DateTimeValidator before(DateTime max, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (val.isAfter(max)) {
        return message ?? FormixValidationKeys.withParam(FormixValidationKeys.maxDate, max.millisecondsSinceEpoch);
      }
      return null;
    });
  }

  /// Validates that the date is within `[min, max]` (inclusive).
  DateTimeValidator between(DateTime min, DateTime max, [String? message]) => after(min, message).before(max, message);
}

/// Validator chain for any generic type.
class GenericValidator<T> extends ValidatorChain<T, GenericValidator<T>> {
  /// Creates a [GenericValidator].
  GenericValidator(super.syncValidators);

  /// Validates that the value is one of [options].
  GenericValidator<T> oneOf(List<T> options, [String? message]) {
    return _add((val) {
      if (val == null) return null;
      if (!options.contains(val)) {
        return message ?? FormixValidationKeys.invalidSelection;
      }
      return null;
    });
  }
}
