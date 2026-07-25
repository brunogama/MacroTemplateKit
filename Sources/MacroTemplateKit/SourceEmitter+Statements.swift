import SwiftSyntax
import SwiftSyntaxBuilder

/// Statement-level counterpart to `SourceEmitter`'s `Template` emission
/// (`SourceEmitter.swift`, Task 3): walks `Statement<A>` values appending
/// Swift source text to a buffer, delegating to `emit(_: Template<A>, into:)`
/// for every embedded expression. `Renderer.renderParsed(_: Statement<A>)`
/// (`StatementRenderer.swift`) parses the resulting buffer once per
/// statement.
extension SourceEmitter {
    static func emit<A: Sendable>(_ statement: Statement<A>, into buffer: inout String) {
        switch statement {
        case .letBinding(let name, let type, let initializer):
            buffer.append("let ")
            buffer.append(name)
            if let type {
                buffer.append(": ")
                buffer.append(type)
            }
            buffer.append(" = ")
            emit(initializer, into: &buffer)

        case .varBinding(let name, let type, let initializer):
            buffer.append("var ")
            buffer.append(name)
            if let type {
                buffer.append(": ")
                buffer.append(type)
            }
            buffer.append(" = ")
            emit(initializer, into: &buffer)

        case .guardStatement(let condition, let elseBody):
            buffer.append("guard ")
            emit(condition, into: &buffer)
            buffer.append(" else {\n")
            emitStatements(elseBody, into: &buffer)
            buffer.append("}")

        case .ifStatement(let condition, let thenBody, let elseBody):
            buffer.append("if ")
            emit(condition, into: &buffer)
            buffer.append(" {\n")
            emitStatements(thenBody, into: &buffer)
            buffer.append("}")
            if let elseBody {
                buffer.append(" else {\n")
                emitStatements(elseBody, into: &buffer)
                buffer.append("}")
            }

        case .forInStatement(let variable, let collection, let body):
            buffer.append("for ")
            buffer.append(variable)
            buffer.append(" in ")
            emit(collection, into: &buffer)
            buffer.append(" {\n")
            emitStatements(body, into: &buffer)
            buffer.append("}")

        case .ifLetBinding(let name, let type, let initializer, let thenBody, let elseBody):
            buffer.append("if let ")
            buffer.append(name)
            if let type {
                buffer.append(": ")
                buffer.append(type)
            }
            buffer.append(" = ")
            emit(initializer, into: &buffer)
            buffer.append(" {\n")
            emitStatements(thenBody, into: &buffer)
            buffer.append("}")
            if let elseBody {
                buffer.append(" else {\n")
                emitStatements(elseBody, into: &buffer)
                buffer.append("}")
            }

        case .returnStatement(let expression):
            // `expression` is optional (bare `return`); the legacy renderer
            // (`ReturnStmtSyntax(expression:)`) omits the expression clause
            // entirely when nil, rather than rendering an empty one.
            buffer.append("return")
            if let expression {
                buffer.append(" ")
                emit(expression, into: &buffer)
            }

        case .throwStatement(let expression):
            buffer.append("throw ")
            emit(expression, into: &buffer)

        case .deferStatement(let body):
            buffer.append("defer {\n")
            emitStatements(body, into: &buffer)
            buffer.append("}")

        case .expression(let expr):
            emit(expr, into: &buffer)

        case .guardLetBinding(let name, let type, let initializer, let elseBody):
            buffer.append("guard let ")
            buffer.append(name)
            if let type {
                buffer.append(": ")
                buffer.append(type)
            }
            buffer.append(" = ")
            emit(initializer, into: &buffer)
            buffer.append(" else {\n")
            emitStatements(elseBody, into: &buffer)
            buffer.append("}")

        case .switchStatement(let subject, let cases):
            buffer.append("switch ")
            emit(subject, into: &buffer)
            buffer.append(" {\n")
            for switchCase in cases {
                emitSwitchCase(switchCase, into: &buffer)
            }
            buffer.append("}")

        case .assignmentStatement(let lhs, let rhs):
            // Same shape as `Template.assignment` in `SourceEmitter.swift`:
            // `InfixOperatorExprSyntax` with `AssignmentExprSyntax`.
            emit(lhs, into: &buffer)
            buffer.append(" = ")
            emit(rhs, into: &buffer)

        case .guardCase(let pattern, let value, let elseBody):
            buffer.append("guard ")
            emitMatch(pattern, value: value, into: &buffer)
            buffer.append(" else {\n")
            emitStatements(elseBody, into: &buffer)
            buffer.append("}")

        case .ifCase(let pattern, let value, let thenBody, let elseBody):
            buffer.append("if ")
            emitMatch(pattern, value: value, into: &buffer)
            buffer.append(" {\n")
            emitStatements(thenBody, into: &buffer)
            buffer.append("}")
            if let elseBody {
                buffer.append(" else {\n")
                emitStatements(elseBody, into: &buffer)
                buffer.append("}")
            }

        case .breakStatement:
            buffer.append("break")
        }
    }

