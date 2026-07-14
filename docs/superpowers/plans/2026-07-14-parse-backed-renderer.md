# Parse-Backed Renderer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace MacroTemplateKit's per-node structural rendering with a SourceEmitter + single-parse pipeline that is ≥25% faster at every benchmark size with token-identical output and no memory regression.

**Architecture:** A new internal `SourceEmitter` walks `Template`/`Statement`/`Declaration` values appending Swift source text to one `String` buffer; `Renderer`'s public entry points then parse that buffer once per fragment (the `ExprSyntax("\(raw:)")` mechanism). The existing structural construction is kept temporarily as an internal reference for token-parity tests, then deleted once parity and the benchmark gate are proven.

**Tech Stack:** Swift 5.10, swift-syntax 603.0.2 (pinned range `510.0.0..<700.0.0`), SwiftSyntaxBuilder string-interpolation initializers, XCTest, the `Benchmarks/` harness on branch `perf/render-engine`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-14-parse-backed-renderer-design.md` — read it before starting.
- Public API of `Renderer` must not change: `render(_: Template<A>) -> ExprSyntax`, `render(_: Statement<A>) -> CodeBlockItemSyntax`, `render(_: Declaration<A>) -> DeclSyntax` (plus `renderStatements`).
- Output bar is **token-identical** to the current renderer: same tokens, same order; trivia may differ. Never compare `description`; always compare token streams.
- Merge gate: `mtk` pipeline p50 improves ≥25% at sizes 4/16/64/256 on the generate workload, retained KB does not grow, equivalence gate passes.
- Root package builds with `-enable-experimental-feature StrictConcurrency`; new code must be warning-free under it (make `SourceEmitter` an caseless `enum` with static methods; no mutable statics).
- Run the library tests with `swift test` from the repo root. Run benchmarks with `swift build -c release --package-path Benchmarks` then `Benchmarks/.build/release/RenderEngineBench`.
- Commit after every task with a conventional-commits message (commitlint is configured); end commit bodies with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## File Structure

- Create: `Sources/MacroTemplateKit/SourceEmitter.swift` — expression (`Template`) emission + string-literal escaping (one responsibility: value → source text).
- Create: `Sources/MacroTemplateKit/SourceEmitter+Statements.swift` — `Statement` emission.
- Create: `Sources/MacroTemplateKit/SourceEmitter+Declarations.swift` — `Declaration` + signature + attribute emission.
- Modify: `Sources/MacroTemplateKit/Renderer.swift`, `DeclarationRenderer.swift`, `StatementRenderer.swift` — public entry points switch to emit+parse; structural internals renamed `legacyRender*` in-place, then deleted in Task 7.
- Create: `Tests/MacroTemplateKitTests/RendererParityTests.swift` — corpus + token-parity tests.
- Modify: `Benchmarks/README.md`, `CHANGELOG.md` — final numbers + behavior note.

---

### Task 1: Token-parity harness and corpus

**Files:**
- Create: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Consumes: existing `Renderer.render` (all three overloads).
- Produces: `func tokenStream(_ node: some SyntaxProtocol) -> String`; `enum ParityCorpus` with `static let templates: [Template<Void>]`, `static let statements: [Statement<Void>]`, `static let declarations: [Declaration<Void>]`; `func assertTokenParity(_ reference: some SyntaxProtocol, _ candidate: some SyntaxProtocol, file: StaticString, line: UInt)`.

- [ ] **Step 1: Write the harness and a self-parity test (this test must PASS immediately — it validates the harness, not the feature)**

```swift
import SwiftSyntax
import XCTest
@testable import MacroTemplateKit

