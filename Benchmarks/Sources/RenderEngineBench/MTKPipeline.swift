import MacroTemplateKit
import SwiftSyntax

/// Builds the expansion out of MacroTemplateKit values.
///
/// Each computed property is expressed as a single `Declaration` and rendered
/// in **one** call; its accessors are then read back out. Because they come
/// from one parse they share a single syntax arena, which is what keeps
/// retained memory down — the renderer's cost is dominated by the *number* of
/// render calls, not by total output size.
///
/// An earlier version of this pipeline rendered leaf expressions one at a time
/// and assembled the surrounding accessors with handwritten SwiftSyntax, at
/// three renders per property. That was not a style choice: until
/// `Template.cast` and the bare `set { }` form existed, the kit could not
/// express `_storage["name", default: x] as! Type` at all. Both gaps are now
/// closed, so the pipeline measures idiomatic usage rather than a workaround.
struct MTKPipeline: ASTGeneratorPipeline {
    static let name = "mtk"
    static let summary = "MacroTemplateKit templates, one render per whole computed property"

    init() {}

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember(),
            accessors: properties.flatMap(Self.accessors(for:))
        )
    }

    // var _storage: [String: Any] = [:]
    private static func storageMember() -> DeclSyntax {
        Renderer.render(
            Declaration<Void>.property(
                PropertySignature(
                    name: "_storage",
                    type: "[String: Any]",
                    isLet: false,
                    initializer: .dictionaryLiteral([])
                )
            )
        )
    }

    /// Renders `var name: Type { get { ... } set { ... } }` in a single call and
    /// returns its two accessors.
    private static func accessors(for property: StoredProperty) -> [AccessorDeclSyntax] {
        let typeName = property.type.trimmedDescription

        // _storage["name", default: <default>] as! Type
        let storageLookup = Template<Void>.cast(
            .subscriptCall(
                base: .variable("_storage"),
                arguments: [
                    (label: nil, value: .literal(.string(property.name))),
                    // The fixture hands us the default as an ExprSyntax, and the
                    // kit has no verbatim/raw-expression case — `.variable` is
                    // the only way to splice existing source text into a
                    // template, since it emits its name unchanged.
                    (label: "default", value: .variable(property.defaultValue.trimmedDescription)),
                ]
            ),
            type: typeName,
            kind: .forced
        )

        // _storage["name"] = newValue
        let assignment = Statement<Void>.assignmentStatement(
            lhs: .subscriptAccess(
                base: .variable("_storage"),
                index: .literal(.string(property.name))
            ),
            rhs: .variable("newValue")
        )

        let declaration = Declaration<Void>.computedProperty(
            ComputedPropertySignature(
                name: property.name,
                type: typeName,
                getter: [.expression(storageLookup)],
                setter: SetterSignature(body: [assignment])
            )
        )

        let rendered = Renderer.render(declaration)
        guard
            let variable = rendered.as(VariableDeclSyntax.self),
            let accessorBlock = variable.bindings.first?.accessorBlock,
            case .accessors(let list) = accessorBlock.accessors
        else {
            fatalError("mtk: rendered declaration was not a computed property")
        }
        return Array(list)
    }
}
