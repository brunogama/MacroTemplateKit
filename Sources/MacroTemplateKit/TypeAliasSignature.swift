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

  /// Alias name.
  public let name: String

  /// Existing type being aliased (as raw string, e.g., "UInt8", "Array<String>").
  public let existingType: String

  public init(
    accessLevel: AccessLevel = .internal,
    name: String,
    existingType: String
  ) {
    self.accessLevel = accessLevel
    self.name = name
    self.existingType = existingType
  }
}
