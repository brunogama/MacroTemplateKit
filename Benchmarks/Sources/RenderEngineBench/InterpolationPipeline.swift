import SwiftSyntax
import SwiftSyntaxBuilder

/// The research's technique #5: build each new fragment with ONE
/// string-interpolation parse. Existing nodes (`type`, `defaultValue`) are
/// spliced structurally by the interpolation — they are not re-serialized.
struct InterpolationPipeline: ASTGeneratorPipeline {
    static let name = "interpolation"
    static let summary = "SwiftSyntaxBuilder string interpolation; one parse per fragment, structural splicing"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: "var _storage: [String: Any] = [:]",
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

    private static func getter(for property: StoredProperty) -> AccessorDeclSyntax {
        """
        get {
          _storage[\(literal: property.name), default: \(property.defaultValue)] as! \(property.type)
        }
        """
    }

    private static func setter(for property: StoredProperty) -> AccessorDeclSyntax {
        """
        set {
          _storage[\(literal: property.name)] = newValue
        }
        """
    }
}
