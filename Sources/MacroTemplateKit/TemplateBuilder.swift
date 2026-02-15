/// Result builder for declarative template construction.
///
/// Enables fluent DSL syntax for building templates:
/// ```swift
/// @TemplateBuilder<Void> var body: Template<Void> {
///   Template.function("request") {
///     Template.property("url", on: "base")
///     Template.literal("GET")
///   }
/// }
/// ```
@resultBuilder
public struct TemplateBuilder<A> {

  // MARK: - Single Expression

  public static func buildExpression(_ expression: Template<A>) -> Template<A> {
    expression
  }

  // MARK: - Block Building

  public static func buildBlock() -> Template<A> {
    .arrayLiteral([])
  }

  public static func buildBlock(_ component: Template<A>) -> Template<A> {
    component
  }

  public static func buildBlock(_ components: Template<A>...) -> Template<A> {
    .arrayLiteral(components)
  }

  // MARK: - Optionals

  public static func buildOptional(_ component: Template<A>?) -> Template<A> {
    component ?? .literal(.nil)
  }

  // MARK: - Conditionals

  public static func buildEither(first component: Template<A>) -> Template<A> {
    component
  }

  public static func buildEither(second component: Template<A>) -> Template<A> {
    component
  }

  // MARK: - Arrays

  public static func buildArray(_ components: [Template<A>]) -> Template<A> {
    .arrayLiteral(components)
  }

  // MARK: - Limited Availability

  public static func buildLimitedAvailability(_ component: Template<A>) -> Template<A> {
    component
  }
}
