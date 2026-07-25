import MacroTemplateKit
import SwiftSyntax

/// The TCA-shaped workload: `@CasePathable`'s per-case expansion.
///
/// For every enum case, CasePaths-style macros generate a computed
/// `AnyCasePath` property carrying two closures:
///
///     public var case0: AnyCasePath<Fixture, String> {
///       get {
///         AnyCasePath(
///           embed: { Fixture.case0($0) },
///           extract: {
///             guard case let .case0(value) = $0 else { return nil }
///             return value
///           }
///         )
///       }
///     }
///
/// A TCA app pays this expansion for every case of every `@CasePathable`
/// action enum, which is where "framework that uses tons of macros" actually
/// spends its macro budget. The shape is deliberately nastier than
/// case-factory: closures as labeled arguments, a guard-case matching
/// pattern, and a generic return type. It is also *more* invariant-heavy —
/// the `else { return nil }` block, the `= $0` initializer, and the
/// `return value` statement never vary across cases — so the hoisted
/// baseline gets its best possible showing here, per ADR 0004.
///
/// All three pipelines implement `CaseFactoryPipeline`; only the registry
/// and workload name differ.

/// Raw SwiftSyntax initializers, rebuilding everything per case.
struct StructuralCasePathPipeline: CaseFactoryPipeline {
    static let name = "structural"
    static let summary = "Raw SwiftSyntax initializers"

    init() {}

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        cases.map { enumCase in
            // { Fixture.case0($0) }
            let embed = ClosureExprSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        item: .expr(
                            ExprSyntax(
                                FunctionCallExprSyntax(
                                    calledExpression: ExprSyntax(
                                        MemberAccessExprSyntax(
                                            base: DeclReferenceExprSyntax(
                                                baseName: .identifier(enumName)),
                                            name: .identifier(enumCase.name)
                                        )
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax([
                                        LabeledExprSyntax(
                                            expression: DeclReferenceExprSyntax(
                                                baseName: .dollarIdentifier("$0")))
                                    ]),
                                    rightParen: .rightParenToken()
                                ))))
                ])
            )

            // guard case let .case0(value) = $0 else { return nil }
            let matchPattern = ExpressionPatternSyntax(
                expression: FunctionCallExprSyntax(
                    calledExpression: ExprSyntax(
                        MemberAccessExprSyntax(name: .identifier(enumCase.name))
                    ),
                    leftParen: .leftParenToken(),
                    arguments: LabeledExprListSyntax([
                        LabeledExprSyntax(
                            expression: DeclReferenceExprSyntax(baseName: .identifier("value")))
                    ]),
                    rightParen: .rightParenToken()
                )
            )
            let guardStatement = GuardStmtSyntax(
                conditions: ConditionElementListSyntax([
                    ConditionElementSyntax(
                        condition: .matchingPattern(
                            MatchingPatternConditionSyntax(
                                pattern: ValueBindingPatternSyntax(
                                    bindingSpecifier: .keyword(.let),
                                    pattern: PatternSyntax(matchPattern)
                                ),
                                initializer: InitializerClauseSyntax(
                                    value: DeclReferenceExprSyntax(
                                        baseName: .dollarIdentifier("$0")))
                            )))
                ]),
                body: CodeBlockSyntax(
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            item: .stmt(
                                StmtSyntax(
                                    ReturnStmtSyntax(
                                        expression: ExprSyntax(NilLiteralExprSyntax())))))
                    ])
                )
            )
            let extract = ClosureExprSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .stmt(StmtSyntax(guardStatement))),
                    CodeBlockItemSyntax(
                        item: .stmt(
                            StmtSyntax(
                                ReturnStmtSyntax(
                                    expression: ExprSyntax(
                                        DeclReferenceExprSyntax(
                                            baseName: .identifier("value"))))))),
                ])
            )

            // AnyCasePath(embed: ..., extract: ...)
            let casePathCall = FunctionCallExprSyntax(
                calledExpression: ExprSyntax(
                    DeclReferenceExprSyntax(baseName: .identifier("AnyCasePath"))),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(
                        label: .identifier("embed"),
                        colon: .colonToken(),
                        expression: embed,
                        trailingComma: .commaToken()
                    ),
                    LabeledExprSyntax(
                        label: .identifier("extract"),
                        colon: .colonToken(),
                        expression: extract
                    ),
                ]),
                rightParen: .rightParenToken()
            )

            // public var case0: AnyCasePath<Fixture, String> { get { ... } }
            let returnType = IdentifierTypeSyntax(
                name: .identifier("AnyCasePath"),
                genericArgumentClause: GenericArgumentClauseSyntax(
                    arguments: GenericArgumentListSyntax([
                        GenericArgumentSyntax(
                            argument: .type(
                                TypeSyntax(IdentifierTypeSyntax(name: .identifier(enumName)))),
                            trailingComma: .commaToken()
                        ),
                        GenericArgumentSyntax(argument: .type(enumCase.payloadType)),
                    ])
                )
            )
            let property = VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.public))
                ]),
                bindingSpecifier: .keyword(.var),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(
                            identifier: .identifier(enumCase.name)),
                        typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(returnType)),
                        accessorBlock: AccessorBlockSyntax(
                            accessors: .accessors(
                                AccessorDeclListSyntax([
                                    AccessorDeclSyntax(
                                        accessorSpecifier: .keyword(.get),
                                        body: CodeBlockSyntax(
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    item: .expr(ExprSyntax(casePathCall)))
                                            ]))
                                    )
                                ]))
                        )
                    )
                ])
            )
            return DeclSyntax(property)
        }
    }
}

