# Formix Benchmarks — Riverpod (0.1.x) vs Signals (0.2.0)

Formix 0.2.0 replaced its Riverpod core with [signals](https://pub.dev/packages/signals_flutter).
This is a like-for-like comparison of the **same benchmark suite** (`test/formix_benchmarks.dart`,
`test/performance_stress_test.dart`) run against both engines.

> Methodology: each metric is warmed up, then averaged over 3 runs × 1000 iterations
> (dependency-chain metrics use a single large run). Numbers vary by machine; what
> matters is the **relative** result on the same hardware. Reproduce with:
> `flutter test test/formix_benchmarks.dart test/performance_stress_test.dart`.

## Core reactive overhead

| Metric                                   | 0.1.x (Riverpod) | 0.2.0 (Signals) | Change      |
| ---------------------------------------- | ---------------: | --------------: | ----------- |
| Pure Formix overhead — per rebuild       |        0.097 ms  |       0.088 ms  | **−9.3%**   |
| Pure Formix — mount/unmount per cycle    |        0.054 ms  |       0.049 ms  | **−9.3%**   |
| Full widget passive rebuild (Material)   |        9.548 ms  |       9.392 ms  | −1.6%       |
| Field mount/unmount cycle                |        1.584 ms  |       1.189 ms  | **−24.9%**  |

## Scale

| Metric                                   | 0.1.x (Riverpod) | 0.2.0 (Signals) |
| ---------------------------------------- | ---------------: | --------------: |
| Bulk-update 1000 fields (single batch)   |         ~< 1000 ms |         286 ms |
| Trigger 100,000-field dependency chain   |          ~160 ms |          196 ms |

## Why signals is faster (and simpler)

- **Surgical rebuilds by construction.** Each field/aspect is a memoized `Computed`
  slice. A keystroke only notifies the widgets that read *that* field's slice —
  there is no provider-graph traversal and no whole-`select` re-evaluation fan-out.
- **One reactivity system, not two.** 0.1.x ran a Riverpod `Notifier` *and* a
  `ValueNotifier`/`Stream` compatibility layer side by side. 0.2.0 collapses both
  into a single `Signal<FormixData>` + `Computed` slices, deleting the hand-rolled
  delta-notification, combined-notifier, and family-provider machinery.
- **No `ProviderScope`.** Zero setup/attachment cost at the tree root.
- **Aggregates are computed, not counted.** `isValid`/`isDirty`/`errorCount` are
  `Computed` values that recompute only when a dependency changes, replacing manual
  count bookkeeping.

## Surgical-rebuild guarantee

`test/benchmark_surgical_rebuild_test.dart` asserts the key behavioural win: with
1000 fields each rendered by its own reactive builder, updating **one** field
triggers exactly **one** widget rebuild — the other 999 do not rebuild. A single
`batchUpdate` of all 1000 fields completes in ~6 ms.

## 0.2.x correctness/perf guards

- **No-op write guard:** re-setting a field to its current value allocates nothing and
  fires no notification (the write pipeline's apply-guard skips unchanged state). Verified
  in `test/type_safe_additions_test.dart`.
- **Async generation guard:** each scheduled async validation carries a generation token; a
  superseded, still-in-flight result is dropped instead of overwriting newer state. This is
  a *correctness* fix (prevents stale-write races on fast typing), not a throughput change —
  its cost is one map lookup + int compare per async completion.
- **Already-optimal, verified:** transitive-dependents are memoized (`_transitiveDependentsCache`),
  and a multi-field batch produces a single `FormixData` snapshot (not one per field).

> Identified but deferred: migrating `FormixData`'s five maps to structural-sharing `IMap`
> would drop the per-write `{...values}` copy from O(n) to O(log n). The payoff is material
> only on very large (1000+ field) forms — pure per-rebuild overhead is already ~0.1 ms vs
> Flutter's own `TextFormField` at ~12 ms — so it is left as a separately-benchmarked change.
