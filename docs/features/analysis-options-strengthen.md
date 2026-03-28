# analysis-options-strengthen.md

## User Story

As a developer maintaining the Hike app, I want the linter to catch async-safety bugs, missing return types, and unclosed streams automatically, so that common error patterns are flagged at `flutter analyze` time rather than discovered at runtime.

## Background / Problem

Analysis report item **N4**.

`analysis_options.yaml` already enables `flutter_lints` and a set of additional rules (from `lint-rules-improvement.md`). The following high-value rules are not yet enabled:

- `always_declare_return_types` — catches functions that accidentally return `dynamic`.
- `avoid_dynamic_calls` — particularly valuable given the JSON parsing in `WeatherService` where `json['key']` is `dynamic`.
- `cancel_subscriptions` — flags `StreamSubscription` fields that are not cancelled in `dispose()`, which is the cause of GPS stream leaks.
- `close_sinks` — flags `StreamController` or `Sink` fields not closed in `dispose()`.
- `use_super_parameters` — modern Dart style for widget constructors (`super.key` instead of `Key? key`).
- `prefer_final_in_for_each` — enforces immutability in loop variables.

The absence of `avoid_dynamic_calls` is particularly significant: several JSON-parsing paths in `WeatherService` and intent-handler code use untyped map access.

## Requirements

1. Add the following rules to the `linter: rules:` section of `analysis_options.yaml`:
   ```yaml
   - always_declare_return_types
   - avoid_dynamic_calls
   - cancel_subscriptions
   - close_sinks
   - use_super_parameters
   - prefer_final_in_for_each
   ```
2. Fix all new `flutter analyze` warnings introduced by enabling these rules across the entire `lib/` directory.
3. Fix all new warnings in `test/` as well.
4. Do not suppress warnings with `// ignore:` comments except where suppression is genuinely justified (e.g. a third-party interface that cannot be changed); add a comment explaining each suppression.
5. `flutter analyze` must report zero issues after all fixes are applied.

## Non-Goals

- Enabling `always_specify_types` (too noisy for Dart type-inferred code).
- Enabling `public_member_api_docs` (not a public library).
- Changing any runtime behaviour — all changes are structural/style fixes.

## Design / Implementation Notes

**Files to touch:**
- `analysis_options.yaml` — add rules.
- Multiple files in `lib/` — fix lint violations. The most common expected violations:
  - `avoid_dynamic_calls`: `WeatherService` JSON access (`json['key']` → cast explicitly).
  - `always_declare_return_types`: anonymous callbacks and local functions without return types.
  - `cancel_subscriptions`: `StreamSubscription` fields in services without `dispose()` cancellation.
  - `use_super_parameters`: widget constructors using `Key? key` pattern.

**Strategy:** enable rules one at a time, fix violations, then enable the next, to keep each commit focused.

**Reference:** `lint-rules-improvement.md` (already implemented) for the pattern of enabling rules incrementally.

## Acceptance Criteria

- [ ] All six rules are present in `analysis_options.yaml`.
- [ ] `flutter analyze` reports zero issues in `lib/` and `test/`.
- [ ] No `// ignore: avoid_dynamic_calls` suppressions appear in JSON-parsing code (explicit casts are used instead).
- [ ] Any `// ignore:` suppressions include an explanatory comment.
