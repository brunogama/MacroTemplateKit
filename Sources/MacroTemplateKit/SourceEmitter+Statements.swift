import SwiftSyntax
import SwiftSyntaxBuilder

/// Statement-level counterpart to `SourceEmitter`'s `Template` emission
/// (`SourceEmitter.swift`, Task 3): walks `Statement<A>` values appending
/// Swift source text to a buffer, delegating to `emit(_: Template<A>, into:)`
/// for every embedded expression. `Renderer.renderParsed(_: Statement<A>)`
/// (`StatementRenderer.swift`) parses the resulting buffer once per
/// statement.
extension SourceEmitter {
  /// Dispatches each statement case to a focused emitter while keeping this
  /// switch exhaustive over `Statement`.
  static func emit<A: Sendable>(_ statement: Statement<A>, into buffer: inout String) {
    switch statement {
    case .letBinding(let name, let type, let initializer):
      emitBinding("let ", name, type, initializer, into: &buffer)
    case .varBinding(let name, let type, let initializer):
      emitBinding("var ", name, type, initializer, into: &buffer)
    case .guardStatement(let condition, let elseBody):
      emitGuardStatement(condition, elseBody, into: &buffer)
    case .ifStatement(let condition, let thenBody, let elseBody):
      emitIfStatement(condition, thenBody, elseBody, into: &buffer)
    case .forInStatement(let variable, let collection, let body):
      emitForInStatement(variable, collection, body, into: &buffer)
    case .ifLetBinding(let name, let type, let initializer, let thenBody, let elseBody):
      emitBinding("if let ", name, type, initializer, into: &buffer)
      emitConditionalBody(thenBody, elseBody, into: &buffer)
    case .returnStatement(let expression):
      emitReturnStatement(expression, into: &buffer)
    case .throwStatement(let expression):
      emitThrowStatement(expression, into: &buffer)
    case .deferStatement(let body):
      emitDeferStatement(body, into: &buffer)
    case .expression(let expression):
      emit(expression, into: &buffer)
    case .guardLetBinding(let name, let type, let initializer, let elseBody):
      emitGuardLetBinding(name, type, initializer, elseBody, into: &buffer)
    case .switchStatement(let subject, let cases):
      emitSwitchStatement(subject, cases, into: &buffer)
    case .assignmentStatement(let lhs, let rhs):
      emitAssignmentStatement(lhs, rhs, into: &buffer)
    case .guardCase(let pattern, let value, let elseBody):
      emitGuardCase(pattern, value, elseBody, into: &buffer)
    case .ifCase(let pattern, let value, let thenBody, let elseBody):
      emitIfCase(pattern, value, thenBody, elseBody, into: &buffer)
    case .breakStatement:
      buffer.append("break")
    }
  }

  // MARK: - Per-case emission

  private static func emitBinding<A: Sendable>(
    _ keyword: String,
    _ name: String,
    _ type: String?,
    _ initializer: Template<A>,
    into buffer: inout String
  ) {
    buffer.append(keyword)
    buffer.append(name)
    if let type {
      buffer.append(": ")
      buffer.append(type)
    }
    buffer.append(" = ")
    emit(initializer, into: &buffer)
  }

  private static func emitGuardStatement<A: Sendable>(
    _ condition: Template<A>,
    _ elseBody: [Statement<A>],
    into buffer: inout String
  ) {
    buffer.append("guard ")
    emit(condition, into: &buffer)
    buffer.append(" else {\n")
    emitStatements(elseBody, into: &buffer)
    buffer.append("}")
  }

  private static func emitIfStatement<A: Sendable>(
    _ condition: Template<A>,
    _ thenBody: [Statement<A>],
    _ elseBody: [Statement<A>]?,
    into buffer: inout String
  ) {
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
  }

  private static func emitForInStatement<A: Sendable>(
    _ variable: String,
    _ collection: Template<A>,
    _ body: [Statement<A>],
    into buffer: inout String
  ) {
    buffer.append("for ")
    buffer.append(variable)
    buffer.append(" in ")
    emit(collection, into: &buffer)
    buffer.append(" {\n")
    emitStatements(body, into: &buffer)
    buffer.append("}")
  }

  private static func emitConditionalBody<A: Sendable>(
    _ thenBody: [Statement<A>],
    _ elseBody: [Statement<A>]?,
    into buffer: inout String
  ) {
    buffer.append(" {\n")
    emitStatements(thenBody, into: &buffer)
    buffer.append("}")
    if let elseBody {
      buffer.append(" else {\n")
      emitStatements(elseBody, into: &buffer)
      buffer.append("}")
    }
  }

  /// `expression` is optional (bare `return`); the legacy renderer's
  /// `ReturnStmtSyntax(expression:)` omits the expression clause when nil.
  private static func emitReturnStatement<A: Sendable>(
    _ expression: Template<A>?,
    into buffer: inout String
  ) {
    buffer.append("return")
    if let expression {
      buffer.append(" ")
      emit(expression, into: &buffer)
    }
  }

  private static func emitThrowStatement<A: Sendable>(
    _ expression: Template<A>,
    into buffer: inout String
  ) {
    buffer.append("throw ")
    emit(expression, into: &buffer)
  }

  private static func emitDeferStatement<A: Sendable>(
    _ body: [Statement<A>],
    into buffer: inout String
  ) {
    buffer.append("defer {\n")
    emitStatements(body, into: &buffer)
    buffer.append("}")
  }

  private static func emitGuardLetBinding<A: Sendable>(
    _ name: String,
    _ type: String?,
    _ initializer: Template<A>,
    _ elseBody: [Statement<A>],
    into buffer: inout String
  ) {
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
  }

  private static func emitSwitchStatement<A: Sendable>(
    _ subject: Template<A>,
    _ cases: [SwitchCase<A>],
    into buffer: inout String
  ) {
    buffer.append("switch ")
    emit(subject, into: &buffer)
    buffer.append(" {\n")
    for switchCase in cases {
      emitSwitchCase(switchCase, into: &buffer)
    }
    buffer.append("}")
  }

  /// Same token shape as `Template.assignment` in `SourceEmitter.swift`.
  private static func emitAssignmentStatement<A: Sendable>(
    _ lhs: Template<A>,
    _ rhs: Template<A>,
    into buffer: inout String
  ) {
    emit(lhs, into: &buffer)
    buffer.append(" = ")
    emit(rhs, into: &buffer)
  }

  private static func emitGuardCase<A: Sendable>(
    _ pattern: MatchPattern<A>,
    _ value: Template<A>,
    _ elseBody: [Statement<A>],
    into buffer: inout String
  ) {
    buffer.append("guard ")
    emitMatch(pattern, value: value, into: &buffer)
    buffer.append(" else {\n")
    emitStatements(elseBody, into: &buffer)
    buffer.append("}")
  }

  private static func emitIfCase<A: Sendable>(
    _ pattern: MatchPattern<A>,
    _ value: Template<A>,
    _ thenBody: [Statement<A>],
    _ elseBody: [Statement<A>]?,
    into buffer: inout String
  ) {
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
