# Code review guidance for Copilot

Apply these project-specific rules when reviewing changes in `Sources/` and `Tests/`.

## Hard blockers
- Any change that breaks target layering (Core targets importing GRDB/SQLite/CoreML/etc.).
- Unsafe concurrency (data races, non-Sendable escapes, missing actor isolation) given strict concurrency settings.
- Added/changed behavior without tests (unless PR explicitly states why and the change is doc-only).

## Strong preferences
- Prefer value types and small focused types.
- Avoid implicit global singletons.
- Keep routing logic deterministic and testable.

## Tests expected per area
- `Vec0` / routing changes: matrix tests + equivalence vs SQL baseline.
- Index changes: nearest-neighbor correctness + recall regression guard.
- Quantization changes: precision/recall bounds + round-trip properties.

- # Ultra-Strict Swift Merge-Gate Checklist

Below is a merge-gate checklist, not a style guide. In an ultra-strict review, any unchecked **Blocker** rejects the PR.

For the baseline, require **Swift 6 language mode** and **Complete strict concurrency checking** on every target.

---

## 1) Build, Toolchain, and Review Gates

### Blockers
- Builds cleanly in Debug and Release for every supported platform.
- Zero compiler warnings in CI.
- Swift 6 language mode is enabled everywhere that is under active development.
- Strict concurrency checking is **Complete** everywhere, including test targets.
- No `#if DEBUG` logic changes correctness, security, data flow, or isolation behavior.
- No suppressed warnings, compiler flags, or `@preconcurrency` shims without a written reason and removal plan.
- No API added to `public` or `open` without explicit review of stability, naming, docs, and tests.

### Majors
- Availability annotations are correct.
- Build settings are consistent across modules.
- Package/Xcode target boundaries match architecture boundaries.
- External dependencies are pinned and justified.

---

## 2) Concurrency and Isolation

`Sendable`, actor isolation, and structured concurrency are the default bar. Cancellation in Swift is cooperative, not magical, and every `await` inside actor-isolated code must be treated as a reentrancy boundary. Apple also provides `Mutex` as a synchronization primitive when actor isolation is not the right fit.

### Blockers
- No shared mutable state exists outside one of these protections:
  - actor isolation
  - `@MainActor`
  - `Mutex` / atomics / equivalent synchronization
- Every type crossing concurrency domains is actually safe to send.
- No `@unchecked Sendable` unless there is a written proof of invariants, ownership, and synchronization.
- No mutable global state.
- No singleton with unsynchronized mutable storage.
- No `Task.detached` unless ownership, lifetime, cancellation, and priority are explicitly correct.
- No `nonisolated` escape hatch that weakens safety without a real performance or interop reason.
- Actor-isolated methods do not assume state observed before `await` is still valid after `await`.
- No closure passed across domains captures non-`Sendable` mutable state.
- No continuation can be resumed more than once, or forgotten entirely.
- No blocking calls inside async contexts on executors that must stay responsive.
- Main-actor code is not used as a dumping ground for unrelated work.

### Majors
- Actor boundaries are explicit and make architectural sense.
- Long-running loops and expensive operations check cancellation.
- Child tasks in task groups do not leak references or mutate parent-owned state unsafely.
- Async APIs define ownership: who starts them, who cancels them, who awaits them.
- Priority is chosen intentionally, not left accidental.
- Actor hopping is minimized in hot paths.
- Bridging from callbacks, delegates, Combine, GCD, or Objective-C preserves isolation guarantees.

### Immediate Reject Patterns
- `DispatchQueue.main.async` used to silence actor-isolation problems instead of fixing ownership.
- `nonisolated(unsafe)` or `@unchecked Sendable` added just to make the compiler stop complaining.
- Background code reading or mutating view model state directly.
- “It seems to work” used as the concurrency proof.

---

## 3) SwiftUI and UI Correctness

SwiftUI expects UI work to stay aligned with main-actor behavior. Its `.task` modifier ties async work to the view lifetime and cancels when the view disappears or the task identity changes. Apple also recommends keeping time-sensitive UI updates synchronous and separating long-running async work from view logic.

### Blockers
- `body` is pure: no network, disk, crypto, database, analytics, logging side effects, or object construction with side effects.
- UI state mutations happen on the main actor.
- Views do not own business logic they should not own.
- View models / observable state are not recreated accidentally during render.
- No async work is started from rendering paths except through the intended lifecycle modifiers.
- No feedback loop from `onChange`, `onReceive`, bindings, or observation that can cause runaway updates.
- No hidden dependency on view redraw timing.

