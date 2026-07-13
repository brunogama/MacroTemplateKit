import MacroTemplateKit
import SwiftSyntax

/// MacroTemplateKit's template algebra, mirroring how the library is used in
/// Examples/MemberMacros/DictionaryStorageMacro+MacroTemplateKit.swift:
/// `Template`/`Statement`/`Declaration` values rendered through `Renderer`,
/// with raw SwiftSyntax only where the algebra has no case (the `as!` cast
/// and the labeled `default:` subscript argument).
struct MTKPipeline: ASTGeneratorPipeline {
    static let name = "mtk"
    static let summary = "MacroTemplateKit Template/Statement/Declaration → Renderer"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember(),
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

    // var _storage: [String: Any] = [:]
    private static func storageMember() -> DeclSyntax {
        let storageProperty = Declaration<Void>.property(
            PropertySignature(
                name: "_storage",
                type: "[String: Any]",
                isLet: false,
                initializer: .dictionaryLiteral([])
            )
        )
        return Renderer.render(storageProperty)
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
