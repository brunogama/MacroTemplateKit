# Expression Macro Examples

Each file in this directory re-implements one of the expression macros from the
[swift-syntax MacroExamples](https://github.com/swiftlang/swift-syntax/tree/main/Examples/Sources/MacroExamples)
using MacroTemplateKit's template algebra instead of raw string interpolation.
The "BEFORE" approach (commented out) is shown alongside the "AFTER" approach
so the migration is immediately visible.

---

## StringifyMacro+MacroTemplateKit.swift

Implements `#stringify(expr)` → `(expr, "expr")`.

The result tuple is modelled as a two-argument `.functionCall` with an empty
function name, which SwiftSyntax renders as the parenthesised pair `(value, "source")`.
Eliminates the `fatalError` in the original by throwing a typed `ExpansionError.missingArgument`.

---

## URLMacro+MacroTemplateKit.swift

Implements `#URL("https://example.com")` → `URL(string: "https://example.com")!`.

Validates the literal at compile time using `Foundation.URL`; on failure throws a typed
`URLMacroExpansionError` with a `CustomStringConvertible` description. The force-unwrap
is represented via `Template.forceUnwrap` instead of a raw `"!"` suffix in a string.

---

## WarningMacro+MacroTemplateKit.swift

Implements `#myWarning("msg")` → emits a compiler warning and expands to `()`.

The Void result is modelled as a zero-argument `.functionCall` with an empty name.
Diagnostic emission is encapsulated in a private `WarningDiagnosticMessage` conforming
to `DiagnosticMessage & Sendable`, replacing the ad-hoc `SimpleDiagnosticMessage` struct.

---

## FontLiteralMacro+MacroTemplateKit.swift

Implements `#fontLiteral(name:size:weight:)` → `.init(fontLiteralName:size:weight:)`.

Renames the first argument label from `"name"` to `"fontLiteralName"` using a private
`resolvedLabel(for:at:)` helper and models the call as `.methodCall(base: .literal(.nil), ...)`,
which renders the dot-prefixed `.init(...)` form expected by `ExpressibleByFontLiteral`.

---

## AddBlockerMacro+MacroTemplateKit.swift

Implements `#addBlocker(expr)` — warns on `+` operators and rewrites them to `-`.

AST traversal and Fix-It emission remain in a `SyntaxRewriter` subclass (`AddVisitor`)
because structural rewriting is outside the scope of the template algebra. MacroTemplateKit
is used only for the output path: the rewritten expression text is forwarded through
`.variable(description, payload: ())` and rendered via `Renderer.render(_:)`, keeping
the output pipeline consistent and avoiding force casts/unwraps in the public API.

---

## SourceLocationMacro+MacroTemplateKit.swift

Implements four source-location macros: `#nativeFileID`, `#nativeFilePath`,
`#nativeLine`, and `#nativeColumn`.

Each queries `MacroExpansionContext.location` and routes the result through a
`Template<Void>` (`.literal(.string(...))` for string values, `.variable(...)`
for integer values) so that all four macros share the same `Renderer.render(_:)` output
path. Throws a typed `ExpansionError.locationUnavailable` instead of force-unwrapping
the optional location result.