/// The same construction with every case-invariant node hoisted. This shape
/// rewards hoisting unusually well: entire subtrees — the else block, the
/// `= $0` initializer, the trailing `return value` — are identical for
/// every case.
struct InternedStructuralCasePathPipeline: CaseFactoryPipeline {
    static let name = "structural-interned"
    static let summary = "Hand-rolled SwiftSyntax with invariant nodes hoisted out of the loop"

    init() {}

    private enum Interned {
        static let publicModifier = DeclModifierListSyntax([
            DeclModifierSyntax(name: .keyword(.public))
        ])
        static let varKeyword = TokenSyntax.keyword(.var)
        static let getKeyword = TokenSyntax.keyword(.get)
        static let letKeyword = TokenSyntax.keyword(.let)
        static let leftParen = TokenSyntax.leftParenToken()
        static let rightParen = TokenSyntax.rightParenToken()
        static let comma = TokenSyntax.commaToken()
        static let colon = TokenSyntax.colonToken()
        static let embedLabel = TokenSyntax.identifier("embed")
        static let extractLabel = TokenSyntax.identifier("extract")
        static let casePathRef = ExprSyntax(
            DeclReferenceExprSyntax(baseName: .identifier("AnyCasePath")))
        static let dollarZero = ExprSyntax(
            DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")))
        /// `(value)` — the match pattern's argument list.
        static let valueArguments = LabeledExprListSyntax([
            LabeledExprSyntax(
                expression: DeclReferenceExprSyntax(baseName: .identifier("value")))
        ])
        /// `($0)` — the embed call's argument list.
        static let dollarArguments = LabeledExprListSyntax([
            LabeledExprSyntax(
                expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")))
        ])
        /// `= $0` — invariant for every case.
        static let dollarInitializer = InitializerClauseSyntax(
            value: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0")))
        /// `{ return nil }` — the entire guard else block.
        static let returnNilBlock = CodeBlockSyntax(
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(
                    item: .stmt(
                        StmtSyntax(ReturnStmtSyntax(expression: ExprSyntax(NilLiteralExprSyntax())))))
            ])
        )
        /// `return value` — the extract closure's trailing statement.
        static let returnValueItem = CodeBlockItemSyntax(
            item: .stmt(
                StmtSyntax(
                    ReturnStmtSyntax(
                        expression: ExprSyntax(
                            DeclReferenceExprSyntax(baseName: .identifier("value")))))))
    }

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        // Invariant across cases but not across calls.
        let enumRef = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(enumName)))
        let enumTypeArgument = GenericArgumentSyntax(
            argument: .type(TypeSyntax(IdentifierTypeSyntax(name: .identifier(enumName)))),
            trailingComma: Interned.comma
        )

        return cases.map { enumCase in
            let embed = ClosureExprSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        item: .expr(
                            ExprSyntax(
                                FunctionCallExprSyntax(
                                    calledExpression: ExprSyntax(
                                        MemberAccessExprSyntax(
                                            base: enumRef, name: .identifier(enumCase.name))),
                                    leftParen: Interned.leftParen,
                                    arguments: Interned.dollarArguments,
                                    rightParen: Interned.rightParen
                                ))))
                ])
            )

            let matchPattern = ExpressionPatternSyntax(
                expression: FunctionCallExprSyntax(
                    calledExpression: ExprSyntax(
                        MemberAccessExprSyntax(name: .identifier(enumCase.name))),
                    leftParen: Interned.leftParen,
                    arguments: Interned.valueArguments,
                    rightParen: Interned.rightParen
                )
            )
            let guardStatement = GuardStmtSyntax(
                conditions: ConditionElementListSyntax([
                    ConditionElementSyntax(
                        condition: .matchingPattern(
                            MatchingPatternConditionSyntax(
                                pattern: ValueBindingPatternSyntax(
                                    bindingSpecifier: Interned.letKeyword,
                                    pattern: PatternSyntax(matchPattern)
                                ),
                                initializer: Interned.dollarInitializer
                            )))
                ]),
                body: Interned.returnNilBlock
            )
            let extract = ClosureExprSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .stmt(StmtSyntax(guardStatement))),
                    Interned.returnValueItem,
                ])
            )

            let casePathCall = FunctionCallExprSyntax(
                calledExpression: Interned.casePathRef,
                leftParen: Interned.leftParen,
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(
                        label: Interned.embedLabel,
                        colon: Interned.colon,
                        expression: embed,
                        trailingComma: Interned.comma
                    ),
                    LabeledExprSyntax(
                        label: Interned.extractLabel,
                        colon: Interned.colon,
                        expression: extract
                    ),
                ]),
                rightParen: Interned.rightParen
            )

            let returnType = IdentifierTypeSyntax(
                name: .identifier("AnyCasePath"),
                genericArgumentClause: GenericArgumentClauseSyntax(
                    arguments: GenericArgumentListSyntax([
                        enumTypeArgument,
                        GenericArgumentSyntax(argument: .type(enumCase.payloadType)),
                    ])
                )
            )
            let property = VariableDeclSyntax(
                modifiers: Interned.publicModifier,
                bindingSpecifier: Interned.varKeyword,
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(
                            identifier: .identifier(enumCase.name)),
                        typeAnnotation: TypeAnnotationSyntax(type: TypeSyntax(returnType)),
                        accessorBlock: AccessorBlockSyntax(
                            accessors: .accessors(
                                AccessorDeclListSyntax([
                                    AccessorDeclSyntax(
                                        accessorSpecifier: Interned.getKeyword,
                                        body: CodeBlockSyntax(
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    item: .expr(ExprSyntax(casePathCall)))
                                            ]))
                                    )
                                ]))
                        )
                    )
                ])
            )
            return DeclSyntax(property)
        }
    }
}

