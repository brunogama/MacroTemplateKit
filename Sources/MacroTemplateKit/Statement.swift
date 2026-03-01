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

  /// for variable in collection { body }
  ///
  /// SwiftSyntax equivalent: `ForInStmtSyntax`
  case forInStatement(
    variable: String,
    collection: Template<A>,
    body: [Statement<A>]
  )

  /// if let name: Type = initializer { thenBody } else { elseBody }
  ///
  /// Uses `OptionalBindingConditionSyntax` for optional binding condition.
  /// The type annotation is optional; omit if nil.
  ///
  /// SwiftSyntax equivalent: `IfExprSyntax` with `OptionalBindingConditionSyntax`
  case ifLetBinding(
    name: String,
    type: String?,
    initializer: Template<A>,
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

  // MARK: - Guard Let Binding

  /// guard let name: Type = expr else { body }
  ///
  /// Uses `OptionalBindingConditionSyntax` — this is a guard-let, not a boolean guard.
  /// The type annotation is optional; omit if nil.
  ///
  /// SwiftSyntax equivalent: `GuardStmtSyntax` with `OptionalBindingConditionSyntax`
  case guardLetBinding(
    name: String,
    type: String?,
    initializer: Template<A>,
    elseBody: [Statement<A>]
  )

  // MARK: - Switch Statement

  /// switch subject { case ...: body }
  ///
  /// SwiftSyntax equivalent: `SwitchExprSyntax`
  case switchStatement(subject: Template<A>, cases: [SwitchCase<A>])

  // MARK: - Assignment Statement

  /// lhs = rhs as a statement (assignment expression in statement position).
  ///
  /// SwiftSyntax equivalent: `InfixOperatorExprSyntax` wrapped in `CodeBlockItemSyntax`
  case assignmentStatement(lhs: Template<A>, rhs: Template<A>)

  // MARK: - Break Statement

  /// break
  ///
  /// SwiftSyntax equivalent: `BreakStmtSyntax`
  case breakStatement
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
    case .forInStatement(let variable, let collection, let body):
      return .forInStatement(
        variable: variable,
        collection: collection.map(transform),
        body: body.map { $0.map(transform) }
      )
    case .ifLetBinding(let name, let type, let initializer, let thenBody, let elseBody):
      return .ifLetBinding(
        name: name,
        type: type,
        initializer: initializer.map(transform),
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
    case .guardLetBinding(let name, let type, let initializer, let elseBody):
      return .guardLetBinding(
        name: name,
        type: type,
        initializer: initializer.map(transform),
        elseBody: elseBody.map { $0.map(transform) }
      )
    case .switchStatement(let subject, let cases):
      return .switchStatement(
        subject: subject.map(transform),
        cases: cases.map { switchCase in
          SwitchCase<B>(
            pattern: mapSwitchCasePattern(switchCase.pattern, transform),
            body: switchCase.body.map { $0.map(transform) }
          )
        }
      )
    case .assignmentStatement(let lhs, let rhs):
      return .assignmentStatement(lhs: lhs.map(transform), rhs: rhs.map(transform))
    case .breakStatement:
      return .breakStatement
    }
  }

  private func mapSwitchCasePattern<B>(
    _ pattern: SwitchCasePattern<A>,
    _ transform: (A) -> B
  ) -> SwitchCasePattern<B> {
    switch pattern {
    case .expression(let expr):
      return .expression(expr.map(transform))
    case .stringLiteral(let s):
      return .stringLiteral(s)
    case .defaultCase:
      return .defaultCase
    }
  }
}

// MARK: - Equatable

extension Statement: Equatable where A: Equatable {}

// MARK: - Hashable

extension Statement: Hashable where A: Hashable {}

// MARK: - Sendable

extension Statement: Sendable where A: Sendable {}
