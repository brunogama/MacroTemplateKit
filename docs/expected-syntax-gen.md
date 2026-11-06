# ExpectedSyntaxGen

ExpectedSyntaxGen converts valid Swift source into a Swift factory function that
reconstructs the parsed tree with public SwiftSyntax initializers. Generated source
imports `SwiftSyntax` only. It does not parse source at runtime and does not depend on
MacroTemplateKit or ExpectedSyntaxGenCore.

---

## Command line usage

With no arguments, the command reads `expected-output.swift` and atomically writes
`expected-output-ast-syntax.swift` beside it:

```bash
swift run ExpectedSyntaxGen
```

An explicit input derives its output name from the input stem. For example,
`Other.swift` writes `Other-ast-syntax.swift` unless `--output` is supplied.

```bash
swift run ExpectedSyntaxGen Sources/Fixture.swift \
  --kind declaration \
  --name makeExpectedDeclaration \
  --output Tests/Generated/ExpectedDeclaration.swift
```

Use `-` for stdin or stdout:

```bash
swift run ExpectedSyntaxGen - --kind expression --output -
```

Input is decoded as strict UTF-8. Diagnostics go to stderr and failures return a
nonzero status. Generation and validation finish before an output file is replaced,
and the command refuses to use the input path as its output path.

---

## Root kinds

| `--kind` | Generated return type | Representation limits |
| --- | --- | --- |
| `file` | `SourceFileSyntax` | Preserves the complete file, including shebangs, semicolons, and EOF trivia. |
| `declaration` | `DeclSyntax` | Requires exactly one declaration. Rejects shebangs and semicolons owned by a code-block item. |
| `expression` | `ExprSyntax` | Requires exactly one expression. Rejects shebangs and semicolons owned by a code-block item. |
| `declarations` | `[DeclSyntax]` | Requires only top-level declarations. Empty input returns an empty array. Non-empty trivia-only input is rejected. |

Fragment modes move EOF-owned trivia to the final returned syntax value. They reject
source whose bytes cannot be represented by their declared return type instead of
silently discarding it.

---

## Programmatic API

```swift
import ExpectedSyntaxGenCore

let generated = try ExpectedSyntaxGenerator.generate(
  source: source,
  options: ExpectedSyntaxGenerationOptions(
    kind: .expression,
    factoryName: "makeExpectedExpression"
  )
)
```

`ExpectedSyntaxGenerationError` distinguishes invalid factory names, parser
diagnostics, root mismatches, unrepresentable fragments, and incompatible metadata.
The `SwiftSyntax` factory name is reserved because it shadows the module used by
constructor expressions.

---

## Compatibility and validation boundary

The package keeps its SwiftSyntax dependency range at `600.0.1..<700.0.0`.
Constructor types, labels, token cases, and child choices can change within that
range. Generate and consume a fixture with the same resolved SwiftSyntax version,
and regenerate fixtures after changing that version.

The generator follows public `SyntaxNodeStructure` key paths. One isolated adapter
uses SwiftSyntax's `RawSyntax` SPI only to resolve each key path's child name. Emitted
source contains no SPI, raw syntax, parser calls, source-text wrapper, or debugger
initializer. If metadata cannot be represented through public constructors,
generation fails rather than falling back to a lossy form.

Parsing establishes syntactic validity only. It does not type-check names, imports,
overloads, availability, or other semantic constraints in the input program.

Constructor output is intentionally verbose. Every layout slot, absent optional,
token kind, source presence, and trivia piece is explicit. Large inputs therefore
produce large Swift files, although typed postorder bindings keep individual
type-checking expressions small.

Compilation, executable round trips, and macro expansion tests passed with Swift
6.4.2 using SwiftSyntax 600.0.1, 603.0.2, and 604.0.0. The repository compatibility
matrix continues to cover 600.0.1 and 603.0.2.

---

## Generated macro fixture

The compiled example macro returns an expression from a generated constructor. From
the repository root, regenerate it with:

```bash
swift run ExpectedSyntaxGen \
  docs/fixtures/expected-answer-expression.swift \
  --kind expression \
  --name makeExpectedAnswerExpression \
  --output Examples/ExpectedSyntaxGenMacro/ExpectedAnswerExpression.generated.swift
```

Do not edit the generated file by hand. `GeneratedAnswerMacroTests` expands the
macro through `SwiftSyntaxMacrosTestSupport`. `CompiledRoundTripTests` separately
generates all four return types, compiles them in one temporary Swift package against
the already-resolved local SwiftSyntax checkout, executes them, and compares exact
UTF-8 plus structural, token, and trivia-inclusive debug-tree fingerprints.

---

## Distribution

`ExpectedSyntaxGenCore` and the `ExpectedSyntaxGen` executable are source-package
products. `Package.binary.swift` continues to distribute only the prebuilt
MacroTemplateKit library.
