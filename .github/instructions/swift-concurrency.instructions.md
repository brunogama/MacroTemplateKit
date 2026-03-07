---
applyTo:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
description: "Strict concurrency, isolation, and ownership review rules for Swift changes"
---

# Concurrency and lifetime review gates

- Shared mutable state must be protected by actor isolation, `@MainActor`, `Mutex`, atomics, or equivalent synchronization.
- Types that cross concurrency domains must truly be safe to send. Do not accept `@unchecked Sendable` without a written proof of invariants, ownership, and synchronization.
- Reject mutable globals, unsynchronized singleton storage, `Task.detached` without an explicit ownership and cancellation model, and `nonisolated` escape hatches added only to silence the compiler.
- Treat every `await` inside actor-isolated code as a reentrancy boundary. State observed before suspension must be revalidated after suspension.
- Reject closures that cross domains while capturing mutable non-`Sendable` state.
- Continuations must always be resumed exactly once.
- Do not block executors that must stay responsive, and do not use the main actor as a dumping ground for unrelated work.
- Long-running or expensive async work should check cancellation. Child tasks and task groups must not leak references or mutate parent-owned state unsafely.
- Async APIs must make ownership clear: who starts the work, who cancels it, and who awaits it.
- Bridging from callbacks, delegates, Combine, GCD, Objective-C, or C must preserve isolation guarantees.

## Immediate rejection patterns

- `DispatchQueue.main.async` used to paper over actor-isolation problems
- `nonisolated(unsafe)` or `@unchecked Sendable` added only to make warnings disappear
- background code reading or mutating view-model state directly
- concurrency reasoning justified with “it seems to work”

## Memory and ownership gates

- Reject retain cycles involving owners, delegates, closures, tasks, timers, observers, or async streams.
- Capture lists must be deliberate. Do not accept `unowned` unless lifetime is mathematically guaranteed.
- Lifetimes of tasks, subscriptions, timers, notifications, and observation tokens must be explicit.
- Avoid unbounded caches or in-memory accumulation without eviction.
