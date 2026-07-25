import MacroTemplateKit
import SwiftSyntax

/// A switchable strategy for the case-factory workload.
///
/// Given an enum's cases, produce one static factory per case:
///
///     static func makeCase0(_ value: String) -> Fixture { Fixture.case0(value) }
///
/// This is deliberately a different shape from the generate workload. That one
/// builds accessor *bodies* hanging off stored properties; this one builds
/// whole *declarations with signatures* — modifiers, parameter clauses, return
/// types — which is the shape enum-driven macros (case paths, action builders)
/// actually generate. Results from one workload must not be quoted for the
/// other.
protocol CaseFactoryPipeline {
    static var name: String { get }
    static var summary: String { get }

    init()
    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax]
}

/// Raw SwiftSyntax initializers — the hand-rolled baseline.
struct StructuralCaseFactoryPipeline: CaseFactoryPipeline {
    static let name = "structural"
    static let summary = "Raw SwiftSyntax initializers"

    init() {}

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        cases.map { enumCase in
            let parameter = FunctionParameterSyntax(
                firstName: .wildcardToken(),
                secondName: .identifier("value"),
                colon: .colonToken(),
                type: enumCase.payloadType
            )
            let call = FunctionCallExprSyntax(
                calledExpression: ExprSyntax(
                    MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier(enumName)),
                        name: .identifier(enumCase.name)
                    )
                ),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(
                        expression: DeclReferenceExprSyntax(baseName: .identifier("value")))
                ]),
                rightParen: .rightParenToken()
            )
            let function = FunctionDeclSyntax(
                modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.static))]),
                name: .identifier("make\(enumCase.name.capitalizedFirst)"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        parameters: FunctionParameterListSyntax([parameter])
                    ),
                    returnClause: ReturnClauseSyntax(
                        type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(enumName)))
                    )
                ),
                body: CodeBlockSyntax(
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(item: .expr(ExprSyntax(call)))
                    ])
                )
            )
            return DeclSyntax(function)
        }
    }
}

/// The same hand-rolled construction with every expansion-invariant node
/// hoisted out of the per-case loop.
///
/// This is the honest baseline for the workload. `StructuralCaseFactoryPipeline`
/// rebuilds the static modifier, both parens, the wildcard and colon tokens,
/// the argument list and the return type once per case, none of which vary
/// across cases — a macro author writing this by hand would not. Comparing
/// against the unhoisted version credits the library for a mistake the
/// baseline made rather than for anything the library does.
struct InternedStructuralCaseFactoryPipeline: CaseFactoryPipeline {
    static let name = "structural-interned"
    static let summary = "Hand-rolled SwiftSyntax with invariant nodes hoisted out of the loop"

    init() {}

    private enum Interned {
        static let staticModifier = DeclModifierListSyntax([
            DeclModifierSyntax(name: .keyword(.static))
        ])
        static let wildcard = TokenSyntax.wildcardToken()
        static let valueName = TokenSyntax.identifier("value")
        static let colon = TokenSyntax.colonToken()
        static let leftParen = TokenSyntax.leftParenToken()
        static let rightParen = TokenSyntax.rightParenToken()
        /// The call's argument list is `(value)` for every case.
        static let arguments = LabeledExprListSyntax([
            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("value")))
        ])
    }

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        // Invariant across cases but not across calls, so hoisted to here
        // rather than into `Interned`.
        let enumRef = DeclReferenceExprSyntax(baseName: .identifier(enumName))
        let returnClause = ReturnClauseSyntax(
            type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(enumName)))
        )

        return cases.map { enumCase in
            let parameter = FunctionParameterSyntax(
                firstName: Interned.wildcard,
                secondName: Interned.valueName,
                colon: Interned.colon,
                type: enumCase.payloadType
            )
            let call = FunctionCallExprSyntax(
                calledExpression: ExprSyntax(
                    MemberAccessExprSyntax(base: enumRef, name: .identifier(enumCase.name))
                ),
                leftParen: Interned.leftParen,
                arguments: Interned.arguments,
                rightParen: Interned.rightParen
            )
            let function = FunctionDeclSyntax(
                modifiers: Interned.staticModifier,
                name: .identifier("make\(enumCase.name.capitalizedFirst)"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        parameters: FunctionParameterListSyntax([parameter])
                    ),
                    returnClause: returnClause
                ),
                body: CodeBlockSyntax(
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(item: .expr(ExprSyntax(call)))
                    ])
                )
            )
            return DeclSyntax(function)
        }
    }
}

/// MacroTemplateKit values, one render per generated declaration.
struct MTKCaseFactoryPipeline: CaseFactoryPipeline {
    static let name = "mtk"
    static let summary = "MacroTemplateKit templates, one render per declaration"

    init() {}

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        cases.map { enumCase in
            let construction = Template<Void>.methodCall(
                base: .variable(enumName),
                method: enumCase.name,
                arguments: [(label: nil, value: .variable("value"))]
            )
            let function = Declaration<Void>.function(
                FunctionSignature(
                    isStatic: true,
                    name: "make\(enumCase.name.capitalizedFirst)",
                    parameters: [
                        ParameterSignature(
                            label: "_", name: "value",
                            type: enumCase.payloadType.trimmedDescription)
                    ],
                    returnType: enumName,
                    body: [.expression(construction)]
                )
            )
            return try! Renderer.render(function)
        }
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
