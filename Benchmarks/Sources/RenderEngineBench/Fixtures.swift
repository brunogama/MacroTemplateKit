import SwiftParser
import SwiftSyntax

/// Generates a realistic annotated-struct fixture with `count` stored
/// properties of varied types and initializers, parses it once, and returns
/// the struct node. Parsing happens outside the timed region because a macro
/// receives an already-parsed tree from the compiler.
enum Fixtures {
    private static let variants: [(type: String, value: String)] = [
        ("String", "\"default value\""),
        ("Int", "42"),
        ("Double", "1.5"),
        ("Bool", "true"),
        ("[String]", "[\"a\", \"b\", \"c\"]"),
        ("[String: Int]", "[\"key\": 1]"),
    ]

    static func structDecl(propertyCount: Int) -> StructDeclSyntax {
        var lines: [String] = ["struct Fixture\(propertyCount) {"]
        for index in 0..<propertyCount {
            let variant = variants[index % variants.count]
            lines.append("    var property\(index): \(variant.type) = \(variant.value)")
        }
        lines.append("}")
        let source = lines.joined(separator: "\n")

        let file = Parser.parse(source: source)
        guard
            let item = file.statements.first,
            let structDecl = item.item.as(StructDeclSyntax.self)
        else {
            fatalError("fixture generation produced an unparsable struct")
        }
        return structDecl
    }

    /// Generates an enum with `count` single-payload cases.
    ///
    /// A second fixture shape exists because every number in the generate
    /// workload comes from one macro shape — accessor pairs over stored
    /// properties. Enum-driven macros (case paths, action builders) generate
    /// *declarations with signatures* rather than accessor bodies, which
    /// exercises a different part of the renderer.
    static func enumDecl(caseCount: Int) -> EnumDeclSyntax {
        var lines: [String] = ["enum Fixture\(caseCount) {"]
        for index in 0..<caseCount {
            let variant = variants[index % variants.count]
            lines.append("    case case\(index)(\(variant.type))")
        }
        lines.append("}")
        let source = lines.joined(separator: "\n")

        let file = Parser.parse(source: source)
        guard
            let item = file.statements.first,
            let enumDecl = item.item.as(EnumDeclSyntax.self)
        else {
            fatalError("fixture generation produced an unparsable enum")
        }
        return enumDecl
    }
}

/// One enum case with a single associated value.
struct EnumCaseInfo {
    let name: String
    /// Carried as a node, not a string: a macro receives types already parsed.
    /// The structural pipeline uses it directly; MacroTemplateKit models types
    /// as source text, so its pipeline pays a `trimmedDescription` to convert.
    let payloadType: TypeSyntax
}

/// Extracts single-payload cases from an enum fixture. Runs inside the timed
/// region for the same reason `extractStoredProperties` does.
func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCaseInfo] {
    enumDecl.memberBlock.members.compactMap { member -> EnumCaseInfo? in
        guard
            let caseDecl = member.decl.as(EnumCaseDeclSyntax.self),
            let element = caseDecl.elements.first,
            let parameter = element.parameterClause?.parameters.first
        else {
            return nil
        }
        return EnumCaseInfo(
            name: element.name.text,
            payloadType: parameter.type
        )
    }
}