### Majors
- `.task(id:)` uses an identity that is intentional.
- Async work launched from views is cancellation-aware.
- Loading, optimistic updates, and error states are explicit.
- Animation-triggering state changes that must feel immediate happen synchronously before suspension points.
- Heavy work lives outside the view layer.
- Preview code does not rely on production services or global state.
- Navigation state is deterministic and testable.
- No large computed data transformations inside `body`.

### SwiftUI-Specific Red Flags
- `Task {}` sprinkled across button handlers and modifiers with no ownership model.
- Observable object created in `body`.
- Network requests initiated from computed properties.
- List rows doing image decoding, JSON parsing, or date formatting in render hot paths.

---

## 4) Memory, Ownership, and Lifetime

Swift uses ARC, closures can create reference cycles, and the language enforces memory-safety rules around conflicting access. That does not mean leaks, lifetime bugs, or ownership confusion disappear on their own.

### Blockers
- No retain cycles between owners, delegates, closures, tasks, timers, observers, or async streams.
- Capture lists are deliberate, not cargo cult.
- Lifetimes of timers, notifications, tasks, observation tokens, delegates, and subscriptions are explicit.
- No unbounded cache or in-memory accumulation without eviction.
- No use-after-cancel assumptions on tasks, streams, or callbacks.
- No force-unwrapped weak references.
- No `unowned` unless lifetime is mathematically guaranteed.

### Majors
- Large value copies are intentional.
- Reference semantics are used only when identity or shared mutable state is required.
- `deinit` is not carrying business-critical cleanup that may never run when expected.
- Temporary buffers, images, and decoded payloads are not retained longer than needed.
- Objective-C bridging hot paths are reviewed for autorelease pressure where relevant.
- Closure ownership is readable at the call site.

### Ownership Questions Every Review Should Ask
- Who owns this object?
- Who may mutate it?
- On which actor / thread / executor?
- When does it die?
- What cancels it?
- What happens if the owner disappears mid-flight?

---

## 5) Security, Privacy, and Secrets Handling

Keychain is the standard encrypted store for small sensitive data. Secure Enclave exists for stronger protection of private keys. ATS improves privacy and data integrity for network traffic. Privacy manifests are required for required-reason APIs used by apps and third-party SDKs.

### Blockers
- No secrets in source, test fixtures, screenshots, logs, crash reports, or `Info.plist`.
- Credentials, refresh tokens, and small secrets are stored in Keychain, not `UserDefaults`.
- Private keys use Secure Enclave where the threat model justifies it.
- ATS is not weakened globally.
- Any ATS exception is narrowly scoped, documented, and justified.
- Manual trust evaluation, custom pinning, or certificate overrides are security-reviewed and tested.
- No user-sensitive data is logged in plaintext.
- Privacy manifest is present and accurate for app and included SDKs where required.
- Entitlements are least-privilege only.
- Deep links, file URLs, universal links, pasteboard, and imported files are validated before use.
- No fingerprinting-like collection hidden behind analytics or diagnostics.

### Majors
- Sensitive values are redacted in logs and debug descriptions.
- Data collection is minimized.
- Retention and deletion rules are defined.
- Errors do not leak secrets or internal topology.
- Clipboard, screenshots, backups, and sharing flows are reviewed for sensitive data exposure.
- Auth flows defend against replay, stale session, and race conditions.

### Immediate Reject Patterns
- Token in `UserDefaults`.
- `NSAllowsArbitraryLoads = YES` without a very narrow reason.
- Trusting self-signed certs in production without device-managed roots or equivalent design.
- API keys shipped in the client as if they were secrets.

---

## 6) Networking, Persistence, and Data Boundaries

### Blockers
- External input is never force-unwrapped or force-decoded.
- Network and persistence boundaries validate input shape, size, and semantics.
- DTOs are separate from domain models where that separation matters.
- Partial failures, retries, and offline behavior are designed, not accidental.
- File system writes are atomic where corruption matters.
- Data races cannot occur between persistence and UI state propagation.

### Majors
- Timeouts, retry policy, and backoff are explicit.
- Idempotency is considered for retried operations.
- Migrations are versioned and tested.
- Dates, locales, and calendars are handled explicitly.
- `Codable` defaults are not silently masking server bugs.
- Error mapping produces actionable user and telemetry outcomes.

---

## 7) API Design and Architecture

Access control exists to hide implementation details and constrain surface area. In strict review, overexposed APIs are defects, not polish issues.

