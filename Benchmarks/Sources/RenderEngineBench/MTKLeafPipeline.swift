import MacroTemplateKit
import SwiftSyntax

/// Deliberately naive MacroTemplateKit usage: render leaf expressions one at a
/// time and assemble the surrounding syntax by hand.
///
/// This is not a recommended pattern — `MTKPipeline` shows the idiomatic one —
/// but it is the pattern a macro author falls into when the kit cannot express
/// some part of the output, and it is the pattern the earlier version of the
/// `mtk` pipeline used. It exists as a standing regression guard: the
/// parse-backed renderer's cost is driven by *how many times* `render` is
/// called, so a change that makes per-call overhead worse shows up here first,
/// where the idiomatic pipeline would hide it.
///
/// Three renders per property, versus one for `mtk`.
struct MTKLeafPipeline: ASTGeneratorPipeline {
    static let name = "mtk-leaf"
    static let summary = "MacroTemplateKit rendered at leaf granularity (cliff regression guard)"

    init() {}

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember(),
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

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

    // get { _storage["name", default: <default>] as! <Type> }
    private static func getter(for property: StoredProperty) -> AccessorDeclSyntax {
        let subscriptWithDefault = SubscriptCallExprSyntax(
            calledExpression: Renderer.render(Template<Void>.variable("_storage")),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: Renderer.render(Template<Void>.literal(property.name)),
                    trailingComma: .commaToken()
                ),
                LabeledExprSyntax(
                    label: .identifier("default"),
                    colon: .colonToken(),
                    expression: property.defaultValue
                ),
            ])
        )
        let forceCast = AsExprSyntax(
            expression: ExprSyntax(subscriptWithDefault),
            questionOrExclamationMark: .exclamationMarkToken(),
            type: property.type
        )
        return AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(forceCast)))
                ])
            )
        )
    }

    // set { _storage["name"] = newValue }
    private static func setter(for property: StoredProperty) -> AccessorDeclSyntax {
        let assignment = Statement<Void>.assignmentStatement(
            lhs: .subscriptAccess(
                base: .variable("_storage"),
                index: .literal(.string(property.name))
            ),
            rhs: .variable("newValue")
        )
        return AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([Renderer.render(assignment)])
            )
        )
    }
}
