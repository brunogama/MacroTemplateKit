# Changelog

All notable changes to MacroTemplateKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes

- `Renderer.render`, `StatementRenderer.render`, `DeclarationRenderer.render`,
  `renderStatements`, and the `rendered` convenience properties now `throw`.
  The parse gate was an `assert`, which is stripped from release builds --- the
  only configuration a macro plugin ships in --- so a malformed emit reached the
  compiler as a broken tree and was blamed on the user's macro. Call sites need
  `try`; `rendered` is now a throwing computed property. See
  `docs/adr/0001-parse-gate-throws.md`.
- `Template.binaryOperation` and the `operation` factory take an `Operator`
  instead of a `String`. String literals still work, so `operator: "+"` is
  unchanged; custom operators can now declare their precedence.
- `SetterSignature.parameterName` is now `String?` and defaults to `nil`,
  emitting the bare `set { ... }` form. Previously it was mandatory, so every
  generated setter carried an explicit `(newValue)`.
- Closure parameters with an explicit type now emit the colon: `{ (x: Int) in }`
  where the previous output was `{ (x Int) in }`. The old form parses --- Swift
  reads it as a parameter with two *names* rather than a typed one --- so it
  never failed the parse gate, and token-parity against the legacy renderer
  actively pinned it in place, since that renderer omitted the colon too.
  Deleting the legacy path is what allowed the fix. Any golden files or string
  comparisons covering typed closure parameters will need updating.

### Added

- `Template.cast(_:type:kind:)` for `as`, `as?`, and `as!`. Without it the kit
  could not express a forced cast at all.
- `Template.syntax(_:)` splices an existing `ExprSyntax` into a template,
  instead of routing its description through `.variable`.
- `Operator`, `Precedence`, and `Associativity` are public, so a macro emitting
  a custom operator can state how tightly it binds.
- `RenderError` carries the offending source and the parse diagnostics, and
  names MacroTemplateKit rather than the caller.
- `MatchPattern` and the `Statement.guardCase` / `Statement.ifCase` cases, for
  destructuring an enum case: `guard case let .success(value) = result else`.
  Previously this could only be written by handing raw source to
  `Template.variable`, which meant it was invisible to `map` and unchecked
  until the parse gate. `MatchPattern` covers enum cases, tuples, wildcards,
  bindings, and expression patterns, hoisting a single `let` in front of the
  whole pattern when any name is bound. Named `MatchPattern` because it covers
  only match position, not the binding patterns in a signature or a `let`. A
  bare `Pattern` also shadows out under `import XCTest`, though not under
  SwiftSyntax, which defines no such type.

  Typed patterns cost about 10% against the raw-string form on the `case-path`
  benchmark --- an indirect enum allocates a box and a subpattern array per
  case where an interpolated `String` allocated once. The benchmark uses the
  typed form and the published ratio moved accordingly, from 0.67x to 0.74x.
  `.variable` remains available where that 10% matters.

### Bug Fixes

- Nested operations are parenthesised by precedence. `.operation(.operation(a,
  "+", b), "*", c)` emitted `a + b * c` --- it parsed cleanly and passed token
  parity, so nothing caught it, and the generated code silently meant something
  other than what the template said.
- Reserved keywords used as identifiers are backtick-escaped, so a property
  named `default` or `class` generates code that compiles. Contextual keywords
  (`open`, `some`, `get`) and expression keywords (`self`, `super`, `nil`) are
  deliberately left bare.
- The leaf fast path no longer bypasses the parse gate. `.variable` is built
  structurally only when its contents are a plain identifier; anything else
  falls through to the parser, which validates it.
- `SourceEmitter` no longer renders closure bodies by calling back into the
  parse-backed renderer and re-serialising the result --- a round trip inside
  the emitter.

### Performance