### Blockers
- Invalid states are unrepresentable where practical.
- Domain invariants are enforced at construction time.
- No primitive obsession for core business concepts.
- No convenience API that weakens safety relative to the core API.
- Public API names are stable, unambiguous, and follow one mental model.

### Majors
- Prefer value types unless identity is required.
- Protocols are small and behavior-oriented.
- Generic abstractions pay for themselves.
- No hidden global dependencies.
- Modules expose the minimum possible surface.
- Errors are typed where recovery matters.
- Dependencies point inward; UI does not leak into domain and infrastructure does not leak into view logic.

---

## 8) Performance and Responsiveness

### Blockers
- No blocking I/O, heavy parsing, crypto, or image work on the main actor.
- No accidental quadratic behavior in rendering, diffing, sorting, filtering, or reconciliation paths.
- No hot-path formatter creation, decoder creation, or repeated expensive allocations in tight loops.

### Majors
- Performance-critical code is measured, not guessed.
- Copy cost of large structs is understood.
- Async boundaries do not create executor thrash.
- Caches have eviction and bounded growth.
- Backpressure exists for streams and producer/consumer pipelines.
- Batching is used where latency and throughput justify it.

---

## 9) Error Handling and Resilience

### Blockers
- No `try!` or force unwrap in production paths unless a crash is the explicitly reviewed policy.
- No empty `catch`.
- No lossy fallback that silently corrupts business behavior.
- Cancellation is not reported as a generic failure.
- User-visible operations always reach a terminal state: success, cancellation, retryable failure, or hard failure.

### Majors
- Errors preserve diagnostic context without leaking secrets.
- Retryability is encoded or inferable.
- Domain errors are not raw transport errors.
- Recovery paths are tested.

---

## 10) Testing Requirements

### Blockers
- Every bug fix has a regression test.
- New concurrency code has tests for:
  - isolation
  - cancellation
  - reentrancy-sensitive behavior
  - ordering assumptions
  - timeout behavior
- Security-sensitive code has tests for malformed input, authorization failure, and secret leakage.
- SwiftUI stateful flows are covered either via view-model tests, reducer tests, or UI tests, depending on architecture.

### Majors
- Pure transformations use parameterized or property-based tests where useful.
- Performance-sensitive code has benchmarks.
- Persistence changes have migration tests.
- Network clients have contract tests or strong fixtures.
- Tests avoid time-based flakiness and hidden global state.

---

## 11) Interop and Legacy Boundaries

### Blockers
- Objective-C, C, delegates, callbacks, notifications, and Combine boundaries do not weaken Swift isolation guarantees.
- Imported legacy APIs are wrapped so unsafe threading assumptions do not leak through.
- FFI or pointer-based code documents ownership and lifetime precisely.

### Majors
- Legacy code is quarantined behind narrow adapters.
- Bridge layers translate errors, threading, and data ownership explicitly.
- Unsafe APIs are not exposed to broad call sites.

---

## 12) Documentation and Operational Readiness

### Blockers
- Non-obvious invariants are written down in code comments or docs.
- Every unsafe, unchecked, security exception, or concurrency escape hatch has a justification comment.
- Public APIs include usage constraints.
- Feature flags, migrations, and rollout constraints are documented.

### Majors
- Metrics, logs, and traces exist for critical paths.
- Crash-prone or security-sensitive modules have runbooks.
- Known technical debt is tracked with an owner and exit criteria.

---

## 13) Ultra-Strict Automatic Rejection List

Reject immediately if the PR does any of the following:

- Adds `@unchecked Sendable` with no proof.
- Adds `Task.detached` with no owner/cancellation model.
- Uses `DispatchQueue.main.async` to paper over actor isolation.
- Stores secrets outside Keychain when they should be protected.
- Weakens ATS broadly.
- Performs side effects from `SwiftUI.View.body`.
- Introduces force unwraps on external data.
- Introduces shared mutable global state.
- Hides failures with `try?`, empty `catch`, or “best effort” behavior in critical logic.
- Expands public API surface without tests and documentation.

---

## 14) Review Verdict Rubric

- **Reject:** any Blocker unchecked.
- **Fix before release:** Blockers clear, but Majors remain in security, concurrency, persistence, or UI correctness.
- **Accept:** no Blockers, Majors either resolved or explicitly ticketed with owner, scope, and deadline.

## 15) Swift Macros Code Expansion

- All swift macro code expansion must be built by swift ast syntax# Code review guidance for Copilot

