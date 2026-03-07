/// Typed function or method call argument.
public struct TemplateArgument<A> {
  public let label: String?
  public let value: Template<A>

  public init(label: String? = nil, value: Template<A>) {
    self.label = label
    self.value = value
  }

  public static func labeled(_ label: String, _ value: Template<A>) -> Self {
    .init(label: label, value: value)
  }

  public static func unlabeled(_ value: Template<A>) -> Self {
    .init(value: value)
  }
}

extension TemplateArgument: Equatable where A: Equatable {}

extension TemplateArgument: Hashable where A: Hashable {}

extension TemplateArgument: Sendable where A: Sendable {}

@resultBuilder
public struct TemplateArgumentBuilder<A> {
  public static func buildExpression(_ expression: TemplateArgument<A>) -> [TemplateArgument<A>] {
    [expression]
  }

  public static func buildExpression(_ expression: Template<A>) -> [TemplateArgument<A>] {
    [.unlabeled(expression)]
  }

  public static func buildExpression(
    _ expression: (label: String?, value: Template<A>)
  ) -> [TemplateArgument<A>] {
    [TemplateArgument(label: expression.label, value: expression.value)]
  }

  public static func buildBlock(_ components: [TemplateArgument<A>]...) -> [TemplateArgument<A>] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ component: [TemplateArgument<A>]?) -> [TemplateArgument<A>] {
    component ?? []
  }

  public static func buildEither(first component: [TemplateArgument<A>]) -> [TemplateArgument<A>] {
    component
  }

  public static func buildEither(second component: [TemplateArgument<A>]) -> [TemplateArgument<A>] {
    component
  }

  public static func buildArray(_ components: [[TemplateArgument<A>]]) -> [TemplateArgument<A>] {
    components.flatMap { $0 }
  }

  public static func buildLimitedAvailability(
    _ component: [TemplateArgument<A>]
  ) -> [TemplateArgument<A>] {
    component
  }
}
