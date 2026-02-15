/// Statement-level code generation templates.
///
/// Complements `Template<A>` (expressions) with statement-level constructs
/// needed for macro expansion: variable bindings, control flow, and returns.
///
/// `Statement<A>` is a functor that maps over all embedded `Template<A>` expressions,
/// allowing transformation of metadata payloads while preserving statement structure.
public indirect enum Statement<A> {
  // MARK: - Variable Bindings

  /// let name: Type = initializer
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `let` keyword
  case letBinding(
    name: String,
    type: String?,
    initializer: Template<A>
  )

  /// var name: Type = initializer
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `var` keyword
  case varBinding(
    name: String,
    type: String?,
    initializer: Template<A>
  )

  // MARK: - Control Flow

  /// guard condition else { statements; return/throw }
  ///
  /// SwiftSyntax equivalent: `GuardStmtSyntax` with `CodeBlockItemListSyntax`
  case guardStatement(
    condition: Template<A>,
    elseBody: [Statement<A>]
  )

  /// if condition { then } else { else }
  ///
  /// SwiftSyntax equivalent: `IfExprSyntax` with optional `CodeBlockSyntax`
  case ifStatement(
    condition: Template<A>,
    thenBody: [Statement<A>],
    elseBody: [Statement<A>]?
  )

  // MARK: - Returns and Throws

  /// return expression
  ///
  /// SwiftSyntax equivalent: `ReturnStmtSyntax` with optional `ExprSyntax`
  case returnStatement(Template<A>?)

  /// throw expression
  ///
  /// SwiftSyntax equivalent: `ThrowStmtSyntax` with `ExprSyntax`
  case throwStatement(Template<A>)

  // MARK: - Defer

  /// defer { statements }
  ///
  /// SwiftSyntax equivalent: `DeferStmtSyntax` with `CodeBlockSyntax`
  case deferStatement([Statement<A>])

  // MARK: - Expressions as Statements

  /// expression (function call, assignment, etc.)
  ///
  /// SwiftSyntax equivalent: `ExprSyntax` in statement position
  case expression(Template<A>)
}

// MARK: - Functor

extension Statement {
  /// Maps a transformation function over all embedded expression payloads.
  ///
  /// This operation satisfies functor laws:
  /// - Identity: `statement.map { $0 } == statement`
  /// - Composition: `statement.map(f).map(g) == statement.map { g(f($0)) }`
  ///
  /// All `Template<A>` expressions are transformed recursively; statement structure is preserved.
  ///
  /// - Parameter transform: Function applied to each variable payload in nested templates
  /// - Returns: New statement with transformed payloads and identical structure
  public func map<B>(_ transform: (A) -> B) -> Statement<B> {
    switch self {
    case .letBinding(let name, let type, let initializer):
      return .letBinding(name: name, type: type, initializer: initializer.map(transform))
    case .varBinding(let name, let type, let initializer):
      return .varBinding(name: name, type: type, initializer: initializer.map(transform))
    case .guardStatement(let condition, let elseBody):
      return .guardStatement(
        condition: condition.map(transform),
        elseBody: elseBody.map { $0.map(transform) }
      )
    case .ifStatement(let condition, let thenBody, let elseBody):
      return .ifStatement(
        condition: condition.map(transform),
        thenBody: thenBody.map { $0.map(transform) },
        elseBody: elseBody?.map { $0.map(transform) }
      )
    case .returnStatement(let expression):
      return .returnStatement(expression?.map(transform))
    case .throwStatement(let expression):
      return .throwStatement(expression.map(transform))
    case .deferStatement(let body):
      return .deferStatement(body.map { $0.map(transform) })
    case .expression(let expr):
      return .expression(expr.map(transform))
    }
  }
}

// MARK: - Equatable

extension Statement: Equatable where A: Equatable {}

// MARK: - Hashable

extension Statement: Hashable where A: Hashable {}

// MARK: - Sendable

extension Statement: Sendable where A: Sendable {}
