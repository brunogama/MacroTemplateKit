/// A segment in a string interpolation expression.
///
/// Used by `Template.stringInterpolation` to represent either a literal text
/// segment or an interpolated expression segment within a string literal.
public enum StringInterpolationSegment<A> {
  /// A literal text segment (no interpolation).
  case text(String)
  /// An interpolated expression segment (`\(expr)`).
  case expression(Template<A>)
}

/// Signature for a closure expression.
///
/// Carries parameter names, optional type annotations, optional return type,
/// and body statements for rendering as a `ClosureExprSyntax`.
public struct ClosureSignature<A> {
  /// Named parameters with optional type annotations.
  public let parameters: [(name: String, type: String?)]
  /// Optional explicit return type annotation.
  public let returnType: String?
  /// Body statements rendered inside the closure braces.
  public let body: [Statement<A>]

  /// Creates a closure signature.
  public init(parameters: [(name: String, type: String?)], returnType: String?, body: [Statement<A>]) {
    self.parameters = parameters
    self.returnType = returnType
    self.body = body
  }
}

/// A single case in a switch statement.
public struct SwitchCase<A> {
  /// The pattern matched by this case.
  public let pattern: SwitchCasePattern<A>
  /// Body statements executed when the pattern matches.
  public let body: [Statement<A>]

  /// Creates a switch case.
  public init(pattern: SwitchCasePattern<A>, body: [Statement<A>]) {
    self.pattern = pattern
    self.body = body
  }
}

/// The pattern for a single switch case.
public enum SwitchCasePattern<A> {
  /// Match by evaluating an expression pattern (e.g., `case myEnum.value:`).
  case expression(Template<A>)
  /// Match a string literal (e.g., `case "hello":`).
  case stringLiteral(String)
  /// The default case (`default:`).
  case defaultCase
}

