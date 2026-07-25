import SwiftSyntax
import SwiftSyntaxBuilder

/// Declaration-level rendering utilities.
///
/// Provides pure functions to transform `Declaration<A>` templates into SwiftSyntax
/// declaration nodes (`DeclSyntax`). Declaration rendering is the top-level transformation
/// layer for complete Swift declarations (functions, properties, extensions, structs).
extension Renderer {
    // MARK: - Declaration Rendering

    /// Renders a Declaration to SwiftSyntax DeclSyntax.
    ///
    /// Converts declaration-level templates to complete Swift declarations. The rendering process:
    /// - Translates each Declaration case to corresponding SwiftSyntax declaration node
    /// - Handles functions, properties, computed properties, extensions, and structs
    /// - Recursively renders statement bodies and nested declarations
    ///
    /// Implemented via the source-emit-then-parse pipeline (`renderParsed(_:)`
    /// below). The per-node structural implementation this superseded is
    /// retained as `legacyRender(_:)` for token-parity testing.
    ///
    /// - Parameter declaration: Declaration to render
    /// - Returns: SwiftSyntax declaration node
    public static func render<A: Sendable>(_ declaration: Declaration<A>) throws -> DeclSyntax {
        try renderParsed(declaration)
    }

    /// Legacy per-node structural implementation that `render(_: Declaration<A>)`
    /// used before the source-emit-then-parse pipeline replaced it, retained
    /// side-by-side for token-parity testing. Not reachable from the public
    /// API; scheduled for removal once the parity suite is retired.
    static func legacyRender<A: Sendable>(_ declaration: Declaration<A>) -> DeclSyntax {
        switch declaration {
        case .function(let sig):
            return DeclSyntax(renderFunction(sig))

        case .property(let sig):
            return DeclSyntax(renderProperty(sig))

        case .computedProperty(let sig):
            return DeclSyntax(renderComputedProperty(sig))

        case .extensionDecl(let sig):
            return DeclSyntax(renderExtension(sig))

        case .structDecl(let sig):
            return DeclSyntax(renderStruct(sig))

        case .enumDecl(let sig):
            return DeclSyntax(renderEnum(sig))

        case .typeAlias(let sig):
            return DeclSyntax(renderTypeAlias(sig))

        case .initDecl(let sig):
            return DeclSyntax(renderInitializer(sig))
        }
    }

    // MARK: - Private Declaration Helpers

    private static func renderFunction<A: Sendable>(_ sig: FunctionSignature<A>) -> FunctionDeclSyntax
    {
        let params = renderParameterList(sig.parameters)

        let parameterClause = FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax(params)
        )

