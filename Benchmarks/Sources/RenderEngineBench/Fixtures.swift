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
}
