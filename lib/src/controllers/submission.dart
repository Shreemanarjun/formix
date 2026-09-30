/// The submission lifecycle of a form, modelled as a sealed set of states so
/// the UI can `switch` over it exhaustively — no impossible states, no boolean
/// soup of `isSubmitting`/`hasError`/`isSuccess` flags.
///
/// Read it reactively via `FormixController.submissionSignal`:
/// ```dart
/// SignalBuilder(builder: (context) {
///   return switch (controller.submissionSignal.value) {
///     FormixSubmissionIdle() => const Text('Ready'),
///     FormixSubmissionSubmitting() => const CircularProgressIndicator(),
///     FormixSubmissionSuccess() => const Text('Saved!'),
///     FormixSubmissionError(:final error) => Text('Failed: $error'),
///   };
/// });
/// ```
sealed class FormixSubmission {
  /// Const base constructor.
  const FormixSubmission();

  /// Nothing is in flight.
  const factory FormixSubmission.idle() = FormixSubmissionIdle;

  /// A submission is currently running.
  const factory FormixSubmission.submitting() = FormixSubmissionSubmitting;

  /// The last submission's `onValid` completed without throwing.
  const factory FormixSubmission.success() = FormixSubmissionSuccess;

  /// The last submission's `onValid` threw [error].
  const factory FormixSubmission.error(Object error, [StackTrace? stackTrace]) = FormixSubmissionError;

  /// Whether a submission is currently running.
  bool get isInProgress => this is FormixSubmissionSubmitting;
}

/// Nothing in flight (the initial state).
final class FormixSubmissionIdle extends FormixSubmission {
  /// Creates an idle state.
  const FormixSubmissionIdle();

  @override
  bool operator ==(Object other) => other is FormixSubmissionIdle;
  @override
  int get hashCode => (FormixSubmissionIdle).hashCode;
}

/// A submission is running.
final class FormixSubmissionSubmitting extends FormixSubmission {
  /// Creates a submitting state.
  const FormixSubmissionSubmitting();

  @override
  bool operator ==(Object other) => other is FormixSubmissionSubmitting;
  @override
  int get hashCode => (FormixSubmissionSubmitting).hashCode;
}

/// The last submission succeeded.
final class FormixSubmissionSuccess extends FormixSubmission {
  /// Creates a success state.
  const FormixSubmissionSuccess();

  @override
  bool operator ==(Object other) => other is FormixSubmissionSuccess;
  @override
  int get hashCode => (FormixSubmissionSuccess).hashCode;
}

/// The last submission failed with [error].
final class FormixSubmissionError extends FormixSubmission {
  /// Creates an error state carrying the thrown [error] and optional [stackTrace].
  const FormixSubmissionError(this.error, [this.stackTrace]);

  /// The object thrown by `onValid`.
  final Object error;

  /// The stack trace captured when [error] was thrown, if any.
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) => other is FormixSubmissionError && other.error == error;
  @override
  int get hashCode => Object.hash(FormixSubmissionError, error);
}