        var effectSpecifiers: FunctionEffectSpecifiersSyntax?
        if sig.isAsync || sig.canThrow {
            effectSpecifiers = FunctionEffectSpecifiersSyntax(
                asyncSpecifier: sig.isAsync ? .keyword(.async) : nil,
                throwsClause: sig.canThrow ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws)) : nil
            )
        }

        let returnClause = sig.returnType.map { type in
            ReturnClauseSyntax(type: TypeSyntax(stringLiteral: type))
        }

        let signature = FunctionSignatureSyntax(
            parameterClause: parameterClause,
            effectSpecifiers: effectSpecifiers,
            returnClause: returnClause
        )

        let body = CodeBlockSyntax(statements: legacyRenderStatements(sig.body))

        var modifierList: [DeclModifierSyntax] = []
        if let keyword = sig.accessLevel.keyword {
            modifierList.append(DeclModifierSyntax(name: .keyword(keyword)))
        }
        if sig.isStatic {
            modifierList.append(DeclModifierSyntax(name: .keyword(.static)))
        }
        if sig.isMutating {
            modifierList.append(DeclModifierSyntax(name: .keyword(.mutating)))
        }

        return FunctionDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: DeclModifierListSyntax(modifierList),
            name: .identifier(sig.name),
            genericParameterClause: renderGenericParameterClause(sig.genericParameters),
            signature: signature,
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
            body: body
        )
    }

    private static func renderProperty<A: Sendable>(_ sig: PropertySignature<A>) -> VariableDeclSyntax
    {
        var modifierList: [DeclModifierSyntax] = []
        if let keyword = sig.accessLevel.keyword {
            modifierList.append(DeclModifierSyntax(name: .keyword(keyword)))
        }
        if sig.isStatic {
            modifierList.append(DeclModifierSyntax(name: .keyword(.static)))
        }
        let modifiers = DeclModifierListSyntax(modifierList)

        let pattern = IdentifierPatternSyntax(identifier: .identifier(sig.name))
        let typeAnnotation = sig.type.map { TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: $0)) }
        let initializer = sig.initializer.map { InitializerClauseSyntax(value: legacyRender($0)) }

        let binding = PatternBindingSyntax(
            pattern: PatternSyntax(pattern),
            typeAnnotation: typeAnnotation,
            initializer: initializer
        )

        return VariableDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: modifiers,
            bindingSpecifier: sig.isLet ? .keyword(.let) : .keyword(.var),
            bindings: PatternBindingListSyntax([binding])
        )
    }

    private static func renderComputedProperty<A: Sendable>(
        _ sig: ComputedPropertySignature<A>
    ) -> VariableDeclSyntax {
        var modifierList: [DeclModifierSyntax] = []
        if let keyword = sig.accessLevel.keyword {
            modifierList.append(DeclModifierSyntax(name: .keyword(keyword)))
        }
        if sig.isStatic {
            modifierList.append(DeclModifierSyntax(name: .keyword(.static)))
        }
        let modifiers = DeclModifierListSyntax(modifierList)

        let getterBody = CodeBlockSyntax(statements: legacyRenderStatements(sig.getter))
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get),
            body: getterBody
        )

        var accessors: AccessorDeclListSyntax
        if let setterSig = sig.setter {
            let setterBody = CodeBlockSyntax(statements: legacyRenderStatements(setterSig.body))
            let setter = AccessorDeclSyntax(
                accessorSpecifier: .keyword(.set),
                parameters: setterSig.parameterName.map {
                    AccessorParametersSyntax(name: .identifier($0))
                },
                body: setterBody
            )
            accessors = AccessorDeclListSyntax([getter, setter])
        } else {
            accessors = AccessorDeclListSyntax([getter])
        }

        let pattern = IdentifierPatternSyntax(identifier: .identifier(sig.name))
        let typeAnnotation = TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: sig.type))

        let binding = PatternBindingSyntax(
            pattern: PatternSyntax(pattern),
            typeAnnotation: typeAnnotation,
            accessorBlock: AccessorBlockSyntax(accessors: .accessors(accessors))
        )

        return VariableDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: modifiers,
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax([binding])
        )
    }

    /// Renders an `ExtensionSignature` directly to `ExtensionDeclSyntax`.
    ///
    /// Use this when the `ExtensionMacro` protocol requires `[ExtensionDeclSyntax]`
    /// rather than `DeclSyntax`.
    public static func renderExtensionDecl<A: Sendable>(
        _ sig: ExtensionSignature<A>
    ) -> ExtensionDeclSyntax {
        renderExtension(sig)
    }

    private static func renderExtension<A: Sendable>(
        _ sig: ExtensionSignature<A>
    ) -> ExtensionDeclSyntax {
        let members = MemberBlockItemListSyntax(
            sig.members.map { member in
                MemberBlockItemSyntax(decl: legacyRender(member))
            }
        )

        return ExtensionDeclSyntax(
            modifiers: renderModifiers(accessLevel: sig.accessLevel),
            extendedType: TypeSyntax(stringLiteral: sig.typeName),
            inheritanceClause: renderInheritanceClause(sig.conformances),
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
            memberBlock: MemberBlockSyntax(members: members)
        )
    }

    private static func renderStruct<A: Sendable>(_ sig: StructSignature<A>) -> StructDeclSyntax {
        let members = MemberBlockItemListSyntax(
            sig.members.map { member in
                MemberBlockItemSyntax(decl: legacyRender(member))
            }
        )

        return StructDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: renderModifiers(accessLevel: sig.accessLevel),
            name: .identifier(sig.name),
            genericParameterClause: renderGenericParameterClause(sig.genericParameters),
            inheritanceClause: renderInheritanceClause(sig.conformances),
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
            memberBlock: MemberBlockSyntax(members: members)
        )
    }

    private static func renderEnum<A: Sendable>(_ sig: EnumSignature<A>) -> EnumDeclSyntax {
        var members: [MemberBlockItemSyntax] = sig.cases.map { enumCase in
            MemberBlockItemSyntax(decl: DeclSyntax(stringLiteral: renderEnumCaseDeclaration(enumCase)))
        }

        members.append(
            contentsOf: sig.members.map { member in
                MemberBlockItemSyntax(decl: legacyRender(member))
            }
        )

        return EnumDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: renderModifiers(accessLevel: sig.accessLevel),
            name: .identifier(sig.name),
            genericParameterClause: renderGenericParameterClause(sig.genericParameters),
            inheritanceClause: renderInheritanceClause(sig.conformances),
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
            memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(members))
        )
    }

    private static func renderEnumCaseDeclaration(_ sig: EnumCaseSignature) -> String {
        var declaration = "case \(sig.name)"

        if !sig.associatedTypes.isEmpty {
            declaration += "(\(sig.associatedTypes.joined(separator: ", ")))"
        }

        if let rawValue = sig.rawValue {
            declaration += " = \"\(rawValue)\""
        }

        return declaration
    }

    private static func renderTypeAlias(_ sig: TypeAliasSignature) -> TypeAliasDeclSyntax {
        TypeAliasDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: renderModifiers(accessLevel: sig.accessLevel),
            typealiasKeyword: .keyword(
                .typealias,
                leadingTrivia: sig.accessLevel.keyword == nil ? Trivia() : .space,
                trailingTrivia: .space
            ),
            name: .identifier(sig.name),
            genericParameterClause: renderGenericParameterClause(sig.genericParameters),
            initializer: TypeInitializerClauseSyntax(
                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                value: TypeSyntax(stringLiteral: sig.existingType)
            ),
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements)
        )
    }

    private static func renderInitializer<A: Sendable>(
        _ sig: InitializerSignature<A>
    ) -> InitializerDeclSyntax {
        let params = renderParameterList(sig.parameters)

        let parameterClause = FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax(params)
        )

        let throwsClause: ThrowsClauseSyntax? =
            sig.canThrow
            ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
            : nil

        let signature = FunctionSignatureSyntax(
            parameterClause: parameterClause,
            effectSpecifiers: throwsClause.map { clause in
                FunctionEffectSpecifiersSyntax(throwsClause: clause)
            }
        )

        let body = CodeBlockSyntax(statements: legacyRenderStatements(sig.body))

        return InitializerDeclSyntax(
            attributes: renderAttributes(sig.attributes),
            modifiers: renderModifiers(accessLevel: sig.accessLevel),
            optionalMark: sig.isFailable ? .postfixQuestionMarkToken() : nil,
            genericParameterClause: renderGenericParameterClause(sig.genericParameters),
            signature: signature,
            genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
            body: body
        )
    }

    // MARK: - Modifier Helpers

    private static func renderGenericParameterClause(
        _ genericParameters: [GenericParameterSignature]
    ) -> GenericParameterClauseSyntax? {
        guard !genericParameters.isEmpty else { return nil }

        let parameters = GenericParameterListSyntax(
            genericParameters.enumerated().map { index, parameter in
                GenericParameterSyntax(
                    specifier: parameter.isParameterPack ? .keyword(.each) : nil,
                    name: .identifier(parameter.name),
                    colon: parameter.constraint != nil ? .colonToken() : nil,
                    inheritedType: parameter.constraint.map { TypeSyntax(stringLiteral: $0) },
                    trailingComma: index < genericParameters.count - 1
                        ? .commaToken(trailingTrivia: .space)
                        : nil
                )
            }
        )

        return GenericParameterClauseSyntax(parameters: parameters)
    }

    private static func renderGenericWhereClause(
        _ requirements: [WhereRequirement]
    ) -> GenericWhereClauseSyntax? {
        guard !requirements.isEmpty else { return nil }

        let renderedRequirements = GenericRequirementListSyntax(
            requirements.enumerated().map { index, requirement in
                let renderedRequirement: GenericRequirementSyntax.Requirement

                switch requirement.relation {
                case .conformance:
                    renderedRequirement = .conformanceRequirement(
                        ConformanceRequirementSyntax(
                            leftType: TypeSyntax(stringLiteral: requirement.leftType),
                            rightType: TypeSyntax(stringLiteral: requirement.rightType)
                        ))
                case .sameType:
                    renderedRequirement = .sameTypeRequirement(
                        SameTypeRequirementSyntax(
                            leftType: .init(TypeSyntax(stringLiteral: requirement.leftType)),
                            equal: .binaryOperator("=="),
                            rightType: .init(TypeSyntax(stringLiteral: requirement.rightType))
                        ))
                }

                return GenericRequirementSyntax(
                    requirement: renderedRequirement,
                    trailingComma: index < requirements.count - 1
                        ? .commaToken(trailingTrivia: .space)
                        : nil
                )
            }
        )

        return GenericWhereClauseSyntax(requirements: renderedRequirements)
    }

    private static func renderModifiers(accessLevel: AccessLevel) -> DeclModifierListSyntax {
        guard let keyword = accessLevel.keyword else {
            return DeclModifierListSyntax([])
        }
        return DeclModifierListSyntax([
            DeclModifierSyntax(name: .keyword(keyword))
        ])
    }

    private static func renderInheritanceClause(
        _ conformances: [String]
    ) -> InheritanceClauseSyntax? {
        guard !conformances.isEmpty else { return nil }

        let lastIndex = conformances.count - 1
        let types = conformances.enumerated().map { index, conformance in
            InheritedTypeSyntax(
                type: TypeSyntax(stringLiteral: conformance),
                trailingComma: index < lastIndex ? .commaToken(trailingTrivia: .space) : nil
            )
        }

        return InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax(types))
    }

    // MARK: - Parameter Helpers

    private static func renderParameterList(
        _ parameters: [ParameterSignature]
    ) -> [FunctionParameterSyntax] {
        parameters.enumerated().map { index, param -> FunctionParameterSyntax in
            let firstName = param.label.map { TokenSyntax.identifier($0) } ?? .identifier(param.name)
            let secondName = param.label != nil ? TokenSyntax.identifier(param.name) : nil
            let typePrefix = param.attributes.map(renderAttributeSource).joined(separator: " ")
            let bareType = param.isInout ? "inout \(param.type)" : param.type
            let typeString = typePrefix.isEmpty ? bareType : "\(typePrefix) \(bareType)"

            let defaultExpr: InitializerClauseSyntax? = param.defaultValue.map { value in
                InitializerClauseSyntax(value: ExprSyntax(stringLiteral: value))
            }

            let isLast = index == parameters.count - 1

            return FunctionParameterSyntax(
                firstName: firstName,
                secondName: secondName,
                type: TypeSyntax(stringLiteral: typeString),
                defaultValue: defaultExpr,
                trailingComma: isLast ? nil : .commaToken()
            )
        }
    }
}