Apply these project-specific rules when reviewing changes in `Sources/` and `Tests/`.

## Hard blockers
- Any change that breaks target layering (Core targets importing GRDB/SQLite/CoreML/etc.).
- Unsafe concurrency (data races, non-Sendable escapes, missing actor isolation) given strict concurrency settings.
- Added/changed behavior without tests (unless PR explicitly states why and the change is doc-only).

## Strong preferences
- Prefer value types and small focused types.
- Avoid implicit global singletons.
- Keep routing logic deterministic and testable.

## Tests expected per area
- `Vec0` / routing changes: matrix tests + equivalence vs SQL baseline.
- Index changes: nearest-neighbor correctness + recall regression guard.
- Quantization changes: precision/recall bounds + round-trip properties.

- # Ultra-Strict Swift Merge-Gate Checklist

Below is a merge-gate checklist, not a style guide. In an ultra-strict review, any unchecked **Blocker** rejects the PR.

For the baseline, require **Swift 6 language mode** and **Complete strict concurrency checking** on every target.

---

## 1) Build, Toolchain, and Review Gates

### Blockers
- Builds cleanly in Debug and Release for every supported platform.
- Zero compiler warnings in CI.
- Swift 6 language mode is enabled everywhere that is under active development.
- Strict concurrency checking is **Complete** everywhere, including test targets.
- No `#if DEBUG` logic changes correctness, security, data flow, or isolation behavior.
- No suppressed warnings, compiler flags, or `@preconcurrency` shims without a written reason and removal plan.
- No API added to `public` or `open` without explicit review of stability, naming, docs, and tests.

### Majors
- Availability annotations are correct.
- Build settings are consistent across modules.
- Package/Xcode target boundaries match architecture boundaries.
- External dependencies are pinned and justified.

---

## 2) Concurrency and Isolation

`Sendable`, actor isolation, and structured concurrency are the default bar. Cancellation in Swift is cooperative, not magical, and every `await` inside actor-isolated code must be treated as a reentrancy boundary. Apple also provides `Mutex` as a synchronization primitive when actor isolation is not the right fit.

### Blockers
- No shared mutable state exists outside one of these protections:
  - actor isolation
  - `@MainActor`
  - `Mutex` / atomics / equivalent synchronization
- Every type crossing concurrency domains is actually safe to send.
- No `@unchecked Sendable` unless there is a written proof of invariants, ownership, and synchronization.
- No mutable global state.
- No singleton with unsynchronized mutable storage.
- No `Task.detached` unless ownership, lifetime, cancellation, and priority are explicitly correct.
- No `nonisolated` escape hatch that weakens safety without a real performance or interop reason.
- Actor-isolated methods do not assume state observed before `await` is still valid after `await`.
- No closure passed across domains captures non-`Sendable` mutable state.
- No continuation can be resumed more than once, or forgotten entirely.
- No blocking calls inside async contexts on executors that must stay responsive.
- Main-actor code is not used as a dumping ground for unrelated work.

### Majors
- Actor boundaries are explicit and make architectural sense.
- Long-running loops and expensive operations check cancellation.
- Child tasks in task groups do not leak references or mutate parent-owned state unsafely.
- Async APIs define ownership: who starts them, who cancels them, who awaits them.
- Priority is chosen intentionally, not left accidental.
- Actor hopping is minimized in hot paths.
- Bridging from callbacks, delegates, Combine, GCD, or Objective-C preserves isolation guarantees.

### Immediate Reject Patterns
- `DispatchQueue.main.async` used to silence actor-isolation problems instead of fixing ownership.
- `nonisolated(unsafe)` or `@unchecked Sendable` added just to make the compiler stop complaining.
- Background code reading or mutating view model state directly.
- “It seems to work” used as the concurrency proof.

---

## 3) SwiftUI and UI Correctness

SwiftUI expects UI work to stay aligned with main-actor behavior. Its `.task` modifier ties async work to the view lifetime and cancels when the view disappears or the task identity changes. Apple also recommends keeping time-sensitive UI updates synchronous and separating long-running async work from view logic.

### Blockers
- `body` is pure: no network, disk, crypto, database, analytics, logging side effects, or object construction with side effects.
- UI state mutations happen on the main actor.
- Views do not own business logic they should not own.
- View models / observable state are not recreated accidentally during render.
- No async work is started from rendering paths except through the intended lifecycle modifiers.
- No feedback loop from `onChange`, `onReceive`, bindings, or observation that can cause runaway updates.
- No hidden dependency on view redraw timing.

