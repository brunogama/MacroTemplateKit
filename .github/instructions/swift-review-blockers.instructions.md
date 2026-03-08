---
applyTo:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
description: "Ultra-strict merge blockers, architecture gates, and test expectations for Swift reviews"
---

# Code review guidance for Copilot

- Treat these items as hard blockers:
  - any change that breaks target layering, especially core targets importing infrastructure concerns
  - added or changed behavior without tests unless the PR clearly states the change is doc-only
  - public or open API additions without explicit review of stability, naming, docs, and tests
- Require Swift 6 language mode and Complete strict concurrency checking across all actively developed targets, including test targets.
- Require clean Debug and Release builds for supported platforms and zero compiler warnings in CI.
- Do not accept suppressed warnings, custom compiler escape hatches, or `@preconcurrency` shims without a written reason and removal plan.
- Do not allow `#if DEBUG` to change correctness, security, data flow, or isolation behavior.
- Prefer value types, small focused types, and deterministic, testable routing. Avoid implicit global singletons.
- Keep access control tight. Module boundaries should match architecture boundaries, and dependencies must continue to point inward.
- Reject designs that make invalid states easy to represent, weaken invariants through convenience APIs, or expand public surface area without documentation.

## Tests expected

- Every bug fix must include a regression test.
- New concurrency code must cover isolation, cancellation, reentrancy-sensitive behavior, ordering assumptions, and timeout behavior.
- Security-sensitive code must cover malformed input, authorization failure, and secret leakage.
- SwiftUI stateful flows must be covered via view-model, reducer, or UI tests as appropriate.
- Vec0 or routing changes need matrix tests plus equivalence against the SQL baseline.
- Index changes need nearest-neighbor correctness tests plus a recall regression guard.
- Quantization changes need precision and recall bounds plus round-trip property coverage.