func tokenStream(_ node: some SyntaxProtocol) -> String {
    node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

func assertTokenParity(
    _ reference: some SyntaxProtocol,
    _ candidate: some SyntaxProtocol,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(tokenStream(reference), tokenStream(candidate), file: file, line: line)
}

enum ParityCorpus {
    // Cover EVERY Template case. Extend these arrays until an exhaustive
    // switch over Template in SourceEmitter has a corpus entry per case —
    // start from the cases used in Examples/ and Tests/.
    static let templates: [Template<Void>] = [
        .literal(.integer(42)), .literal(.double(1.5)),
        .literal(.string("he said \"hi\"\nline2")), .literal(.boolean(true)), .literal(.nil),
        .variable("newValue"),
        .conditional(condition: .variable("flag"), then: .literal(.integer(1)), else: .literal(.integer(2))),
        // ... one entry per remaining case: loop, binaryOperation, functionCall,
        // methodCall, propertyAccess, selfAccess, subscriptAccess, arrayLiteral,
        // dictionaryLiteral, tupleLiteral, closure, assignment, awaitExpression,
        // tryExpression, forceUnwrap, stringInterpolation, genericCall, variableDeclaration
    ]
    static let statements: [Statement<Void>] = [
        .assignmentStatement(lhs: .variable("x"), rhs: .literal(.integer(1))),
        .returnStatement(.variable("x")),
        // ... one entry per remaining Statement case (14 total): breakStatement,
        // deferStatement, expression, forInStatement, guardLetBinding, guardStatement,
        // ifLetBinding, ifStatement, letBinding, switchStatement, throwStatement, varBinding
    ]
    static let declarations: [Declaration<Void>] = [
        .property(PropertySignature(name: "_storage", type: "[String: Any]", isLet: false,
                                    initializer: .dictionaryLiteral([]))),
        // ... one entry per remaining Declaration case (8 total): computedProperty,
        // enumDecl, extensionDecl, function, initDecl, structDecl, typeAlias
    ]
}

final class ParityHarnessTests: XCTestCase {
    func testHarnessDetectsEquality() {
        let node = Renderer.render(Template<Void>.variable("x"))
        assertTokenParity(node, node)
    }

    func testCorpusRendersWithoutErrors() {
        for template in ParityCorpus.templates {
            XCTAssertFalse(Renderer.render(template).hasError, "\(template)")
        }
        for statement in ParityCorpus.statements {
            XCTAssertFalse(Renderer.render(statement).hasError, "\(statement)")
        }
        for declaration in ParityCorpus.declarations {
            XCTAssertFalse(Renderer.render(declaration).hasError, "\(declaration)")
        }
    }
}
```

While filling in the corpus, use the real case signatures from `Template.swift`, `Statement.swift`, `Declaration.swift` (associated values differ per case — the compiler is the authority, not this plan).

- [ ] **Step 2: Run the tests — both must PASS**

Run: `swift test --filter ParityHarnessTests`
Expected: PASS. If `testCorpusRendersWithoutErrors` fails for a case, the corpus entry is malformed — fix the entry, not the renderer.

- [ ] **Step 3: Commit**

```bash
git add Tests/MacroTemplateKitTests/RendererParityTests.swift
git commit -m "test: add token-parity harness and renderer corpus"
```

---

### Task 2: SourceEmitter skeleton + literals/variables, parse-backed entry point

**Files:**
- Create: `Sources/MacroTemplateKit/SourceEmitter.swift`
- Modify: `Sources/MacroTemplateKit/Renderer.swift` (add internal entry point; do NOT touch public `render` yet)
- Test: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Produces: `enum SourceEmitter { static func emit<A: Sendable>(_ template: Template<A>, into buffer: inout String); static func escapeStringLiteral(_ raw: String) -> String }`; `extension Renderer { static func renderParsed<A: Sendable>(_ template: Template<A>) -> ExprSyntax }` (internal).
- Consumes: Task 1's `ParityCorpus.templates`, `assertTokenParity`.

- [ ] **Step 1: Write the failing parity test**

```swift
final class TemplateEmitterParityTests: XCTestCase {
    func testLiteralAndVariableParity() {
        let cases: [Template<Void>] = [
            .literal(.integer(42)), .literal(.double(1.5)),
            .literal(.string("he said \"hi\"\nline2")),
            .literal(.boolean(true)), .literal(.nil),
            .variable("newValue"),
        ]
        for template in cases {
            assertTokenParity(Renderer.render(template), Renderer.renderParsed(template))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter TemplateEmitterParityTests`
Expected: FAIL — `renderParsed` not defined.

- [ ] **Step 3: Implement the skeleton**

```swift
// SourceEmitter.swift
import SwiftSyntax
import SwiftSyntaxBuilder

/// Walks template values appending Swift source text to a single buffer.
/// Renderer parses the buffer once per fragment. Internal by design:
/// the emitter's output format is an implementation detail of Renderer.
enum SourceEmitter {
    static func emit<A: Sendable>(_ template: Template<A>, into buffer: inout String) {
        switch template {
        case .literal(let value):
            emit(value, into: &buffer)
        case .variable(let name, _):
            buffer.append(name)
        default:
            // Temporary during migration: Tasks 3 fills in every case and
            // deletes this default so the switch is compiler-exhaustive.
            fatalError("SourceEmitter: unhandled template case \(template)")
        }
    }

    static func emit(_ value: LiteralValue, into buffer: inout String) {
        switch value {
        case .integer(let int): buffer.append(String(int))
        case .double(let double): buffer.append(String(double))
        case .boolean(let bool): buffer.append(bool ? "true" : "false")
        case .nil: buffer.append("nil")
        case .string(let string):
            buffer.append("\"")
            buffer.append(escapeStringLiteral(string))
            buffer.append("\"")
        }
    }

    /// Escapes content for a double-quoted Swift string literal, matching the
    /// token text StringLiteralExprSyntax(content:) produces.
    static func escapeStringLiteral(_ raw: String) -> String {
        var out = ""
        out.reserveCapacity(raw.count)
        for scalar in raw.unicodeScalars {
            switch scalar {
            case "\\": out.append("\\\\")
            case "\"": out.append("\\\"")
            case "\n": out.append("\\n")
            case "\r": out.append("\\r")
            case "\t": out.append("\\t")
            case "\0": out.append("\\0")
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}

// Renderer.swift — add:
extension Renderer {
    static func renderParsed<A: Sendable>(_ template: Template<A>) -> ExprSyntax {
        var buffer = ""
        SourceEmitter.emit(template, into: &buffer)
        let expr: ExprSyntax = "\(raw: buffer)"
        assert(!expr.hasError, "SourceEmitter produced unparsable source: \(buffer)")
        return expr
    }
}
```

If `LiteralValue`'s cases differ from the above (check `LiteralValue.swift`), match the real enum; the parity test is the arbiter of escaping correctness.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter TemplateEmitterParityTests`
Expected: PASS. If the string-literal case fails, diff the two token streams in the failure message and adjust `escapeStringLiteral` until identical.

- [ ] **Step 5: Commit**

```bash
git add Sources/MacroTemplateKit/SourceEmitter.swift Sources/MacroTemplateKit/Renderer.swift Tests/MacroTemplateKitTests/RendererParityTests.swift
git commit -m "feat: add SourceEmitter skeleton with parse-backed render entry point"
```

---

### Task 3: Emit all remaining Template cases

**Files:**
- Modify: `Sources/MacroTemplateKit/SourceEmitter.swift`
- Test: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Consumes: `Renderer.renderParsed(_: Template<A>)`, `ParityCorpus.templates`.
- Produces: `SourceEmitter.emit(_: Template<A>, into:)` with a compiler-exhaustive switch (no `default`).

- [ ] **Step 1: Write the failing whole-corpus parity test**

```swift
final class TemplateCorpusParityTests: XCTestCase {
    func testAllTemplateCasesParity() {
        for template in ParityCorpus.templates {
            assertTokenParity(Renderer.render(template), Renderer.renderParsed(template))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter TemplateCorpusParityTests`
Expected: FAIL — hits the `fatalError` default for the first non-literal case.

- [ ] **Step 3: Implement every case, working from the legacy renderer**

Delete the `default:` clause. The compiler now lists every unhandled case.
For each, open the corresponding `render…` function in `Renderer.swift` and
transcribe the token sequence it builds as text emission. Two worked examples
of the pattern (repeat it for all cases):

```swift
case .conditional(let condition, let thenBranch, let elseBranch):
    // Legacy builds TernaryExprSyntax: cond ? then : else
    emit(condition, into: &buffer)
    buffer.append(" ? ")
    emit(thenBranch, into: &buffer)
    buffer.append(" : ")
    emit(elseBranch, into: &buffer)

case .loop(let variable, let collection, let body):
    // Legacy renders collection.forEach { variable in body }
    emit(collection, into: &buffer)
    buffer.append(".forEach { ")
    buffer.append(variable)
    buffer.append(" in ")
    emit(body, into: &buffer)
    buffer.append(" }")
```

Rules: parenthesize exactly where the legacy renderer inserts paren tokens (the parity test catches every divergence); grow `ParityCorpus.templates` until every case in the switch has at least one corpus entry (add nested combinations for precedence-sensitive cases like `binaryOperation` inside `conditional`).

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter TemplateCorpusParityTests`
Expected: PASS with zero `fatalError` paths and no `default:` in the switch.

- [ ] **Step 5: Commit**

```bash
git add Sources/MacroTemplateKit/SourceEmitter.swift Tests/MacroTemplateKitTests/RendererParityTests.swift
git commit -m "feat: emit all Template cases in SourceEmitter"
```

---

### Task 4: Statement emission

**Files:**
- Create: `Sources/MacroTemplateKit/SourceEmitter+Statements.swift`
- Modify: `Sources/MacroTemplateKit/StatementRenderer.swift` (add internal parsed entry)
- Test: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Produces: `SourceEmitter.emit<A: Sendable>(_ statement: Statement<A>, into: inout String)`; `extension Renderer { static func renderParsed<A: Sendable>(_ statement: Statement<A>) -> CodeBlockItemSyntax }` (internal).
- Consumes: `SourceEmitter.emit(_: Template<A>, into:)` for embedded expressions; `ParityCorpus.statements`.

- [ ] **Step 1: Write the failing test**

```swift
final class StatementCorpusParityTests: XCTestCase {
    func testAllStatementCasesParity() {
        for statement in ParityCorpus.statements {
            assertTokenParity(Renderer.render(statement), Renderer.renderParsed(statement))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter StatementCorpusParityTests`
Expected: FAIL — `renderParsed(_: Statement)` not defined.

- [ ] **Step 3: Implement**

```swift
// SourceEmitter+Statements.swift
import SwiftSyntax
import SwiftSyntaxBuilder

extension SourceEmitter {
    static func emit<A: Sendable>(_ statement: Statement<A>, into buffer: inout String) {
        switch statement {
        case .assignmentStatement(let lhs, let rhs):
            emit(lhs, into: &buffer)
            buffer.append(" = ")
            emit(rhs, into: &buffer)
        case .returnStatement(let value):
            buffer.append("return ")
            emit(value, into: &buffer)
        // ... every remaining Statement case, exhaustive switch, no default.
        // Transcribe each from StatementRenderer.swift exactly as in Task 3.
        }
    }
}

extension Renderer {
    static func renderParsed<A: Sendable>(_ statement: Statement<A>) -> CodeBlockItemSyntax {
        var buffer = ""
        SourceEmitter.emit(statement, into: &buffer)
        let item = CodeBlockItemSyntax("\(raw: buffer)")
        assert(!item.hasError, "SourceEmitter produced unparsable statement: \(buffer)")
        return item
    }
}
```

If `CodeBlockItemSyntax` has no string-interpolation initializer in 603.0.2,
parse via `CodeBlockItemListSyntax("\(raw: buffer)").first!` and note it in a
comment. Grow `ParityCorpus.statements` to cover all 14 cases.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter StatementCorpusParityTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MacroTemplateKit/SourceEmitter+Statements.swift Sources/MacroTemplateKit/StatementRenderer.swift Tests/MacroTemplateKitTests/RendererParityTests.swift
git commit -m "feat: emit all Statement cases in SourceEmitter"
```

---

### Task 5: Declaration, signature, and attribute emission

**Files:**
- Create: `Sources/MacroTemplateKit/SourceEmitter+Declarations.swift`
- Modify: `Sources/MacroTemplateKit/DeclarationRenderer.swift` (add internal parsed entry)
- Test: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Produces: `SourceEmitter.emit<A: Sendable>(_ declaration: Declaration<A>, into: inout String)`; `extension Renderer { static func renderParsed<A: Sendable>(_ declaration: Declaration<A>) -> DeclSyntax }` (internal).
- Consumes: Template/Statement emission; `ParityCorpus.declarations`.

- [ ] **Step 1: Write the failing test**

```swift
final class DeclarationCorpusParityTests: XCTestCase {
    func testAllDeclarationCasesParity() {
        for declaration in ParityCorpus.declarations {
            assertTokenParity(Renderer.render(declaration), Renderer.renderParsed(declaration))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter DeclarationCorpusParityTests`
Expected: FAIL — `renderParsed(_: Declaration)` not defined.

- [ ] **Step 3: Implement**

Exhaustive switch over all 8 `Declaration` cases (property, computedProperty,
function, initDecl, structDecl, enumDecl, extensionDecl, typeAlias), plus
emission helpers for the signature types (`PropertySignature`,
`FunctionSignature`, `EnumSignature`, `ExtensionSignature`,
`InitializerSignature`, `TypeAliasSignature`, `ComputedPropertySignature`,
`SetterSignature`) and attributes (`Renderer+AttributeRendering.swift` is the
reference). Worked example of the pattern:

```swift
case .property(let signature):
    // Legacy: [attributes] [modifiers] let|var name[: Type][ = initializer]
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.modifiers, into: &buffer)
    buffer.append(signature.isLet ? "let " : "var ")
    buffer.append(signature.name)
    if let type = signature.type {
        buffer.append(": ")
        buffer.append(type)
    }
    if let initializer = signature.initializer {
        buffer.append(" = ")
        emit(initializer, into: &buffer)
    }
```

Match the optionality and field names to the real `PropertySignature` — the
compiler and the parity test are the authorities. The parsed entry point:

```swift
extension Renderer {
    static func renderParsed<A: Sendable>(_ declaration: Declaration<A>) -> DeclSyntax {
        var buffer = ""
        SourceEmitter.emit(declaration, into: &buffer)
        let decl: DeclSyntax = "\(raw: buffer)"
        assert(!decl.hasError, "SourceEmitter produced unparsable declaration: \(buffer)")
        return decl
    }
}
```

Grow `ParityCorpus.declarations` to cover all 8 cases, including one entry
with attributes and one with generic constraints (`SignatureSupport.swift`
types) since those paths are easy to miss.

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter DeclarationCorpusParityTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/MacroTemplateKit/SourceEmitter+Declarations.swift Sources/MacroTemplateKit/DeclarationRenderer.swift Tests/MacroTemplateKitTests/RendererParityTests.swift
git commit -m "feat: emit all Declaration cases in SourceEmitter"
```

---

### Task 6: Switch the public API to the parsed path

**Files:**
- Modify: `Sources/MacroTemplateKit/Renderer.swift`, `StatementRenderer.swift`, `DeclarationRenderer.swift`
- Test: full suite

**Interfaces:**
- Consumes: the three `renderParsed` entry points.
- Produces: public `Renderer.render(_:)` overloads now delegate to the parsed path; structural implementations renamed `legacyRender(_:)` (internal) so parity tests still reference them.

- [ ] **Step 1: Rename and rewire**

In each renderer file: rename the current public `render` body to
`legacyRender` (internal, same signature), and make the public `render`
delegate:

```swift
public static func render<A: Sendable>(_ template: Template<A>) -> ExprSyntax {
    renderParsed(template)
}

static func legacyRender<A: Sendable>(_ template: Template<A>) -> ExprSyntax {
    // former public body, unchanged
}
```

Update the three parity test classes to compare `Renderer.legacyRender(...)`
vs `Renderer.render(...)` (reference first argument).

- [ ] **Step 2: Run the full suite**

Run: `swift test`
Expected: parity tests PASS. Any other failures must be inspected one by one:
a test asserting exact text (trivia) gets updated to the new output or
converted to a token-stream assertion; a test asserting token content that
now fails indicates an emitter bug — fix the emitter, not the test.

- [ ] **Step 3: Run SwiftLint (config exists at .swiftlint.yml)**

Run: `swiftlint lint --quiet Sources/MacroTemplateKit`
Expected: no new violations.

- [ ] **Step 4: Commit**

```bash
git add -A Sources/MacroTemplateKit Tests
git commit -m "feat!: switch Renderer to parse-backed rendering

Output is token-identical; trivia may differ from previous releases.
Degenerate input now yields parser recovery nodes instead of
structurally-assembled invalid trees."
```

---

### Task 7: Delete the legacy structural path

**Files:**
- Modify: `Sources/MacroTemplateKit/Renderer.swift`, `StatementRenderer.swift`, `DeclarationRenderer.swift`, `Renderer+AttributeRendering.swift`
- Test: `Tests/MacroTemplateKitTests/RendererParityTests.swift`

**Interfaces:**
- Produces: `legacyRender*` gone; parity tests become golden token-stream tests.

- [ ] **Step 1: Record golden token streams while legacy still exists**

Add (temporarily) and run a generator test that prints the corpus token
streams from `Renderer.render` (now the parsed path, already parity-proven):

```swift
func testGenerateGoldenStreams() {
    for (index, template) in ParityCorpus.templates.enumerated() {
        print("golden.templates[\(index)] = \"\(tokenStream(Renderer.render(template)))\"")
    }
    // repeat for statements and declarations
}
```

Paste the output into `ParityCorpus` as `static let goldenTemplateStreams: [String]`
(and statement/declaration equivalents), then delete the generator test.

- [ ] **Step 2: Convert parity tests to golden tests and delete legacy**

```swift
func testTemplateGoldenStreams() {
    for (template, golden) in zip(ParityCorpus.templates, ParityCorpus.goldenTemplateStreams) {
        XCTAssertEqual(tokenStream(Renderer.render(template)), golden, "\(template)")
    }
}
```

Delete every `legacyRender*` function and any private helpers only they used
(the compiler's unused-code errors after deletion are the checklist; also
delete now-unused `stringLiteral` mini-parse helpers).

- [ ] **Step 3: Run the full suite**

Run: `swift test`
Expected: PASS, and `grep -rn "legacyRender" Sources Tests` returns nothing.

- [ ] **Step 4: Commit**

```bash
git add -A Sources/MacroTemplateKit Tests
git commit -m "refactor: delete legacy structural rendering path"
```

---

### Task 8: Benchmark merge gate and documentation

**Files:**
- Modify: `Benchmarks/README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: the `Benchmarks/` harness; the `mtk` pipeline now exercises the new renderer through the unchanged `Renderer` API.

- [ ] **Step 1: Run the gate**

```bash
swift build -c release --package-path Benchmarks
Benchmarks/.build/release/RenderEngineBench --workloads generate \
  --pipelines structural,mtk,mtk-parse --iterations 500
```

Expected: equivalence gate ✅; `mtk` p50 within a few percent of `mtk-parse`
(0.58–0.61× vs structural) at every size; retained KB at or below `mtk-parse`'s
(~0.6× of structural). Gate: mtk p50 must be **≤0.75×** its pre-change values
(95.9 / 353.7 / 1387 / 5557 µs at 4/16/64/256 from the spike baseline run).
If any size misses, profile before proceeding — do not merge on a partial win.

- [ ] **Step 2: Update documentation**

- `Benchmarks/README.md`: add a post-implementation snapshot table (same
  format as existing ones) with the new `mtk` numbers and a line noting the
  spike pipelines `mtk-parse`/`mtk-micro`/`mtk-memo` are retained for
  regression comparison.
- `CHANGELOG.md`: entry under Unreleased — "Renderer is now parse-backed:
  ~40% faster and ~40% less memory per expansion; output is token-identical
  but whitespace/trivia may differ; invalid template input now surfaces as
  parser recovery nodes."

- [ ] **Step 3: Commit**

```bash
git add Benchmarks/README.md CHANGELOG.md
git commit -m "docs: record parse-backed renderer benchmark results"
```