### Majors
- `.task(id:)` uses an identity that is intentional.
- Async work launched from views is cancellation-aware.
- Loading, optimistic updates, and error states are explicit.
- Animation-triggering state changes that must feel immediate happen synchronously before suspension points.
- Heavy work lives outside the view layer.
- Preview code does not rely on production services or global state.
- Navigation state is deterministic and testable.
- No large computed data transformations inside `body`.

### SwiftUI-Specific Red Flags
- `Task {}` sprinkled across button handlers and modifiers with no ownership model.
- Observable object created in `body`.
- Network requests initiated from computed properties.
- List rows doing image decoding, JSON parsing, or date formatting in render hot paths.

---

## 4) Memory, Ownership, and Lifetime

Swift uses ARC, closures can create reference cycles, and the language enforces memory-safety rules around conflicting access. That does not mean leaks, lifetime bugs, or ownership confusion disappear on their own.

### Blockers
- No retain cycles between owners, delegates, closures, tasks, timers, observers, or async streams.
- Capture lists are deliberate, not cargo cult.
- Lifetimes of timers, notifications, tasks, observation tokens, delegates, and subscriptions are explicit.
- No unbounded cache or in-memory accumulation without eviction.
- No use-after-cancel assumptions on tasks, streams, or callbacks.
- No force-unwrapped weak references.
- No `unowned` unless lifetime is mathematically guaranteed.

### Majors
- Large value copies are intentional.
- Reference semantics are used only when identity or shared mutable state is required.
- `deinit` is not carrying business-critical cleanup that may never run when expected.
- Temporary buffers, images, and decoded payloads are not retained longer than needed.
- Objective-C bridging hot paths are reviewed for autorelease pressure where relevant.
- Closure ownership is readable at the call site.

### Ownership Questions Every Review Should Ask
- Who owns this object?
- Who may mutate it?
- On which actor / thread / executor?
- When does it die?
- What cancels it?
- What happens if the owner disappears mid-flight?

---

## 5) Security, Privacy, and Secrets Handling

Keychain is the standard encrypted store for small sensitive data. Secure Enclave exists for stronger protection of private keys. ATS improves privacy and data integrity for network traffic. Privacy manifests are required for required-reason APIs used by apps and third-party SDKs.

### Blockers
- No secrets in source, test fixtures, screenshots, logs, crash reports, or `Info.plist`.
- Credentials, refresh tokens, and small secrets are stored in Keychain, not `UserDefaults`.
- Private keys use Secure Enclave where the threat model justifies it.
- ATS is not weakened globally.
- Any ATS exception is narrowly scoped, documented, and justified.
- Manual trust evaluation, custom pinning, or certificate overrides are security-reviewed and tested.
- No user-sensitive data is logged in plaintext.
- Privacy manifest is present and accurate for app and included SDKs where required.
- Entitlements are least-privilege only.
- Deep links, file URLs, universal links, pasteboard, and imported files are validated before use.
- No fingerprinting-like collection hidden behind analytics or diagnostics.

### Majors
- Sensitive values are redacted in logs and debug descriptions.
- Data collection is minimized.
- Retention and deletion rules are defined.
- Errors do not leak secrets or internal topology.
- Clipboard, screenshots, backups, and sharing flows are reviewed for sensitive data exposure.
- Auth flows defend against replay, stale session, and race conditions.

### Immediate Reject Patterns
- Token in `UserDefaults`.
- `NSAllowsArbitraryLoads = YES` without a very narrow reason.
- Trusting self-signed certs in production without device-managed roots or equivalent design.
- API keys shipped in the client as if they were secrets.

---

## 6) Networking, Persistence, and Data Boundaries

### Blockers
- External input is never force-unwrapped or force-decoded.
- Network and persistence boundaries validate input shape, size, and semantics.
- DTOs are separate from domain models where that separation matters.
- Partial failures, retries, and offline behavior are designed, not accidental.
- File system writes are atomic where corruption matters.
- Data races cannot occur between persistence and UI state propagation.

### Majors
- Timeouts, retry policy, and backoff are explicit.
- Idempotency is considered for retried operations.
- Migrations are versioned and tested.
- Dates, locales, and calendars are handled explicitly.
- `Codable` defaults are not silently masking server bugs.
- Error mapping produces actionable user and telemetry outcomes.

---

## 7) API Design and Architecture

Access control exists to hide implementation details and constrain surface area. In strict review, overexposed APIs are defects, not polish issues.

