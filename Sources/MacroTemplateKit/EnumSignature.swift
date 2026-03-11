/// Enum declaration signature with cases and members.
///
/// Models all components of a Swift enum declaration for template-driven code generation.
/// Supports raw values, associated types, protocol conformances, and nested member declarations.
///
/// # Example
///
/// ```swift
/// EnumSignature(
///   accessLevel: .public,
///   name: "Status",
///   conformances: ["String", "CaseIterable"],
///   cases: [
///     EnumCaseSignature(name: "active", rawValue: "active"),
///     EnumCaseSignature(name: "inactive", rawValue: "inactive")
///   ]
/// )
/// ```
public struct EnumSignature<A>: Sendable where A: Sendable {
    /// Access level (public, internal, private, fileprivate).
    public let accessLevel: AccessLevel

    /// Declaration attributes (e.g. `@available`).
    public let attributes: [AttributeSignature]

    /// Enum name.
    public let name: String

    /// Generic parameter clause (e.g. `<T, each Element>`).
    public let genericParameters: [GenericParameterSignature]

    /// Protocol conformances.
    public let conformances: [String]

    /// Generic `where` clause requirements.
    public let whereRequirements: [WhereRequirement]

    /// Enum cases.
    public let cases: [EnumCaseSignature]

    /// Member declarations (functions, properties, etc.).
    public let members: [Declaration<A>]

    /// Creates a new enum signature.
    ///
    /// - Parameters:
    ///   - accessLevel: Swift access level modifier. Defaults to `.internal`.
    ///   - name: The enum type name.
    ///   - conformances: Protocol names the enum conforms to.
    ///   - cases: Enum case declarations.
    ///   - members: Nested member declarations (functions, properties, etc.).
    public init(
        accessLevel: AccessLevel = .internal,
        attributes: [AttributeSignature] = [],
        name: String,
        genericParameters: [GenericParameterSignature] = [],
        conformances: [String] = [],
        whereRequirements: [WhereRequirement] = [],
        cases: [EnumCaseSignature] = [],
        members: [Declaration<A>] = []
    ) {
        self.accessLevel = accessLevel
        self.attributes = attributes
        self.name = name
        self.genericParameters = genericParameters
        self.conformances = conformances
        self.whereRequirements = whereRequirements
        self.cases = cases
        self.members = members
    }
}

/// A single case in an enum declaration.
///
/// Supports plain cases, raw-value cases, and cases with associated types.
///
/// # Examples
///
/// ```swift
/// EnumCaseSignature(name: "north")                              // plain case
/// EnumCaseSignature(name: "active", rawValue: "active")        // raw value
/// EnumCaseSignature(name: "point", associatedTypes: ["Int", "Int"]) // associated types
/// ```
public struct EnumCaseSignature: Equatable, Hashable, Sendable {
    /// Case name.
    public let name: String

    /// Optional raw value as a string literal (e.g., "customKey").
    public let rawValue: String?

    /// Optional associated value type names (e.g., ["String", "Int"]).
    public let associatedTypes: [String]

    /// Creates a new enum case signature.
    ///
    /// - Parameters:
    ///   - name: The case name.
    ///   - rawValue: Optional raw value string literal.
    ///   - associatedTypes: Optional list of associated value type names.
    public init(
        name: String,
        rawValue: String? = nil,
        associatedTypes: [String] = []
    ) {
        self.name = name
        self.rawValue = rawValue
        self.associatedTypes = associatedTypes
    }
}

// MARK: - Functor

extension EnumSignature {
    /// Maps a transformation over all nested `Template<A>` payloads inside member declarations.
    ///
    /// Satisfies functor laws:
    /// - Identity: `sig.map { $0 } == sig`
    /// - Composition: `sig.map(f).map(g) == sig.map { g(f($0)) }`
    ///
    /// - Parameter transform: Transformation applied to each template payload.
    /// - Returns: New `EnumSignature<B>` with transformed member declarations.
    public func map<B>(_ transform: @escaping @Sendable (A) -> B) -> EnumSignature<B>
    where A: Sendable, B: Sendable {
        EnumSignature<B>(
            accessLevel: accessLevel,
            attributes: attributes,
            name: name,
            genericParameters: genericParameters,
            conformances: conformances,
            whereRequirements: whereRequirements,
            cases: cases,
            members: members.map { $0.map(transform) }
        )
    }
}

// MARK: - Protocol Conformances

extension EnumSignature: Equatable where A: Equatable {}

extension EnumSignature: Hashable where A: Hashable {}