/// Parametric algebraic data type representing code generation templates.
///
/// `Template<A>` is a functor that separates template structure from payload data.
/// The type parameter `A` represents metadata attached to variable references,
/// allowing compile-time tracking of variable usage without affecting rendering.
///
/// The 9 cases cover all common code generation patterns needed for Swift macro expansion.
public indirect enum Template<A> {
  // MARK: - Literals

  /// Primitive literal value (integer, double, string, boolean, nil).
  ///
  /// SwiftSyntax equivalent: `IntegerLiteralExprSyntax`, `StringLiteralExprSyntax`, etc.
  case literal(LiteralValue)

  // MARK: - Variables

  /// Identifier reference with parametric payload for metadata tracking.
  ///
  /// The payload allows attaching type information, scope context, or other
  /// compile-time data without affecting the rendered identifier name.
  ///
  /// SwiftSyntax equivalent: `IdentifierExprSyntax`
  case variable(String, payload: A)

  // MARK: - Control Flow

  /// Ternary conditional expression (condition ? thenBranch : elseBranch).
  ///
  /// SwiftSyntax equivalent: `TernaryExprSyntax`
  case conditional(
    condition: Template<A>,
    thenBranch: Template<A>,
    elseBranch: Template<A>
  )

  /// For-in loop iteration over a collection.
  ///
  /// Note: Rendered as `.forEach` closure pattern since SwiftSyntax expressions
  /// cannot directly represent for-in statements.
  ///
  /// SwiftSyntax equivalent: `FunctionCallExprSyntax` with forEach closure
  case loop(
    variable: String,
    collection: Template<A>,
    body: Template<A>
  )

  // MARK: - Operations

  /// N-ary function call with labeled or unlabeled arguments.
  ///
  /// SwiftSyntax equivalent: `FunctionCallExprSyntax` with `LabeledExprListSyntax`
  case functionCall(
    function: String,
    arguments: [(label: String?, value: Template<A>)]
  )

  /// Method call on an expression (base.method(args)).
  ///
  /// For calling methods on instances or chained expressions.
  /// Example: Date().timeIntervalSince(startTime) or Metrics.shared.record(...)
  ///
  /// SwiftSyntax equivalent: `FunctionCallExprSyntax` with `MemberAccessExprSyntax` callee
  case methodCall(
    base: Template<A>,
    method: String,
    arguments: [(label: String?, value: Template<A>)]
  )

  /// Infix binary operation (left operator right).
  ///
  /// Note: `operator` is a reserved keyword, use backticks when pattern matching.
  ///
  /// SwiftSyntax equivalent: `InfixOperatorExprSyntax` with `BinaryOperatorExprSyntax`
  case binaryOperation(
    left: Template<A>,
    `operator`: String,
    right: Template<A>
  )

  /// Member access chain (base.property).
  ///
  /// SwiftSyntax equivalent: `MemberAccessExprSyntax`
  case propertyAccess(
    base: Template<A>,
    property: String
  )

  // MARK: - Declarations

  /// Variable declaration with optional type annotation and initializer.
  ///
  /// Limitation: Rendering produces only the initializer expression.
  /// Full declaration syntax requires statement context, not expression context.
  ///
  /// SwiftSyntax equivalent: Initializer as `ExprSyntax` (not full `VariableDeclSyntax`)
  case variableDeclaration(
    name: String,
    type: String?,
    initializer: Template<A>
  )

  // MARK: - Effects

  /// Try expression wrapping an inner expression.
  ///
  /// SwiftSyntax equivalent: `TryExprSyntax`
  case tryExpression(Template<A>)

  /// Await expression wrapping an inner expression.
  ///
  /// SwiftSyntax equivalent: `AwaitExprSyntax`
  case awaitExpression(Template<A>)

  // MARK: - Generic Calls

  /// Function call with generic type arguments.
  ///
  /// Renders to: `Function<Type1, Type2>(arg1: val1, ...)`
  ///
  /// SwiftSyntax equivalent: `FunctionCallExprSyntax` with `GenericSpecializationExprSyntax`
  case genericCall(
    function: String,
    typeArguments: [String],
    arguments: [(label: String?, value: Template<A>)]
  )

  // MARK: - Collections

  /// Array literal with element expressions.
  ///
  /// SwiftSyntax equivalent: `ArrayExprSyntax` with `ArrayElementListSyntax`
  case arrayLiteral([Template<A>])

  /// Dictionary literal with key-value pairs.
  ///
  /// Empty array renders as `[:]`. Non-empty renders as `[k1: v1, k2: v2]`.
  ///
  /// SwiftSyntax equivalent: `DictionaryExprSyntax`
  case dictionaryLiteral([(key: Template<A>, value: Template<A>)])

  // MARK: - Access

  /// Subscript access expression (`base[index]`).
  ///
  /// SwiftSyntax equivalent: `SubscriptCallExprSyntax`
  case subscriptAccess(base: Template<A>, index: Template<A>)

  // MARK: - Unwrapping

  /// Force-unwrap expression (`expr!`).
  ///
  /// SwiftSyntax equivalent: `ForceUnwrapExprSyntax`
  case forceUnwrap(Template<A>)

  // MARK: - String Interpolation

  /// String interpolation literal (`"text\(expr)text"`).
  ///
  /// SwiftSyntax equivalent: `StringLiteralExprSyntax` with interpolated segments
  case stringInterpolation([StringInterpolationSegment<A>])

  // MARK: - Closure

  /// Closure expression with optional signature and body statements.
  ///
  /// When parameters is empty and returnType is nil, renders as `{ body }`.
  /// Otherwise renders as `{ (params) -> ReturnType in body }`.
  ///
  /// SwiftSyntax equivalent: `ClosureExprSyntax`
  case closure(ClosureSignature<A>)

  // MARK: - Assignment Expression

  /// Assignment expression (`lhs = rhs`) in expression position.
  ///
  /// SwiftSyntax equivalent: `InfixOperatorExprSyntax` with `AssignmentExprSyntax`
  case assignment(lhs: Template<A>, rhs: Template<A>)

  // MARK: - Functor

  /// Maps a transformation function over all variable payloads, preserving structure.
  ///
  /// This operation satisfies functor laws:
  /// - Identity: `template.map { $0 } == template`
  /// - Composition: `template.map(f).map(g) == template.map { g(f($0)) }`
  ///
  /// Only `.variable` payloads are transformed; all other cases recurse structurally.
  ///
  /// - Parameter transform: Function applied to each variable payload
  /// - Returns: New template with transformed payloads and identical structure
  public func map<B>(_ transform: (A) -> B) -> Template<B> {
    mapLiterals(transform) ?? mapVariables(transform) ?? mapControlFlow(transform) ?? mapOperations(
      transform
    ) ?? mapEffects(transform) ?? mapDeclarations(transform) ?? mapCollections(transform)
      ?? mapExtensions(transform) ?? .literal(.nil)
  }

  private func mapLiterals<B>(_ transform: (A) -> B) -> Template<B>? {
    guard case .literal(let value) = self else { return nil }
    return .literal(value)
  }

  private func mapVariables<B>(_ transform: (A) -> B) -> Template<B>? {
    guard case .variable(let name, let payload) = self else { return nil }
    return .variable(name, payload: transform(payload))
  }

  private func mapControlFlow<B>(_ transform: (A) -> B) -> Template<B>? {
    switch self {
    case .conditional(let condition, let thenBranch, let elseBranch):
      return .conditional(
        condition: condition.map(transform),
        thenBranch: thenBranch.map(transform),
        elseBranch: elseBranch.map(transform)
      )
    case .loop(let variable, let collection, let body):
      return .loop(
        variable: variable,
        collection: collection.map(transform),
        body: body.map(transform)
      )
    default:
      return nil
    }
  }

  private func mapOperations<B>(_ transform: (A) -> B) -> Template<B>? {
    switch self {
    case .functionCall(let function, let arguments):
      return .functionCall(
        function: function,
        arguments: arguments.map { (label: $0.label, value: $0.value.map(transform)) }
      )
    case .methodCall(let base, let method, let arguments):
      return .methodCall(
        base: base.map(transform),
        method: method,
        arguments: arguments.map { (label: $0.label, value: $0.value.map(transform)) }
      )
    case .binaryOperation(let left, let op, let right):
      return .binaryOperation(
        left: left.map(transform),
        operator: op,
        right: right.map(transform)
      )
    case .propertyAccess(let base, let property):
      return .propertyAccess(
        base: base.map(transform),
        property: property
      )
    case .genericCall(let function, let typeArguments, let arguments):
      return .genericCall(
        function: function,
        typeArguments: typeArguments,
        arguments: arguments.map { (label: $0.label, value: $0.value.map(transform)) }
      )
    default:
      return nil
    }
  }

  private func mapEffects<B>(_ transform: (A) -> B) -> Template<B>? {
    switch self {
    case .tryExpression(let inner):
      return .tryExpression(inner.map(transform))
    case .awaitExpression(let inner):
      return .awaitExpression(inner.map(transform))
    default:
      return nil
    }
  }

  private func mapDeclarations<B>(_ transform: (A) -> B) -> Template<B>? {
    guard case .variableDeclaration(let name, let type, let initializer) = self else { return nil }
    return .variableDeclaration(
      name: name,
      type: type,
      initializer: initializer.map(transform)
    )
  }

  private func mapCollections<B>(_ transform: (A) -> B) -> Template<B>? {
    switch self {
    case .arrayLiteral(let elements):
      return .arrayLiteral(elements.map { $0.map(transform) })
    case .dictionaryLiteral(let entries):
      return .dictionaryLiteral(entries.map { (key: $0.key.map(transform), value: $0.value.map(transform)) })
    default:
      return nil
    }
  }

  private func mapExtensions<B>(_ transform: (A) -> B) -> Template<B>? {
    switch self {
    case .subscriptAccess(let base, let index):
      return .subscriptAccess(base: base.map(transform), index: index.map(transform))
    case .forceUnwrap(let inner):
      return .forceUnwrap(inner.map(transform))
    case .stringInterpolation(let segments):
      return .stringInterpolation(segments.map { segment -> StringInterpolationSegment<B> in
        switch segment {
        case .text(let s):
          return .text(s)
        case .expression(let expr):
          return .expression(expr.map(transform))
        }
      })
    case .closure(let sig):
      return .closure(ClosureSignature<B>(
        parameters: sig.parameters,
        returnType: sig.returnType,
        body: sig.body.map { $0.map(transform) }
      ))
    case .assignment(let lhs, let rhs):
      return .assignment(lhs: lhs.map(transform), rhs: rhs.map(transform))
    default:
      return nil
    }
  }
}

// MARK: - Sendable Conformances

extension Template: Sendable where A: Sendable {}
extension StringInterpolationSegment: Sendable where A: Sendable {}
extension ClosureSignature: Sendable where A: Sendable {}
extension SwitchCase: Sendable where A: Sendable {}
extension SwitchCasePattern: Sendable where A: Sendable {}