### Blockers
- Invalid states are unrepresentable where practical.
- Domain invariants are enforced at construction time.
- No primitive obsession for core business concepts.
- No convenience API that weakens safety relative to the core API.
- Public API names are stable, unambiguous, and follow one mental model.

### Majors
- Prefer value types unless identity is required.
- Protocols are small and behavior-oriented.
- Generic abstractions pay for themselves.
- No hidden global dependencies.
- Modules expose the minimum possible surface.
- Errors are typed where recovery matters.
- Dependencies point inward; UI does not leak into domain and infrastructure does not leak into view logic.

---

## 8) Performance and Responsiveness

### Blockers
- No blocking I/O, heavy parsing, crypto, or image work on the main actor.
- No accidental quadratic behavior in rendering, diffing, sorting, filtering, or reconciliation paths.
- No hot-path formatter creation, decoder creation, or repeated expensive allocations in tight loops.

### Majors
- Performance-critical code is measured, not guessed.
- Copy cost of large structs is understood.
- Async boundaries do not create executor thrash.
- Caches have eviction and bounded growth.
- Backpressure exists for streams and producer/consumer pipelines.
- Batching is used where latency and throughput justify it.

---

## 9) Error Handling and Resilience

### Blockers
- No `try!` or force unwrap in production paths unless a crash is the explicitly reviewed policy.
- No empty `catch`.
- No lossy fallback that silently corrupts business behavior.
- Cancellation is not reported as a generic failure.
- User-visible operations always reach a terminal state: success, cancellation, retryable failure, or hard failure.

### Majors
- Errors preserve diagnostic context without leaking secrets.
- Retryability is encoded or inferable.
- Domain errors are not raw transport errors.
- Recovery paths are tested.

---

## 10) Testing Requirements

### Blockers
- Every bug fix has a regression test.
- New concurrency code has tests for:
  - isolation
  - cancellation
  - reentrancy-sensitive behavior
  - ordering assumptions
  - timeout behavior
- Security-sensitive code has tests for malformed input, authorization failure, and secret leakage.
- SwiftUI stateful flows are covered either via view-model tests, reducer tests, or UI tests, depending on architecture.

### Majors
- Pure transformations use parameterized or property-based tests where useful.
- Performance-sensitive code has benchmarks.
- Persistence changes have migration tests.
- Network clients have contract tests or strong fixtures.
- Tests avoid time-based flakiness and hidden global state.

---

## 11) Interop and Legacy Boundaries

### Blockers
- Objective-C, C, delegates, callbacks, notifications, and Combine boundaries do not weaken Swift isolation guarantees.
- Imported legacy APIs are wrapped so unsafe threading assumptions do not leak through.
- FFI or pointer-based code documents ownership and lifetime precisely.

### Majors
- Legacy code is quarantined behind narrow adapters.
- Bridge layers translate errors, threading, and data ownership explicitly.
- Unsafe APIs are not exposed to broad call sites.

---

## 12) Documentation and Operational Readiness

### Blockers
- Non-obvious invariants are written down in code comments or docs.
- Every unsafe, unchecked, security exception, or concurrency escape hatch has a justification comment.
- Public APIs include usage constraints.
- Feature flags, migrations, and rollout constraints are documented.

### Majors
- Metrics, logs, and traces exist for critical paths.
- Crash-prone or security-sensitive modules have runbooks.
- Known technical debt is tracked with an owner and exit criteria.

---

## 13) Ultra-Strict Automatic Rejection List

Reject immediately if the PR does any of the following:

- Adds `@unchecked Sendable` with no proof.
- Adds `Task.detached` with no owner/cancellation model.
- Uses `DispatchQueue.main.async` to paper over actor isolation.
- Stores secrets outside Keychain when they should be protected.
- Weakens ATS broadly.
- Performs side effects from `SwiftUI.View.body`.
- Introduces force unwraps on external data.
- Introduces shared mutable global state.
- Hides failures with `try?`, empty `catch`, or “best effort” behavior in critical logic.
- Expands public API surface without tests and documentation.

---

## 14) Review Verdict Rubric

- **Reject:** any Blocker unchecked.
- **Fix before release:** Blockers clear, but Majors remain in security, concurrency, persistence, or UI correctness.
- **Accept:** no Blockers, Majors either resolved or explicitly ticketed with owner, scope, and deadline.

## 15) Swift Macros Code Expansion

- All swift macro code expansion must be built by swift ast syntax