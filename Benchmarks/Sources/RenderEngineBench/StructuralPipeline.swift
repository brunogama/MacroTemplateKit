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
                    trailingComma: .commaToken(trailingTrivia: .space)
                ),
                LabeledExprSyntax(
                    label: .identifier("default"),
                    colon: .colonToken(trailingTrivia: .space),
                    expression: property.defaultValue
                ),
            ])
        )
        let forceCast = AsExprSyntax(
            expression: ExprSyntax(subscriptWithDefault),
            asKeyword: .keyword(.as, leadingTrivia: .space),
            questionOrExclamationMark: .exclamationMarkToken(trailingTrivia: .space),
            // `.trimmed`: the type node comes from the parsed fixture and
            // carries its trailing space, which `mtk` does not emit.
            type: property.type.trimmed
        )
        return AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get, trailingTrivia: .space),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(trailingTrivia: .newline),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(forceCast)))
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
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
                ExprSyntax(AssignmentExprSyntax(
                    leadingTrivia: .space, trailingTrivia: .space)),
                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue"))),
            ])
        )
        return AccessorDeclSyntax(
            accessorSpecifier: .keyword(.set, trailingTrivia: .space),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(trailingTrivia: .newline),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(assignment)))
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }
}
