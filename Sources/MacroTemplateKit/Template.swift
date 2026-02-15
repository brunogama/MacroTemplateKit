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

  // MARK: - Collections

  /// Array literal with element expressions.
  ///
  /// SwiftSyntax equivalent: `ArrayExprSyntax` with `ArrayElementListSyntax`
  case arrayLiteral([Template<A>])

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
    ) ?? mapDeclarations(transform) ?? mapCollections(transform) ?? .literal(.nil)
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
    guard case .arrayLiteral(let elements) = self else { return nil }
    return .arrayLiteral(elements.map { $0.map(transform) })
  }
}

// MARK: - Sendable Conformance

extension Template: Sendable where A: Sendable {}
