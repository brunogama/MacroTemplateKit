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

  // MARK: - Pattern Matching

  /// guard case <pattern> = value else { ... }
  ///
  /// The pattern-matching counterpart to `guardLetBinding`, which can only
  /// unwrap an optional. Enum-driven macros need this to destructure a case:
  /// `guard case let .success(value) = result else { return nil }`.
  ///
  /// SwiftSyntax equivalent: `GuardStmtSyntax` with a
  /// `MatchingPatternConditionSyntax` condition
  case guardCase(pattern: MatchPattern<A>, value: Template<A>, elseBody: [Statement<A>])

  /// if case <pattern> = value { ... } else { ... }
  ///
  /// SwiftSyntax equivalent: `IfExprSyntax` with a
  /// `MatchingPatternConditionSyntax` condition
  case ifCase(
    pattern: MatchPattern<A>,
    value: Template<A>,
    thenBody: [Statement<A>],
    elseBody: [Statement<A>]?
  )

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
      return mapGuardStatement(condition, elseBody, using: transform)
    case .ifStatement(let condition, let thenBody, let elseBody):
      return mapIfStatement(condition, thenBody, elseBody, using: transform)
    case .forInStatement(let variable, let collection, let body):
      return mapForInStatement(variable, collection, body, using: transform)
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
    case .expression(let expression):
      return .expression(expression.map(transform))
    case .guardLetBinding(let name, let type, let initializer, let elseBody):
      return mapGuardLetBinding(name, type, initializer, elseBody, using: transform)
    case .switchStatement(let subject, let cases):
      return mapSwitchStatement(subject, cases, using: transform)
    case .assignmentStatement(let lhs, let rhs):
      return .assignmentStatement(lhs: lhs.map(transform), rhs: rhs.map(transform))
    case .guardCase(let pattern, let value, let elseBody):
      return mapGuardCase(pattern, value, elseBody, using: transform)
    case .ifCase(let pattern, let value, let thenBody, let elseBody):
      return mapIfCase(pattern, value, thenBody, elseBody, using: transform)
    case .breakStatement:
      return .breakStatement
    }
  }

  private func mapGuardStatement<B>(
    _ condition: Template<A>,
    _ elseBody: [Statement<A>],
    using transform: (A) -> B
  ) -> Statement<B> {
    .guardStatement(
      condition: condition.map(transform),
      elseBody: elseBody.map { $0.map(transform) }
    )
  }

  private func mapIfStatement<B>(
    _ condition: Template<A>,
    _ thenBody: [Statement<A>],
    _ elseBody: [Statement<A>]?,
    using transform: (A) -> B
  ) -> Statement<B> {
    .ifStatement(
      condition: condition.map(transform),
      thenBody: thenBody.map { $0.map(transform) },
      elseBody: elseBody?.map { $0.map(transform) }
    )
  }

  private func mapForInStatement<B>(
    _ variable: String,
    _ collection: Template<A>,
    _ body: [Statement<A>],
    using transform: (A) -> B
  ) -> Statement<B> {
    .forInStatement(
      variable: variable,
      collection: collection.map(transform),
      body: body.map { $0.map(transform) }
    )
  }

  private func mapGuardLetBinding<B>(
    _ name: String,
    _ type: String?,
    _ initializer: Template<A>,
    _ elseBody: [Statement<A>],
    using transform: (A) -> B
  ) -> Statement<B> {
    .guardLetBinding(
      name: name,
      type: type,
      initializer: initializer.map(transform),
      elseBody: elseBody.map { $0.map(transform) }
    )
  }

  private func mapSwitchStatement<B>(
    _ subject: Template<A>,
    _ cases: [SwitchCase<A>],
    using transform: (A) -> B
  ) -> Statement<B> {
    .switchStatement(
      subject: subject.map(transform),
      cases: cases.map { switchCase in
        SwitchCase<B>(
          pattern: mapSwitchCasePattern(switchCase.pattern, transform),
          body: switchCase.body.map { $0.map(transform) }
        )
      }
    )
  }

  private func mapGuardCase<B>(
    _ pattern: MatchPattern<A>,
    _ value: Template<A>,
    _ elseBody: [Statement<A>],
    using transform: (A) -> B
  ) -> Statement<B> {
    .guardCase(
      pattern: pattern.map(transform),
      value: value.map(transform),
      elseBody: elseBody.map { $0.map(transform) }
    )
  }

  private func mapIfCase<B>(
    _ pattern: MatchPattern<A>,
    _ value: Template<A>,
    _ thenBody: [Statement<A>],
    _ elseBody: [Statement<A>]?,
    using transform: (A) -> B
  ) -> Statement<B> {
    .ifCase(
      pattern: pattern.map(transform),
      value: value.map(transform),
      thenBody: thenBody.map { $0.map(transform) },
      elseBody: elseBody?.map { $0.map(transform) }
    )
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