extension Renderer {
    /// Renders a declaration via the source-emit-then-parse pipeline (see
    /// `Renderer.renderParsed(_: Template<A>)` in `Renderer.swift` and
    /// `Renderer.renderParsed(_: Statement<A>)` in `StatementRenderer.swift`
    /// for the same technique one and two levels down, at expression and
    /// statement granularity).
    ///
    /// `SourceEmitter` writes Swift source text for the declaration
    /// (embedding `Template`/`Statement` source text for every nested
    /// expression/statement body via `SourceEmitter+Declarations.swift`)
    /// into a buffer, which is then parsed once into a `DeclSyntax` node.
    /// This is the implementation behind the public
    /// `render(_: Declaration<A>)` entry point above; it remains a separate
    /// internal name so the token-parity suite can call it directly
    /// alongside `legacyRender(_:)`.
    static func renderParsed<A: Sendable>(_ declaration: Declaration<A>) throws -> DeclSyntax {
        var buffer = ""
        SourceEmitter.emit(declaration, into: &buffer)
        let decl: DeclSyntax = "\(raw: buffer)"
        guard !decl.hasError else {
            throw RenderError.make(kind: .declaration, source: buffer, node: decl)
        }
        guard mightNeedSegmentMerge(buffer) else { return decl }
        return StringSegmentMerger().visit(decl)
    }
}
