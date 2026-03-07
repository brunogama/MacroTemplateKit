/// Type alias declaration signature.
///
/// Renders to:
/// ```swift
/// public typealias Name = ExistingType
/// ```
///
/// `TypeAliasSignature` is not generic over `A` because type alias declarations
/// contain no template expressions — they are purely type-level declarations.
/// Consequently, `Declaration.typeAlias` carries no payload-bearing content and
/// the `map` implementation re-wraps the unchanged signature.
public struct TypeAliasSignature: Equatable, Hashable, Sendable {
  /// Access level (public, internal, private, fileprivate).
  public let accessLevel: AccessLevel

  /// Declaration attributes (e.g. `@available`).
  public let attributes: [AttributeSignature]

  /// Alias name.
  public let name: String

  /// Generic parameter clause (e.g. `<T, each Element>`).
  public let genericParameters: [GenericParameterSignature]

  /// Existing type being aliased (as raw string, e.g., "UInt8", "Array<String>").
  public let existingType: String

  /// Generic `where` clause requirements.
  public let whereRequirements: [WhereRequirement]

  public init(
    accessLevel: AccessLevel = .internal,
    attributes: [AttributeSignature] = [],
    name: String,
    genericParameters: [GenericParameterSignature] = [],
    existingType: String,
    whereRequirements: [WhereRequirement] = []
  ) {
    self.accessLevel = accessLevel
    self.attributes = attributes
    self.name = name
    self.genericParameters = genericParameters
    self.existingType = existingType
    self.whereRequirements = whereRequirements
  }
}
