/// Generic parameter signature for declarations.
public struct GenericParameterSignature: Equatable, Hashable, Sendable {
    public let name: String
    public let isParameterPack: Bool
    public let constraint: String?

    public init(
        name: String,
        isParameterPack: Bool = false,
        constraint: String? = nil
    ) {
        self.name = name
        self.isParameterPack = isParameterPack
        self.constraint = constraint
    }
}

/// Typed attribute model for common `@...` syntax on declarations, parameters, and closures.
public struct AttributeSignature: Equatable, Hashable, Sendable {
    public enum Arguments: Equatable, Hashable, Sendable {
        case argumentList([Argument])
        case availability([AvailabilityArgument])
        /// Raw argument text for attribute argument kinds not modeled explicitly
        /// (e.g. `@objc(selector:)`, `@_specialize(...)`, `@backDeployed(...)`).
        case raw(String)
    }

    public struct Argument: Equatable, Hashable, Sendable {
        public let label: String?
        public let value: String

        public init(label: String? = nil, value: String) {
            self.label = label
            self.value = value
        }

        public static func labeled(_ label: String, _ value: String) -> Self {
            .init(label: label, value: value)
        }

        public static func unlabeled(_ value: String) -> Self {
            .init(value: value)
        }
    }

    public enum AvailabilityArgument: Equatable, Hashable, Sendable {
        case token(String)
        case platform(String, version: String? = nil)
        case labeled(String, AvailabilityValue)
    }

    public enum AvailabilityValue: Equatable, Hashable, Sendable {
        case string(String)
        case version(String)
    }

    public let name: String
    public let arguments: Arguments?

    public init(name: String, arguments: Arguments? = nil) {
        self.name = name
        self.arguments = arguments
    }

    public init(_ name: String) {
        self.init(name: name)
    }

    public static var escaping: Self { .init("escaping") }
    public static var sendable: Self { .init("Sendable") }
    public static var mainActor: Self { .init("MainActor") }

    public static func available(_ arguments: [AvailabilityArgument]) -> Self {
        .init(name: "available", arguments: .availability(arguments))
    }

    public static func arguments(_ name: String, _ arguments: [Argument]) -> Self {
        .init(name: name, arguments: .argumentList(arguments))
    }
}

/// Generic `where` clause requirement.
public struct WhereRequirement: Equatable, Hashable, Sendable {
    public enum Relation: Equatable, Hashable, Sendable {
        case conformance
        case sameType
    }

    public let leftType: String
    public let relation: Relation
    public let rightType: String

    /// Compatibility alias for existing API consumers.
    public var typeParameter: String { leftType }

    /// Compatibility alias for existing API consumers.
    public var constraint: String { rightType }

    public init(typeParameter: String, constraint: String) {
        self.leftType = typeParameter
        self.relation = .conformance
        self.rightType = constraint
    }

    public init(leftType: String, relation: Relation, rightType: String) {
        self.leftType = leftType
        self.relation = relation
        self.rightType = rightType
    }

    public static func conformance(_ leftType: String, _ rightType: String) -> Self {
        .init(leftType: leftType, relation: .conformance, rightType: rightType)
    }

    public static func sameType(_ leftType: String, _ rightType: String) -> Self {
        .init(leftType: leftType, relation: .sameType, rightType: rightType)
    }
}
