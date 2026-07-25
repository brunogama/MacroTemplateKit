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
            buffer.append(escapeIdentifier(name))

        case .conditional(let condition, let thenBranch, let elseBranch):
            // Legacy builds TernaryExprSyntax: condition ? thenBranch : elseBranch.
            // Only the condition can need parentheses — the branches are
            // delimited by `?` and `:`, and `?:` is right-associative so a
            // nested ternary in the else branch reads correctly bare.
            emit(condition, parenthesizedInside: .ternary, on: .left, into: &buffer)
            buffer.append(" ? ")
            emit(thenBranch, into: &buffer)
            buffer.append(" : ")
            emit(elseBranch, into: &buffer)

        case .loop(let variable, let collection, let body):
            // Legacy builds FunctionCallExprSyntax(calledExpression: ...forEach,
            // leftParen/rightParen: ...) with the closure as a parenthesized
            // *call argument*, not Swift's sugared trailing-closure syntax —
            // so the parens around the closure are real tokens here.
            emit(collection, into: &buffer)
            buffer.append(".forEach({ ")
            buffer.append(variable)
            buffer.append(" in ")
            emit(body, into: &buffer)
            buffer.append(" })")

        case .functionCall(let function, let arguments):
            buffer.append(function)
            buffer.append("(")
            emitArguments(arguments, into: &buffer)
            buffer.append(")")

        case .methodCall(let base, let method, let arguments):
            emit(base, into: &buffer)
            buffer.append(".")
            buffer.append(method)
            buffer.append("(")
            emitArguments(arguments, into: &buffer)
            buffer.append(")")

        case .binaryOperation(let left, let op, let right):
            let parent = precedenceGroup(forOperator: op) ?? .assignment
            emit(left, parenthesizedInside: parent, on: .left, into: &buffer)
            buffer.append(" ")
            buffer.append(op)
            buffer.append(" ")
            emit(right, parenthesizedInside: parent, on: .right, into: &buffer)

        case .propertyAccess(let base, let property):
            emit(base, into: &buffer)
            buffer.append(".")
            buffer.append(property)

        case .variableDeclaration(_, _, let initializer):
            // Legacy limitation (Renderer.renderDeclarations): only the
            // initializer expression is rendered; name/type produce no
            // tokens because full declarations require statement context.
            // Replicated verbatim for parity, not "fixed".
            emit(initializer, into: &buffer)

        case .tryExpression(let inner):
            buffer.append("try ")
            emit(inner, into: &buffer)

        case .awaitExpression(let inner):
            buffer.append("await ")
            emit(inner, into: &buffer)

        case .genericCall(let function, let typeArguments, let arguments):
            buffer.append(function)
            buffer.append("<")
            buffer.append(typeArguments.joined(separator: ", "))
            buffer.append(">(")
            emitArguments(arguments, into: &buffer)
            buffer.append(")")

        case .arrayLiteral(let elements):
            buffer.append("[")
            for (index, element) in elements.enumerated() {
                emit(element, into: &buffer)
                if index != elements.count - 1 { buffer.append(", ") }
            }
            buffer.append("]")

        case .tupleLiteral(let elements):
            buffer.append("(")
            for (index, element) in elements.enumerated() {
                emit(element, into: &buffer)
                if index != elements.count - 1 { buffer.append(", ") }
            }
            buffer.append(")")

        case .dictionaryLiteral(let entries):
            if entries.isEmpty {
                // Matches Renderer's DictionaryExprSyntax(content: .colon(...))
                // colon-only empty form, not `[: ]` or `[ : ]`.
                buffer.append("[:]")
            } else {
                buffer.append("[")
                for (index, entry) in entries.enumerated() {
                    emit(entry.key, into: &buffer)
                    buffer.append(": ")
                    emit(entry.value, into: &buffer)
                    if index != entries.count - 1 { buffer.append(", ") }
                }
                buffer.append("]")
            }

        case .subscriptAccess(let base, let index):
            emit(base, into: &buffer)
            buffer.append("[")
            emit(index, into: &buffer)
            buffer.append("]")

        case .subscriptCall(let base, let arguments):
            emit(base, into: &buffer)
            buffer.append("[")
            emitArguments(arguments, into: &buffer)
            buffer.append("]")

        case .forceUnwrap(let inner):
            emit(inner, into: &buffer)
            buffer.append("!")

        case .syntax(let node):
            // The parse-backed path has to serialise the node into the buffer,
            // so it is re-parsed as part of the fragment. `Renderer.renderLeaf`
            // short-circuits the common case where the node *is* the whole
            // template and hands it back untouched.
            buffer.append(node.description)

        case .cast(let inner, let type, let kind):
            emit(inner, parenthesizedInside: .casting, on: .left, into: &buffer)
            buffer.append(" ")
            buffer.append(kind.operatorText)
            buffer.append(" ")
            buffer.append(type)

        case .stringInterpolation(let segments):
            buffer.append("\"")
            for segment in segments {
                switch segment {
                case .text(let s):
                    // Legacy emits `.text` verbatim (no escaping pass via
                    // `escapeStringLiteral`) — replicate exactly, do not
                    // route through the string-literal escaper.
                    buffer.append(s)
                case .expression(let expr):
                    buffer.append("\\(")
                    emit(expr, into: &buffer)
                    buffer.append(")")
                }
            }
            buffer.append("\"")

        case .closure(let sig):
            // Bridges to the legacy structural Statement renderer —
            // SourceEmitter's own Statement-level emission doesn't exist
            // until Task 4. This mirrors the benchmark spike's established
            // pattern of serializing already-built syntax via
            // `trimmedDescription` when accepting extracted/structural
            // input (see Benchmarks/.../SpikePipelines.swift,
            // ParseBackedMTKPipeline). It stays token-identical because it
            // re-serializes and re-parses the exact same structural tree
            // the legacy renderer builds for `sig.body` — no semantic
            // difference, only construction mechanism differs for this one
            // nested piece. Intentional, not a shortcut.
            let hasSignature = !sig.attributes.isEmpty || !sig.parameters.isEmpty || sig.returnType != nil
            buffer.append("{ ")
            if hasSignature {
                emitClosureSignature(sig, into: &buffer)
                buffer.append(" in ")
            }
            // Emitted straight into the buffer rather than routed through
            // `Renderer.renderStatements(...).formatted().trimmedDescription`:
            // that built syntax nodes, normalised their trivia, serialised
            // them back to text, and let this buffer's parse re-parse the
            // result — a full round trip inside the emitter. `emitStatements`
            // writes explicit separators, so tokens cannot re-lex together.
            emitStatements(sig.body, into: &buffer)
            buffer.append(" }")

        case .assignment(let lhs, let rhs):
            emit(lhs, into: &buffer)
            buffer.append(" = ")
            emit(rhs, into: &buffer)

        case .selfAccess(let typeName):
            buffer.append(typeName)
            buffer.append(".self")
        }
    }

    /// Shared `(label: value, ...)` text-emission for `.functionCall`,
    /// `.methodCall`, `.genericCall`, and `.subscriptCall` — all four mirror
    /// `Renderer.renderLabeledExprList`'s token shape: `label:` only when
    /// `argument.label != nil`, comma-separated, no trailing comma.
    private static func emitArguments<A: Sendable>(
        _ arguments: [(label: String?, value: Template<A>)],
        into buffer: inout String
    ) {
        for (index, argument) in arguments.enumerated() {
            if let label = argument.label {
                buffer.append(label)
                buffer.append(": ")
            }
            emit(argument.value, into: &buffer)
            if index != arguments.count - 1 { buffer.append(", ") }
        }
    }

    /// Text-emission counterpart to `Renderer.buildClosureSignature`: emits
    /// `(attrs) (p1: T1, p2: T2) -> ReturnType`. Callers append `" in "`
    /// after this to complete the signature.
    private static func emitClosureSignature<A: Sendable>(
        _ sig: ClosureSignature<A>,
        into buffer: inout String
    ) {
        if !sig.attributes.isEmpty {
            // Reuses `Renderer.renderAttributeSource`, which already
            // produces the exact `@Name(args)` text an attribute lowers to
            // — no need to duplicate its argument-source formatting here.
            buffer.append(sig.attributes.map(Renderer.renderAttributeSource).joined(separator: " "))
            buffer.append(" ")
        }
        buffer.append("(")
        for (index, param) in sig.parameters.enumerated() {
            buffer.append(param.name)
            if let type = param.type {
                // No colon token here: legacy's
                // `ClosureParameterSyntax(firstName:type:...)` convenience
                // init (see `buildClosureSignature` in Renderer.swift)
                // doesn't thread a colon token between name and type,
                // unlike e.g. `renderLabeledExprList`'s labeled arguments.
                // Replicated verbatim for token parity, not "fixed".
                buffer.append(" ")
                buffer.append(type)
            }
            if index != sig.parameters.count - 1 { buffer.append(", ") }
        }
        buffer.append(")")
        if let returnType = sig.returnType {
            buffer.append(" -> ")
            buffer.append(returnType)
        }
    }

    static func emit(_ value: LiteralValue, into buffer: inout String) {
        switch value {
        case .integer(let int): buffer.append(String(int))
        case .double(let double): buffer.append(String(double))
        case .boolean(let bool): buffer.append(bool ? "true" : "false")
        case .nil: buffer.append("nil")
        case .string(let string):
            let poundCount = rawStringPoundCount(for: string)
            let pounds = String(repeating: "#", count: poundCount)
            buffer.append(pounds)
            buffer.append("\"")
            buffer.append(escapeStringLiteral(string, poundCount: poundCount))
            buffer.append("\"")
            buffer.append(pounds)
        }
    }

    /// Emits `template` as an operand of an enclosing operator, adding
    /// parentheses when omitting them would change how the result parses.
    ///
    /// This is the guarantee a hand-written source string cannot offer: a
    /// string has no structure to inspect, so its author must track precedence
    /// themselves. A `Template` knows its own shape.
    static func emit<A: Sendable>(
        _ template: Template<A>,
        parenthesizedInside parent: Precedence,
        on side: Template<A>.Side,
        into buffer: inout String
    ) {
        guard template.needsParentheses(inside: parent, on: side) else {
            return emit(template, into: &buffer)
        }
        buffer.append("(")
        emit(template, into: &buffer)
        buffer.append(")")
    }

    /// Swift keywords that are reserved everywhere and therefore need backtick
    /// escaping when used as an identifier.
    ///
    /// Deliberately excludes two groups:
    ///
    /// - *Contextual* keywords (`open`, `some`, `any`, `get`, `set`, `willSet`,
    ///   `didSet`, `convenience`, `final`, `lazy`, `weak`, `unowned`, `mutating`,
    ///   `nonmutating`, `optional`, `override`, `required`, `indirect`,
    ///   `dynamic`, `infix`, `prefix`, `postfix`, `associativity`, ...). These
    ///   are legal identifiers bare; escaping them would add noise and break
    ///   token parity with the legacy renderer.
    /// - Keywords that are legal *expressions* (`self`, `Self`, `super`, `nil`,
    ///   `true`, `false`, `Any`) and the wildcard `_`. A `.variable("self")`
    ///   means the `self` expression, not an identifier named "self", so
    ///   escaping it would change meaning rather than preserve it.
    static let reservedKeywords: Set<String> = [
        // Declarations
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "operator",
        "precedencegroup", "private", "protocol", "public", "static", "struct",
        "subscript", "typealias", "var",
        // Statements
        "break", "case", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw",
        "switch", "where", "while",
        // Expressions and types
        "as", "catch", "is", "rethrows", "throws", "try",
    ]

    /// Wraps `name` in backticks when it is a reserved keyword, so it is legal
    /// in identifier position.
    ///
    /// Apply this at *binding* sites — declaration names, enum case names,
    /// generic parameter names, a parameter's internal name, and variable
    /// references. Do **not** apply it to argument labels or to members after a
    /// `.`: Swift accepts keywords bare in both positions, so escaping there
    /// would emit needless backticks and diverge from the legacy renderer.
    ///
    /// Names that are already backticked are returned unchanged, so callers can
    /// pass through identifiers a user escaped by hand.
    static func escapeIdentifier(_ name: String) -> String {
        guard reservedKeywords.contains(name) else { return name }
        return "`\(name)`"
    }

    /// Escapes content for a Swift string literal, matching the token text
    /// `StringLiteralExprSyntax(content:)` produces.
    ///
    /// Mirrors SwiftSyntaxBuilder's own algorithm rather than the naive
    /// backslash-escaping of `"` and `\`: if `raw` contains an unescaped `"`
    /// or `\`, `StringLiteralExprSyntax(content:)` emits a *raw* string
    /// literal (`#"..."#`, with as many `#`s as needed to disambiguate) and
    /// leaves quotes/backslashes untouched inside it — only newlines and
    /// other unprintable ASCII control characters are backslash-escaped
    /// (prefixed by the same number of `#`s as the delimiter, per Swift's raw
    /// string escape syntax `\#n`). `emit(_:into:)` wraps this content with
    /// the matching opening/closing pound delimiters.
    ///
    /// - Parameter poundCount: The raw-string pound count already computed
    ///   for `raw` by the caller (via `rawStringPoundCount(for:)`), threaded
    ///   through rather than recomputed here so `raw` is scanned only once
    ///   per literal.
    static func escapeStringLiteral(_ raw: String, poundCount: Int) -> String {
        let delimiter = String(repeating: "#", count: poundCount)
        var out = ""
        out.reserveCapacity(raw.count)
        for scalar in raw.unicodeScalars {
            if let escape = controlCharacterEscape(for: scalar) {
                out.append("\\")
                out.append(delimiter)
                out.append(escape)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    /// Returns the escape suffix (the text following `\` + delimiter) for a
    /// scalar that a single-line Swift string literal cannot contain
    /// unescaped, or `nil` if the scalar needs no escaping.
    ///
    /// Matches `StringLiteralExprSyntax`'s single-line escaping rules:
    /// newlines (including Unicode line/paragraph separators, which Swift's
    /// `Character.isNewline` also treats as newlines) and other unprintable
    /// ASCII control characters (including tab, since single-line literals —
    /// unlike multiline ones — must escape tab) are escaped; printable ASCII
    /// and non-ASCII scalars are left as-is.
    private static func controlCharacterEscape(for scalar: Unicode.Scalar) -> String? {
        let isPrintableASCII = scalar.value >= 0x20 && scalar.value < 0x7F
        let needsEscaping = Character(scalar).isNewline || (scalar.isASCII && !isPrintableASCII)
        guard needsEscaping else { return nil }
        switch scalar {
        case "\r": return "r"
        case "\n": return "n"
        case "\t": return "t"
        case "\0": return "0"
        default: return "u{\(String(scalar.value, radix: 16))}"
        }
    }

    /// Computes how many `#`s are needed to delimit `raw` as a raw string
    /// literal (`0` if `raw` contains no `"` or `\`, so an ordinary
    /// `"..."` literal suffices).
    ///
    /// Mirrors `StringLiteralExprSyntax.requiresEscaping`: scans `raw` for
    /// any `"` or `\`, and if found, returns one more than the longest run of
    /// consecutive `#` characters adjacent to a `"` or `\` — the minimal
    /// pound count that disambiguates the raw string's closing delimiter from
    /// any `#` sequence already present in the content.
    private static func rawStringPoundCount(for raw: String) -> Int {
        var countingPounds = false
        var consecutivePounds = 0
        var maxPounds = 0
        var requiresEscaping = false

        for character in raw {
            switch (countingPounds, character) {
            case (false, "\""), (false, "\\"):
                countingPounds = true
                requiresEscaping = true
            case (false, _):
                continue
            case (true, _) where character.unicodeScalars.contains("#"):
                consecutivePounds += 1
                maxPounds = max(maxPounds, consecutivePounds)
            case (true, "\""), (true, "\\"):
                continue
            case (true, _):
                countingPounds = false
                consecutivePounds = 0
            }
        }

        return requiresEscaping ? maxPounds + 1 : 0
    }
}
