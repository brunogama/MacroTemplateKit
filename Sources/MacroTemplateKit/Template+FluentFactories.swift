// MARK: - Fluent Factory Methods

extension Template {

  // MARK: - Literals

  /// Creates an integer literal template.
  public static func literal(_ value: Int) -> Template<A> {
    .literal(.integer(value))
  }

  /// Creates a double literal template.
  public static func literal(_ value: Double) -> Template<A> {
    .literal(.double(value))
  }

  /// Creates a string literal template.
  public static func literal(_ value: String) -> Template<A> {
    .literal(.string(value))
  }

  /// Creates a boolean literal template.
  public static func literal(_ value: Bool) -> Template<A> {
    .literal(.boolean(value))
  }

  /// Creates a nil literal template.
  public static func nilLiteral() -> Template<A> {
    .literal(.nil)
  }

  // MARK: - Property Access

  /// Creates a property access template (base.property).
  public static func property(_ name: String, on base: Template<A>) -> Template<A> {
    .propertyAccess(base: base, property: name)
  }

  /// Creates a property access template from variable name.
  public static func property(_ name: String, on baseName: String, payload: A) -> Template<A> {
    .propertyAccess(base: .variable(baseName, payload: payload), property: name)
  }

  // MARK: - Function Calls

  /// Creates a function call template with labeled arguments.
  public static func function(
    _ name: String,
    arguments: [(label: String?, value: Template<A>)]
  ) -> Template<A> {
    .functionCall(function: name, arguments: arguments)
  }

  /// Creates a function call template with unlabeled arguments.
  public static func function(_ name: String, _ args: Template<A>...) -> Template<A> {
    .functionCall(function: name, arguments: args.map { (label: nil, value: $0) })
  }

  /// Creates a function call template using result builder.
  public static func function(
    _ name: String,
    @TemplateBuilder<A> arguments: () -> Template<A>
  ) -> Template<A> {
    let built = arguments()
    if case .arrayLiteral(let elements) = built {
      return .functionCall(function: name, arguments: elements.map { (label: nil, value: $0) })
    }
    return .functionCall(function: name, arguments: [(label: nil, value: built)])
  }

  // MARK: - Binary Operations

  /// Creates a binary operation template.
  public static func operation(
    _ left: Template<A>,
    _ op: String,
    _ right: Template<A>
  ) -> Template<A> {
    .binaryOperation(left: left, operator: op, right: right)
  }

  // MARK: - Conditionals

  /// Creates a ternary conditional template.
  public static func ternary(
    if condition: Template<A>,
    then thenBranch: Template<A>,
    else elseBranch: Template<A>
  ) -> Template<A> {
    .conditional(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
  }

  // MARK: - Effects

  /// Wraps an expression in `try`.
  public static func `try`(_ expression: Template<A>) -> Template<A> {
    .tryExpression(expression)
  }

  /// Wraps an expression in `await`.
  public static func `await`(_ expression: Template<A>) -> Template<A> {
    .awaitExpression(expression)
  }

  /// Wraps an expression in `try await`.
  public static func tryAwait(_ expression: Template<A>) -> Template<A> {
    .tryExpression(.awaitExpression(expression))
  }

  // MARK: - Generic Calls

  /// Creates a generic function call template (e.g., `SQVField<String>("name")`).
  public static func genericCall(
    _ function: String,
    typeArguments: [String],
    arguments: [(label: String?, value: Template<A>)]
  ) -> Template<A> {
    .genericCall(function: function, typeArguments: typeArguments, arguments: arguments)
  }

  // MARK: - Collections

  /// Creates an array literal template.
  public static func array(_ elements: Template<A>...) -> Template<A> {
    .arrayLiteral(elements)
  }

  /// Creates an array literal template from array.
  public static func array(_ elements: [Template<A>]) -> Template<A> {
    .arrayLiteral(elements)
  }

  /// Creates a tuple literal template.
  public static func tuple(_ elements: Template<A>...) -> Template<A> {
    .tupleLiteral(elements)
  }

  /// Creates a dictionary literal template from key-value pairs.
  ///
  /// Empty array renders as `[:]`. Non-empty renders as `[k1: v1, k2: v2]`.
  public static func dictionary(_ entries: [(key: Template<A>, value: Template<A>)]) -> Template<A>
  {
    .dictionaryLiteral(entries)
  }

  // MARK: - Subscript Access

  /// Creates a subscript access template (`base[index]`).
  public static func `subscript`(_ base: Template<A>, index: Template<A>) -> Template<A> {
    .subscriptAccess(base: base, index: index)
  }

  /// Creates a subscript call template with multiple arguments.
  public static func subscriptCall(
    _ base: Template<A>,
    arguments: [(label: String?, value: Template<A>)]
  ) -> Template<A> {
    .subscriptCall(base: base, arguments: arguments)
  }

  // MARK: - Force Unwrap

  /// Creates a force-unwrap template (`expr!`).
  public static func unwrapped(_ expr: Template<A>) -> Template<A> {
    .forceUnwrap(expr)
  }

  // MARK: - String Interpolation

  /// Creates a string interpolation template from segments.
  ///
  /// Example: `.interpolated([.text("prefix_"), .expression(.variable("name", payload: ())), .text("_suffix")])`
  public static func interpolated(_ segments: [StringInterpolationSegment<A>]) -> Template<A> {
    .stringInterpolation(segments)
  }

  // MARK: - Self Access

  /// Creates a type metatype access template (`TypeName.self`).
  public static func selfType(_ typeName: String) -> Template<A> {
    .selfAccess(typeName)
  }

  // MARK: - Closure

  /// Creates a closure template with explicit signature.
  ///
  /// When parameters is empty and returnType is nil, renders as `{ body }`.
  public static func closure(
    params: [(name: String, type: String?)] = [],
    returnType: String? = nil,
    body: [Statement<A>]
  ) -> Template<A> {
    .closure(ClosureSignature<A>(parameters: params, returnType: returnType, body: body))
  }
}
