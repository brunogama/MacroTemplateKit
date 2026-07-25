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
