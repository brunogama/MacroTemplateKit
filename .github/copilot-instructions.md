# Copilot Instructions for MacroTemplateKit

## What this repository is

- `MacroTemplateKit` is a Swift Package Manager library for building Swift macro output with a typed AST instead of string interpolation.
- Main package manifest: `/home/runner/work/MacroTemplateKit/MacroTemplateKit/Package.swift`
- Primary source: `/home/runner/work/MacroTemplateKit/MacroTemplateKit/Sources/MacroTemplateKit`
- Tests: `/home/runner/work/MacroTemplateKit/MacroTemplateKit/Tests/MacroTemplateKitTests`
- Examples: `/home/runner/work/MacroTemplateKit/MacroTemplateKit/Examples`

Start by reading:

1. `/home/runner/work/MacroTemplateKit/MacroTemplateKit/README.md`
2. `/home/runner/work/MacroTemplateKit/MacroTemplateKit/CONTRIBUTING.md`
3. `/home/runner/work/MacroTemplateKit/MacroTemplateKit/LLMS.txt`

## Recommended workflow for coding agents

1. Inspect the relevant source and matching test file before editing.
2. Make the smallest possible change.
3. Run a targeted validation command as soon as possible.
4. Run the broader required checks before finishing.

For most code changes, validate with:

```bash
swift build -Xswiftc -warnings-as-errors
swift test --filter <RelevantTestSuite>
swift test --parallel
```

## Commands and tooling

- Build: `swift build -Xswiftc -warnings-as-errors`
- Test all: `swift test --parallel`
- Test one suite: `swift test --filter RendererTests`
- Local CI replica: `./scripts/ci-local.sh`
- Tool bootstrap: `./scripts/bootstrap.sh`

`./scripts/ci-local.sh` runs format, lint, build, and tests in the same order as CI.

## Errors encountered while onboarding this repo

- On a fresh environment, `./scripts/ci-local.sh` can fail immediately with:
  - `error: swift-format is not installed.`
  - Work-around: run `./scripts/bootstrap.sh` first to install `swift-format`, `swiftlint`, and `danger-swift`, or run `swift build` / `swift test` directly if you only need compile-and-test validation.
- A GitHub Actions run may appear as `action_required` before any jobs exist.
  - Work-around: inspect the workflow run status first. If there are zero jobs/logs, treat it as an approval or workflow-state issue rather than a code failure.

## Repository-specific coding guidance

- Follow the existing Swift style:
  - 2-space indentation
  - meaningful names
  - avoid force unwraps in production code
  - add `///` docs for public APIs
- Do not add `swiftlint:disable` / `swiftlint:enable` comments. PR validation explicitly rejects them.
- Keep renderer changes pure and exhaustive.
- Compiler warnings are treated as errors in CI.

When adding or changing AST surface area, check whether the same concept must be updated across:

- `Template.swift`
- `Statement.swift`
- `Declaration.swift`
- renderer files such as `Renderer.swift`, `DeclarationRenderer.swift`, and `StatementRenderer.swift`
- conformance/helpers such as `Template+Conformances.swift` and fluent factory extensions
- tests in `/home/runner/work/MacroTemplateKit/MacroTemplateKit/Tests/MacroTemplateKitTests`

## Testing expectations

- Existing tests are organized by behavior:
  - renderer coverage: `RendererTests.swift`, `DeclarationRendererTests.swift`, `StatementRendererTests.swift`
  - new rendering cases: `NewCasesRendererTests.swift`
  - examples/public API usage: `PublicExamplesTests.swift`
  - builder behavior: `TemplateBuilderTests.swift`
  - functor laws: `TemplateFunctorLawsTests.swift`
- If you change `map` behavior or payload propagation, run and update the functor-law tests.
- For documentation-only changes like this file, no code tests need to be added, but you should still verify the file content and keep changes isolated.

## CI expectations

Pull requests are gated by:

- formatting (`swift-format`)
- linting (`swiftlint --strict`)
- build with warnings as errors
- full test suite
- commitlint for Conventional Commits
- Danger

Use Conventional Commit style for commit messages because CI enforces it.

## Scope control

- Avoid unrelated refactors.
- Update `README.md` or `CHANGELOG.md` only when the user-facing change actually requires it.
- Prefer targeted tests first, then the full suite.
