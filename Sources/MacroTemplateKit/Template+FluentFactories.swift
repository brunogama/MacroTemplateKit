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

  // MARK: - Collections

  /// Creates an array literal template.
  public static func array(_ elements: Template<A>...) -> Template<A> {
    .arrayLiteral(elements)
  }

  /// Creates an array literal template from array.
  public static func array(_ elements: [Template<A>]) -> Template<A> {
    .arrayLiteral(elements)
  }
}
