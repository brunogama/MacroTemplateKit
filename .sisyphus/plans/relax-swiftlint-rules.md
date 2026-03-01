# Relax SwiftLint Rules + Fix Trivial Violations

## TL;DR

> **Quick Summary**: Raise SwiftLint thresholds for cyclomatic_complexity and file_length to accommodate macro code's inherent complexity, add common short identifiers to exclusions, and fix the remaining trivial violations (unneeded parentheses, redundant type annotation).
>
> **Deliverables**:
> - Updated `.swiftlint.yml` with relaxed thresholds
> - Fixed trivial SwiftLint violations in `DeclarationRenderer.swift` and `NewCasesRendererTests.swift`
> - Zero `swiftlint lint --strict Sources Tests` violations
> - `swift-format lint --strict --recursive Sources Tests` still passes
> - `swift build -Xswiftc -warnings-as-errors` still passes
> - `swift test --parallel` still passes
>
> **Estimated Effort**: Quick
> **Parallel Execution**: NO - sequential (config first, then fixes, then verify)
> **Critical Path**: Task 1 -> Task 2 -> Task 3 -> Task 4

---

## Context

### Original Request
User asked to relax SwiftLint rules instead of refactoring macro source code. Macros inherently have high cyclomatic complexity and large files. The current thresholds (cyclomatic_complexity warning:10, file_length warning:500) are too strict for this domain.

### Current Violations (30 total, all `--strict` errors)

**By rule**:
- `identifier_name` (24): Short vars `s`, `l`, `r` in `Template+Conformances.swift`, `Statement.swift`, `StatementRenderer.swift`, `Renderer.swift`, `Template.swift`
- `cyclomatic_complexity` (2): `Statement.map` (14), `StatementRenderer.render` (14), `Template.mapExtensions` (11)
- `unneeded_parentheses_in_closure_argument` (2): `DeclarationRenderer.swift` lines 193, 240, 302, 349
- `file_length` (1): `Declaration.swift` (552 > 500)
- `redundant_type_annotation` (1): `NewCasesRendererTests.swift` line 100
- `enum_case_associated_values_count` (1): `Statement.ifLetBinding` has 5 values

### Decision
- **Relax**: cyclomatic_complexity, file_length, identifier_name exclusions, enum_case_associated_values_count
- **Fix**: unneeded_parentheses_in_closure_argument (trivial), redundant_type_annotation (trivial)

---

## Work Objectives

### Core Objective
Make `swiftlint lint --strict Sources Tests` pass with zero violations by relaxing thresholds for macro-appropriate limits and fixing only trivial code issues.

### Concrete Deliverables
- `.swiftlint.yml` with updated thresholds
- `DeclarationRenderer.swift` with parentheses removed from closure arguments
- `NewCasesRendererTests.swift` with redundant type annotation removed

### Definition of Done
- [ ] `swiftlint lint --strict Sources Tests` exits 0
- [ ] `swift-format lint --strict --recursive Sources Tests` exits 0
- [ ] `swift build -Xswiftc -warnings-as-errors` exits 0
- [ ] `swift test --parallel` exits 0

### Must NOT Have
- No `swiftlint:disable` or `swiftlint:enable` tags anywhere in Sources/ or Tests/
- No refactoring of Statement.map, StatementRenderer.render, or Template.mapExtensions
- No splitting of Declaration.swift
- No changes to public API or behavior

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** -- ALL verification is agent-executed.

### Test Decision
- **Infrastructure exists**: YES
- **Automated tests**: YES (tests-after -- run existing suite to confirm no regressions)
- **Framework**: swift test

### QA Policy
Run the full CI-equivalent pipeline after all changes.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Sequential -- config then fixes):
├── Task 1: Update .swiftlint.yml thresholds [quick]
├── Task 2: Fix unneeded_parentheses_in_closure_argument in DeclarationRenderer.swift [quick]
├── Task 3: Fix redundant_type_annotation in NewCasesRendererTests.swift [quick]
└── Task 4: Run swift-format + full CI verification [quick]

