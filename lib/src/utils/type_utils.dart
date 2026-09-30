/// Internal utility for type comparison.
///
/// Uses the same definition as the language specification for when two
/// types are the same. Currently the same as mutual sub-typing.
bool sameTypes<S, V>() {
  // `func` is only ever type-reified (never invoked), so its body is unreachable
  // by design — the whole trick is comparing its generic bound against V.
  void func<X extends S>() {} // coverage:ignore-line
  // Dart spec says this is only true if S and V are "the same type".
  return func is void Function<X extends V>();
}