/// MacroTemplateKit values, one render per generated declaration.
///
/// The guard-case matching pattern has no typed representation in `Statement`,
/// so it rides through `.variable`'s raw-source escape hatch — the same route
/// `AddAsyncMacro` uses for patterns. That is honest idiomatic usage today,
/// and it is also a measurement of the escape hatch's cost: the pattern text
/// is interpolated per case and parsed as part of the fragment.
struct MTKCasePathPipeline: CaseFactoryPipeline {
    static let name = "mtk"
    static let summary = "MacroTemplateKit templates, one render per declaration"

    init() {}

    func expand(cases: [EnumCaseInfo], enumName: String) -> [DeclSyntax] {
        cases.map { enumCase in
            let embed = Template<Void>.closure(body: [
                .expression(
                    .methodCall(
                        base: .variable(enumName),
                        method: enumCase.name,
                        arguments: [(label: nil, value: .variable("$0"))]
                    ))
            ])
            let extract = Template<Void>.closure(body: [
                .guardStatement(
                    condition: .variable("case let .\(enumCase.name)(value) = $0"),
                    elseBody: [.returnStatement(.literal(.nil))]
                ),
                .returnStatement(.variable("value")),
            ])
            let property = Declaration<Void>.computedProperty(
                ComputedPropertySignature(
                    accessLevel: .public,
                    name: enumCase.name,
                    type: "AnyCasePath<\(enumName), \(enumCase.payloadType.trimmedDescription)>",
                    getter: [
                        .expression(
                            .functionCall(
                                function: "AnyCasePath",
                                arguments: [
                                    (label: "embed", value: embed),
                                    (label: "extract", value: extract),
                                ]
                            ))
                    ]
                )
            )
            return try! Renderer.render(property)
        }
    }
}