Critical Path: Task 1 -> Task 2 -> Task 3 -> Task 4
```

### Agent Dispatch Summary

- **Wave 1**: **4** -- All tasks `quick`

---

## TODOs

- [x] 1. Update .swiftlint.yml thresholds

  **What to do**:
  - Change `cyclomatic_complexity` from `warning: 10 / error: 15` to `warning: 15 / error: 25`
  - Change `file_length` from `warning: 500 / error: 1000` to `warning: 800 / error: 1500`
  - Add `s`, `l`, `r` to `identifier_name.excluded` list (these are standard short names in pattern matching for lhs/rhs/string in Equatable/Hashable conformances)
  - Change `enum_case_associated_values_count` threshold: add configuration `enum_case_associated_values_count: warning: 6 / error: 8` (currently defaults to 5)
  - Do NOT add any `swiftlint:disable` tags

  **Must NOT do**:
  - Do not disable any rules entirely
  - Do not change the `opt_in_rules` list
  - Do not remove `unneeded_parentheses_in_closure_argument` from opt_in (we will fix the code instead)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1, Sequential
  - **Blocks**: Tasks 2, 3, 4
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `.swiftlint.yml` (root) -- The file to edit. Current thresholds at lines 62-76 (file_length, function_body_length, type_body_length, cyclomatic_complexity) and lines 78-96 (identifier_name with excluded list)

  **External References**:
  - SwiftLint rule docs: https://realm.github.io/SwiftLint/ (cyclomatic_complexity, file_length, identifier_name, enum_case_associated_values_count)

  **Acceptance Criteria**:

  **QA Scenarios**:

  ```
  Scenario: Config changes are valid YAML and SwiftLint accepts them
    Tool: Bash
    Steps:
      1. Run: swiftlint lint --strict Sources Tests 2>&1 | grep -c "error:"
      2. Verify identifier_name violations for s/l/r are gone
      3. Verify cyclomatic_complexity violations are gone
      4. Verify file_length violation is gone
      5. Verify enum_case_associated_values_count violation is gone
    Expected Result: Only unneeded_parentheses_in_closure_argument and redundant_type_annotation remain (will be fixed in Tasks 2-3)
    Evidence: .sisyphus/evidence/task-1-swiftlint-after-config.txt
  ```

  **Commit**: YES (groups with Tasks 2, 3)
  - Message: `chore(lint): relax SwiftLint thresholds for macro domain complexity`
  - Files: `.swiftlint.yml`

---

- [x] 2. Fix unneeded_parentheses_in_closure_argument in DeclarationRenderer.swift

  **What to do**:
  - Remove unnecessary parentheses around closure arguments at the following locations:
    - Line 193: `{ (index, conformance) in` -> `{ index, conformance in`
    - Line 240: `{ (index, conformance) in` -> `{ index, conformance in`
    - Line 302: `{ (index, conformance) in` -> `{ index, conformance in`
    - Line 349: `{ (index, typeName) in` -> `{ index, typeName in`
  - These are all `.enumerated().map { ... }` closures where the parentheses around the tuple destructuring are unnecessary

  **Must NOT do**:
  - Do not change any other code in DeclarationRenderer.swift
  - Do not change logic, only remove parentheses

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1, after Task 1
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `Sources/MacroTemplateKit/DeclarationRenderer.swift:193` -- First occurrence: `.enumerated().map { (index, conformance) in`
  - `Sources/MacroTemplateKit/DeclarationRenderer.swift:240` -- Second occurrence (renderStruct)
  - `Sources/MacroTemplateKit/DeclarationRenderer.swift:302` -- Third occurrence (renderEnum)
  - `Sources/MacroTemplateKit/DeclarationRenderer.swift:349` -- Fourth occurrence: `.enumerated().map { (index, typeName) in`

  **Acceptance Criteria**:

  **QA Scenarios**:

  ```
  Scenario: Parentheses removed and file compiles
    Tool: Bash
    Steps:
      1. Run: swift build -Xswiftc -warnings-as-errors
      2. Run: swiftlint lint --strict Sources/MacroTemplateKit/DeclarationRenderer.swift
      3. Verify zero violations in DeclarationRenderer.swift
    Expected Result: Build succeeds, zero SwiftLint violations in file
    Evidence: .sisyphus/evidence/task-2-decl-renderer-lint.txt
  ```

  **Commit**: YES (groups with Tasks 1, 3)
  - Message: `chore(lint): relax SwiftLint thresholds for macro domain complexity`
  - Files: `Sources/MacroTemplateKit/DeclarationRenderer.swift`

---

- [x] 3. Fix redundant_type_annotation in NewCasesRendererTests.swift

  **What to do**:
  - Line 100: Remove the redundant type annotation. The violation is at:
    ```swift
    let template: Template<Void> = Template<Void>.subscript(
    ```
    Change to:
    ```swift
    let template = Template<Void>.subscript(
    ```

  **Must NOT do**:
  - Do not change any other test code
  - Do not change test logic or assertions

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1, after Task 2
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:

  **Pattern References**:
  - `Tests/MacroTemplateKitTests/NewCasesRendererTests.swift:100` -- The redundant type annotation line

  **Acceptance Criteria**:

  **QA Scenarios**:

  ```
  Scenario: Type annotation removed and tests still compile
    Tool: Bash
    Steps:
      1. Run: swift build -Xswiftc -warnings-as-errors
      2. Run: swiftlint lint --strict Tests/MacroTemplateKitTests/NewCasesRendererTests.swift
      3. Verify zero violations
    Expected Result: Build succeeds, zero SwiftLint violations in file
    Evidence: .sisyphus/evidence/task-3-test-lint.txt
  ```

  **Commit**: YES (groups with Tasks 1, 2)
  - Message: `chore(lint): relax SwiftLint thresholds for macro domain complexity`
  - Files: `Tests/MacroTemplateKitTests/NewCasesRendererTests.swift`

---

- [ ] 4. Run swift-format and full CI verification

  **What to do**:
  - Run `swift-format format --in-place --recursive Sources Tests` to ensure formatting is clean
  - Run the full CI-equivalent pipeline:
    1. `swift-format lint --strict --recursive Sources Tests`
    2. `swiftlint lint --strict Sources Tests`
    3. `swift build -Xswiftc -warnings-as-errors`
    4. `swift test --parallel`
  - All four commands must exit 0
  - Verify no `swiftlint:disable` or `swiftlint:enable` tags exist: `grep -rn "swiftlint:disable\|swiftlint:enable" Sources/ Tests/ --include="*.swift"`

  **Must NOT do**:
  - Do not make any additional code changes
  - If any check fails, report the failure -- do not try to fix it

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1, final
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2, 3

  **References**:

  **Pattern References**:
  - `.github/workflows/pr-validation.yml` -- The CI pipeline these commands mirror

  **Acceptance Criteria**:

  **QA Scenarios**:

  ```
  Scenario: Full CI-equivalent pipeline passes
    Tool: Bash
    Steps:
      1. Run: swift-format format --in-place --recursive Sources Tests
      2. Run: swift-format lint --strict --recursive Sources Tests
      3. Run: swiftlint lint --strict Sources Tests
      4. Run: swift build -Xswiftc -warnings-as-errors
      5. Run: swift test --parallel
      6. Run: grep -rn "swiftlint:disable\|swiftlint:enable" Sources/ Tests/ --include="*.swift" (must find nothing)
    Expected Result: All commands exit 0, no forbidden disable tags
    Evidence: .sisyphus/evidence/task-4-full-ci-pass.txt

  Scenario: No forbidden swiftlint:disable tags
    Tool: Bash
    Steps:
      1. Run: grep -rn "swiftlint:disable\|swiftlint:enable" Sources/ Tests/ --include="*.swift"
    Expected Result: No output (exit code 1 = no matches found)
    Evidence: .sisyphus/evidence/task-4-no-disable-tags.txt
  ```

  **Commit**: NO (already committed in Task 1-3 group)

---

## Commit Strategy

- **Single commit** grouping Tasks 1, 2, 3: `chore(lint): relax SwiftLint thresholds for macro domain complexity`
  - Files: `.swiftlint.yml`, `Sources/MacroTemplateKit/DeclarationRenderer.swift`, `Tests/MacroTemplateKitTests/NewCasesRendererTests.swift`
  - Pre-commit: `swift-format lint --strict --recursive Sources Tests && swiftlint lint --strict Sources Tests && swift build -Xswiftc -warnings-as-errors && swift test --parallel`

---

## Success Criteria

### Verification Commands
```bash
swift-format lint --strict --recursive Sources Tests  # Expected: exit 0, no output
swiftlint lint --strict Sources Tests                  # Expected: exit 0, "Done linting! Found 0 violations"
swift build -Xswiftc -warnings-as-errors               # Expected: "Build complete!"
swift test --parallel                                   # Expected: all tests pass
grep -rn "swiftlint:disable\|swiftlint:enable" Sources/ Tests/ --include="*.swift"  # Expected: no matches
```

### Final Checklist
- [ ] All "Must Have" present (relaxed thresholds, trivial fixes)
- [ ] All "Must NOT Have" absent (no disable tags, no refactoring, no API changes)
- [ ] All tests pass
- [ ] Zero SwiftLint strict violations
- [ ] Zero swift-format strict violations
