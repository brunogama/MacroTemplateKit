---
applyTo:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
description: "Correctness, security, persistence, performance, and macro review guidance for Swift changes"
---

# Correctness and security review gates

- `SwiftUI.View.body` must stay pure. No networking, disk I/O, crypto, logging side effects, analytics, or side-effectful object construction from render paths.
- UI state mutations belong on the main actor. Async work started from views must have intentional lifecycle ownership and cancellation behavior.
- Do not allow secrets in source, fixtures, screenshots, logs, crash reports, or plist files. Secrets belong in Keychain, and ATS must not be weakened broadly.
- Sensitive values must be redacted from logs. Validate deep links, file URLs, imported files, and pasteboard input before use.
- External input must never be force-unwrapped or force-decoded. Validate shape, size, and semantics at networking and persistence boundaries.
- Partial failures, retries, offline behavior, and atomic writes should be designed intentionally where those boundaries exist.
- Reject blocking I/O, heavy parsing, crypto, or image work on the main actor, plus accidental quadratic hot paths or repeated expensive allocation in tight loops.
- Reject production `try!`, force unwraps on external data, empty `catch`, or lossy fallbacks that silently corrupt behavior.
- Cancellation must not be reported as a generic failure, and user-visible work must reach a terminal success, cancellation, retryable failure, or hard failure state.
- Non-obvious invariants, unsafe operations, unchecked concurrency or security escape hatches, feature flags, and rollout constraints must be documented.
- Preserve least-privilege entitlements and data-minimization expectations.

## Swift macros

- All Swift macro code expansion must be built with the Swift AST and SwiftSyntax abstractions, never by interpolating raw source strings.