    /// Emits `case <pattern> = <value>`, the shared condition form of
    /// `guard case` and `if case`.
    private static func emitMatch<A: Sendable>(
        _ pattern: MatchPattern<A>,
        value: Template<A>,
        into buffer: inout String
    ) {
        buffer.append("case ")
        emit(pattern, into: &buffer)
        buffer.append(" = ")
        emit(value, into: &buffer)
    }

    /// Emits a pattern, hoisting a single `let` to the front when it binds
    /// any name.
    ///
    /// `case let .success(value)` and `case .success(let value)` are the same
    /// pattern to Swift. Hoisting is chosen because it is what the standard
    /// library and the CasePaths macros emit, and because it keeps the
    /// recursive walk free of binding state — the decision is made once at
    /// the root by `bindsAnyName` rather than threaded down.
    static func emit<A: Sendable>(_ pattern: MatchPattern<A>, into buffer: inout String) {
        if pattern.bindsAnyName {
            buffer.append("let ")
        }
        emitPatternBody(pattern, into: &buffer)
    }

    private static func emitPatternBody<A: Sendable>(
        _ pattern: MatchPattern<A>,
        into buffer: inout String
    ) {
        switch pattern {
        case .enumCase(let name, let subpatterns):
            // The leading dot keeps the enum type inferred from the matched
            // value; a qualified `MyEnum.success` is an expression pattern
            // and belongs in `.value`.
            buffer.append(".")
            buffer.append(escapeIdentifier(name))
            guard !subpatterns.isEmpty else { return }
            buffer.append("(")
            for (index, subpattern) in subpatterns.enumerated() {
                if index > 0 { buffer.append(", ") }
                emitPatternBody(subpattern, into: &buffer)
            }
            buffer.append(")")

        case .bind(let name):
            buffer.append(escapeIdentifier(name))

        case .wildcard:
            buffer.append("_")

        case .tuple(let subpatterns):
            buffer.append("(")
            for (index, subpattern) in subpatterns.enumerated() {
                if index > 0 { buffer.append(", ") }
                emitPatternBody(subpattern, into: &buffer)
            }
            buffer.append(")")

        case .value(let template):
            emit(template, into: &buffer)
        }
    }

    /// Emits each statement in `statements` followed by a newline so
    /// consecutive statements in a code block (guard/if/for/defer bodies,
    /// switch case bodies) always have a lexical boundary between them —
    /// e.g. a bare `return` immediately followed by another statement's
    /// leading identifier must not re-lex as one merged token. A real
    /// newline keeps the emitted text closest to what hand-written Swift
    /// source (or the legacy structural renderer, once formatted) would
    /// produce, and Swift's newline-terminated-statement grammar parses it
    /// exactly like any other statement separator.
    ///
    /// Internal rather than private: `SourceEmitter+Declarations.swift`
    /// (Task 5) reuses this exact per-statement/newline emission for
    /// function bodies, initializer bodies, and computed-property
    /// accessor bodies — those are all just `[Statement<A>]` values embedded
    /// inside a `Declaration`, the same shape as the then/else/loop bodies
    /// emitted here, so duplicating this loop there would just be a second
    /// copy of the same lexical-boundary logic.
    static func emitStatements<A: Sendable>(
        _ statements: [Statement<A>],
        into buffer: inout String
    ) {
        for statement in statements {
            emit(statement, into: &buffer)
            buffer.append("\n")
        }
    }

    /// Emits one `case pattern:` / `default:` label followed by its body,
    /// mirroring `Renderer.renderSwitchCase`'s three pattern kinds exactly.
    private static func emitSwitchCase<A: Sendable>(
        _ switchCase: SwitchCase<A>,
        into buffer: inout String
    ) {
        switch switchCase.pattern {
        case .expression(let expr):
            buffer.append("case ")
            emit(expr, into: &buffer)
        case .stringLiteral(let s):
            // Reuses the `LiteralValue.string` emission (pound-escaping
            // included) rather than re-implementing string-literal token
            // text here: `renderSwitchCase` builds this case's pattern via
            // the very same `StringLiteralExprSyntax(content:)` convenience
            // initializer that backs `Template.literal(.string)`, so the
            // token text the two produce is identical by construction.
            buffer.append("case ")
            emit(LiteralValue.string(s), into: &buffer)
        case .defaultCase:
            buffer.append("default")
        }
        buffer.append(":\n")
        emitStatements(switchCase.body, into: &buffer)
    }
}