- Rendering goes through a source-text emitter and one parse per fragment.
  Against a hand-written SwiftSyntax baseline that hoists its loop invariants,
  producing token-identical output, `min` over 3 runs at sizes 16/64/256:

  | workload | shape | ratio |
  |---|---|---|
  | case-path | `@CasePathable`-style property per case | 0.73--0.78x |
  | generate | accessor pairs over stored properties | 0.75--0.79x |
  | case-factory | static factories over enum cases | 1.00--1.06x (parity) |

  Depth decides: structural construction pays per node, the emitter appends text
  and parses once per declaration, so the deeper the generated declaration the
  further ahead the library gets. Previously the kit ran at 0.98--0.99x, so it
  cost nothing and bought nothing; it now ranges from parity on flat
  declarations to a comfortable win on deeply nested ones. Absolute figures are microseconds per expansion ---
  this is not a build-time story.

  Two earlier claims in this section were wrong and are withdrawn:

  - **`~0.55x retained memory` is removed.** It was measured with every rendered
    tree held alive at once. A plugin serialises each expansion and drops the
    tree, so peak memory is one expansion's worth however many expansions a
    build performs --- measured flat across a 2048x sweep. The ratio is real per
    live tree and is then multiplied by a count that is always 1.
    See `docs/adr/0003-memory-win-does-not-accumulate.md`.
  - **`0.59--0.64x` compared against a baseline that rebuilt expansion-invariant
    nodes inside its per-item loop.** Hoisting them alone makes that baseline up
    to 1.75x faster. The ratios above use the hoisted baseline.
    See `docs/adr/0004-baselines-must-hoist-invariants.md`.
  - **A third correction, made after those two.** `case-factory` was restated
    here as 0.94--0.96x, and is now 1.00--1.06x --- at parity, marginally
    slower. Nothing changed in the library. The earlier figure compared numbers
    collected in different benchmark sessions, and absolutes drift ~10% between
    sessions on this hardware for identical code. Every ratio published now
    comes from a single invocation. Sub-5% claims about this workload are not
    supportable in either direction.

  See also `docs/adr/0002-relax-render-engine-merge-gate.md`.

### Bug Fixes

- Address second round of PR #20 review feedback
- Address PR #20 review feedback
- Document single-binding limitation, add @available extraction tests

### Documentation

- Document Extractor API, wither methods, and extract-transform-render pipeline
- Update changelog [skip ci]
- Align review tests with macro template kit
- Add copilot code review instructions
- Update changelog [skip ci]
- Align review tests with macro template kit
- Bump version references to 0.0.6
- Update changelog [skip ci]
- Add docc tutorials for common workflows
- Refresh guides and examples for the new dx
- Update changelog [skip ci]
- Add copilot code review instructions
- Update changelog [skip ci]

### Features

- Raw attribute args, extension access level, strict concurrency
- Extract all variable bindings, add extractAll public API
- Add Extractor API, wither methods, and convenience combinators
- Add typed signatures and fluent templates

### Miscellaneous Tasks

- Regenerate llms.txt
- Simplify macos build matrix
- Fix danger validation
- Update pre-commit settings
- Pre-commits
- Regenerate LLMS.txt [skip ci]
- Update readme
- Code review

## [0.0.5] - 2026-03-07

### Documentation

- Document binary package usage

### Features

- Improve dx for default template usage

### Miscellaneous Tasks

- Regenerate LLMS.txt [skip ci]

## [0.0.4] - 2026-03-01

### Bug Fixes

- **core**: Break up template map nil-coalescing chain for release builds
- Replace swift package generate-documentation with xcodebuild docbuild in docs workflow

### Documentation

- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Sync README and DocC articles with latest API surface
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]

### Features

- **core**: Add tupleLiteral, subscriptCall, forInStatement, ifLetBinding, enumDecl, typeAlias + relax SwiftLint thresholds
- **packaging**: Add binary manifest for MacroTemplateKit

### Miscellaneous Tasks

- Make commit lint reject push and pr
- Update MacroTemplateKit version to 0.0.3
- Modify changelog workflow branch configuration

### Refactor

- **tests**: Remove redundant swiftlint:disable tags now covered by Tests/.swiftlint.yml

## [.0.0.3] - 2026-03-01

### Bug Fixes

- **quick-10**: Add trailing commas to InheritedTypeListSyntax elements
- Update Package@swift-6.0.swift swift-syntax range to 510..<700
- **lint**: Remove array_init rule and disable tags from tests
- **ci**: Use direct git-cliff installation instead of docker action
- **ci**: Use Xcode-bundled Swift instead of standalone toolchain

### Documentation

- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]
- Update changelog [skip ci]

### Features

- Add selfAccess, isFailable, isMutating, breakStatement
- **16-01**: Add new Template and Statement cases to MacroTemplateKit
- Add WhereRequirement support and fix rendering of commas and colons
- Add isStatic, accessLevel, effects, and genericCall

### Miscellaneous Tasks

- Reduce to swift-tools-version 5.10, swift-syntax 510..<700
- Update swift-syntax dependency to from 509.0.0
- Update swift-syntax dependency to 602.0.0
- Add conventional commit validation workflow
- Add strict PR validation with Danger
- Add automatic changelog generation on main branch merges

### Testing

- **16-01**: Add unit tests for all new Template and Statement cases

## [0.0.1] - 2026-02-15

### Features

- Initial release of MacroTemplateKit v0.0.1

[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/brunogama/MacroTemplateKit/compare/v.0.0.3...v0.0.4
[.0.0.3]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.1...v.0.0.3

