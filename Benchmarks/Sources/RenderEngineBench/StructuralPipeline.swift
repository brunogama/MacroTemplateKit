import SwiftSyntax

/// Baseline: raw SwiftSyntax node initializers end-to-end. No parser is
/// invoked at any point; every node is built structurally.
struct StructuralPipeline: ASTGeneratorPipeline {
    static let name = "structural"
    static let summary = "Raw SwiftSyntax node initializers; zero parser invocations"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember(),
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

    // var _storage: [String: Any] = [:]
    private static func storageMember() -> DeclSyntax {
        DeclSyntax(storageVariableDecl())
    }

    // get { _storage["name", default: <default>] as! <Type> }
    static func getter(for property: StoredProperty) -> AccessorDeclSyntax {
        let subscriptWithDefault = SubscriptCallExprSyntax(
            calledExpression: ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier("_storage"))
            ),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: ExprSyntax(StringLiteralExprSyntax(content: property.name)),
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
    static func setter(for property: StoredProperty) -> AccessorDeclSyntax {
        let storageSubscript = SubscriptCallExprSyntax(
            calledExpression: ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier("_storage"))
            ),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: ExprSyntax(StringLiteralExprSyntax(content: property.name))
                )
            ])
        )
        let assignment = SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(storageSubscript),
                ExprSyntax(AssignmentExprSyntax()),
                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue"))),
            ])
        )
        return AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(assignment)))
                ])
            )
        )
    }
}
