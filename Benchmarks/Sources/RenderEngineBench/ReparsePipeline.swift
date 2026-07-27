import SwiftSyntax
import SwiftSyntaxBuilder

/// Negative control for the research's bottleneck #6: every splice of an
/// existing node round-trips through `description` (full source string with
/// trivia) and the whole fragment is re-lexed/re-parsed from a plain string.
/// This is the anti-pattern the report says to avoid; it exists here so the
/// benchmark can measure exactly how much it costs relative to structural
/// splicing on the same output.
struct ReparsePipeline: ASTGeneratorPipeline {
    static let name = "reparse"
    static let summary = "Anti-pattern control: serialize nodes to strings, re-parse every fragment"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: DeclSyntax("var _storage: [String: Any] = [:]"),
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

    private static func getter(for property: StoredProperty) -> AccessorDeclSyntax {
        let source = """
            get {
              _storage["\(property.name)", default: \(property.defaultValue.trimmedDescription)] as! \(property.type.trimmedDescription)
            }
            """
        return AccessorDeclSyntax("\(raw: source)")
    }

    private static func setter(for property: StoredProperty) -> AccessorDeclSyntax {
        let source = """
            set {
              _storage["\(property.name)"] = newValue
            }
            """
        return AccessorDeclSyntax("\(raw: source)")
    }
}
