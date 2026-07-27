# Changelog

All notable changes to MacroTemplateKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Bug Fixes

- Publish changelog updates through pull requests
- Address pr review feedback
- Align pr gates after main merge

### Miscellaneous Tasks

- Merge origin/main into perf/render-engine

## [0.0.7] - 2026-07-14

### Bug Fixes

- **declarations**: Preserve parameter type ordering
- **ci**: Scope lint policy to enforced sources
- **ci**: Enforce hosted validation failures
- **declarations**: Normalize invalid inout defaults

### Documentation

- **changelog**: Record signature preservation
- **changelog**: Record inout normalization
- Prepare release 0.0.7

### Features

- Add structured expression primitives [skip changelog]
- **declarations**: Preserve function throwing effects
- **declarations**: Structure parameter default expressions
- **template**: Model contextual and inout expressions

### Miscellaneous Tasks

- **release**: Publish with github cli
- Keep commit lint installs ephemeral
- **security**: Constrain workflow token permissions
- Scope changelog skip directive
- Run danger on supported node
- Run commit lint on supported node
- Run danger js under node 20
- Trust danger homebrew formulas
- Scope standalone lint to first-parent commits
- Lint pull request first-parent commits

## [0.0.6] - 2026-03-07

### Bug Fixes

- **compatibility**: Support syntax versions 600 through 603
- Make CI pass — bash 3.2 array expansion, and 33 lint violations

### Documentation

- Update changelog [skip ci]
- Fix author name in readme
- Add docc tutorials for common workflows
- Refresh guides and examples for the new dx
- Record that CI was disabled at the repository level

### Features

- Add typed signatures and fluent templates

### Miscellaneous Tasks

- Fix danger validation
- Update pre-commit settings
- Pre-commits
- Regenerate LLMS.txt [skip ci]
- Trigger first run after re-enabling GitHub Actions
- Compile everything, on every branch

### Refactor

- Restore render engine lint compliance

### Styling

- Normalize enforced swift formatting

### Bench

- Make the equivalence check fail the process

### Build

- Normalize Scripts/ directory casing
- Fix warnings-as-errors under the swiftbuild build system
- Make the two package manifests one source of truth

## [0.1.0] - 2026-07-25

### Bug Fixes

- Make Examples a build target — none of them compiled
- Stop the leaf fast path from bypassing the parse gate
- Parenthesize nested expressions by precedence
- Address Task 2 review findings in SourceEmitter/Renderer
- Address second round of PR #20 review feedback
- Address PR #20 review feedback
- Document single-binding limitation, add @available extraction tests

### Documentation

- Narrow the MatchPattern naming rationale to what was verified
- Restate the merge gate (ADR 0005) and close Task 8
- Withdraw two CHANGELOG claims the benchmarks disproved
- Update README and CHANGELOG for the render-engine work
- Add parse-backed renderer implementation plan
- Sharpen glossary after benchmark work
- Add parse-backed renderer design spec with approach spike
- Record CAS-eval matrix results (#23)
- Add toolchain-cache-eval implementation plan; align spec cold-cell definition
- Add toolchain compilation-cache evaluation design spec
- Update changelog [skip ci]
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

- Typed match patterns — MatchPattern, guardCase, ifCase
- Model infix operators as a type so custom precedence can be declared
- Throw RenderError instead of asserting on unparsable output
- Add Template.syntax for SwiftSyntax interop
- Close renderer expressiveness gaps blocking idiomatic usage
- Cut Renderer's public API over to the parse-backed pipeline
- Emit all Declaration cases in SourceEmitter
- Emit all Statement cases in SourceEmitter
- Emit all Template cases in SourceEmitter
- Add SourceEmitter skeleton with parse-backed render entry point
- Raw attribute args, extension access level, strict concurrency
- Extract all variable bindings, add extractAll public API
- Add Extractor API, wither methods, and convenience combinators
- Add typed signatures and fluent templates

### Miscellaneous Tasks

- Untrack docs/agents
- Untrack docs/agents
- Regenerate llms.txt
- Simplify macos build matrix
- Fix danger validation
- Update pre-commit settings
- Pre-commits
- Regenerate LLMS.txt [skip ci]
- Update readme
- Code review

### Performance

- Drop `indirect` from MatchPattern, and withdraw the 10% claim
- Measure idiomatic MTK usage and revise the merge gate
- Add switchable-pipeline render-engine benchmark harness

### Refactor

- Delete the legacy structural renderer (Task 7)

### Testing

- Add case-factory workload on an enum fixture
- Add mtk-leaf pipeline as a granularity regression guard
- Add token-parity harness and renderer corpus

### Bench

- Match trivia on every baseline — the correction favours us, by 1-8%
- Close the trivia bias — and find a worse problem behind it
- Add case-path — the @CasePathable shape TCA actually pays for
- Attack the structural baseline — it was beatable, and the ratios move
- Measure whether the memory win accumulates — it does not

### Release

- 0.1.0

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

[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.7...HEAD
[0.0.7]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/brunogama/MacroTemplateKit/compare/v0.1.0...v0.0.6
[0.1.0]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.5...v0.1.0
[0.0.5]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/brunogama/MacroTemplateKit/compare/v.0.0.3...v0.0.4
[.0.0.3]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.1...v.0.0.3

