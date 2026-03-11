import SwiftSyntax

/// Inverse of `Renderer` — extracts `Declaration<Never>` from SwiftSyntax `DeclSyntax`.
///
/// Completes the extract-transform-render pipeline: receive `DeclSyntax` from a Swift
/// macro protocol, extract it into the kit's model types, transform with first-class
/// functions, then render back via `Renderer`.
///
/// Body handling: extracted declarations always have empty bodies (`[]`).
/// Use `.map` to swap `Never` for your payload type.
public enum Extractor {

    // MARK: - Top-level dispatch

    /// Extracts a `DeclSyntax` into the kit's declaration model.
    ///
    /// Returns `nil` for unsupported declaration kinds (class, protocol, `#if`, etc.).
    /// For multi-binding variable declarations (e.g. `var x, y: Int`), returns the
    /// first binding. Use ``extractAll(_:)`` to get all bindings.
    public static func extract(_ decl: DeclSyntax) -> Declaration<Never>? {
        extractAll(decl).first
    }

    /// Extracts all declarations from a single `DeclSyntax` node.
    ///
    /// Most declaration kinds produce exactly one result. `VariableDeclSyntax` with
    /// multiple bindings (e.g. `var x = 1, y = 2`) produces one declaration per binding.
    /// Returns an empty array for unsupported declaration kinds.
    public static func extractAll(_ decl: DeclSyntax) -> [Declaration<Never>] {
        if let funcDecl = decl.as(FunctionDeclSyntax.self) {
            return [.function(extract(funcDecl))]
        } else if let initDecl = decl.as(InitializerDeclSyntax.self) {
            return [.initDecl(extract(initDecl))]
        } else if let extDecl = decl.as(ExtensionDeclSyntax.self) {
            return [.extensionDecl(extract(extDecl))]
        } else if let structDecl = decl.as(StructDeclSyntax.self) {
            return [.structDecl(extract(structDecl))]
        } else if let enumDecl = decl.as(EnumDeclSyntax.self) {
            return [.enumDecl(extract(enumDecl))]
        } else if let typeAliasDecl = decl.as(TypeAliasDeclSyntax.self) {
            return [.typeAlias(extract(typeAliasDecl))]
        } else if let varDecl = decl.as(VariableDeclSyntax.self) {
            return extractVariableBindings(varDecl)
        }
        return []
    }

    // MARK: - Typed overloads

    /// Extracts a function declaration into a `FunctionSignature<Never>`.
    public static func extract(_ decl: FunctionDeclSyntax) -> FunctionSignature<Never> {
        FunctionSignature<Never>(
            accessLevel: extractAccessLevel(from: decl.modifiers),
            attributes: extractAttributes(from: decl.attributes),
            isStatic: extractIsStatic(from: decl.modifiers),
            isMutating: extractIsMutating(from: decl.modifiers),
            name: decl.name.text,
            genericParameters: extractGenericParameters(from: decl.genericParameterClause),
            parameters: extractParameters(from: decl.signature.parameterClause),
            isAsync: decl.signature.effectSpecifiers?.asyncSpecifier != nil,
            canThrow: decl.signature.effectSpecifiers?.throwsClause != nil,
            returnType: decl.signature.returnClause.map {
                $0.type.trimmedDescription
            },
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause)
        )
    }

    /// Extracts an initializer declaration into an `InitializerSignature<Never>`.
    public static func extract(_ decl: InitializerDeclSyntax) -> InitializerSignature<Never> {
        InitializerSignature<Never>(
            accessLevel: extractAccessLevel(from: decl.modifiers),
            attributes: extractAttributes(from: decl.attributes),
            isFailable: decl.optionalMark != nil,
            genericParameters: extractGenericParameters(from: decl.genericParameterClause),
            parameters: extractParameters(from: decl.signature.parameterClause),
            canThrow: decl.signature.effectSpecifiers?.throwsClause != nil,
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause)
        )
    }

    /// Extracts an extension declaration into an `ExtensionSignature<Never>`.
    public static func extract(_ decl: ExtensionDeclSyntax) -> ExtensionSignature<Never> {
        let members = decl.memberBlock.members.flatMap { member in
            extractAll(member.decl)
        }
        return ExtensionSignature<Never>(
            typeName: decl.extendedType.trimmedDescription,
            conformances: extractConformances(from: decl.inheritanceClause),
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause),
            members: members
        )
    }

    /// Extracts a struct declaration into a `StructSignature<Never>`.
    public static func extract(_ decl: StructDeclSyntax) -> StructSignature<Never> {
        let members = decl.memberBlock.members.flatMap { member in
            extractAll(member.decl)
        }
        return StructSignature<Never>(
            accessLevel: extractAccessLevel(from: decl.modifiers),
            attributes: extractAttributes(from: decl.attributes),
            name: decl.name.text,
            genericParameters: extractGenericParameters(from: decl.genericParameterClause),
            conformances: extractConformances(from: decl.inheritanceClause),
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause),
            members: members
        )
    }

    /// Extracts an enum declaration into an `EnumSignature<Never>`.
    public static func extract(_ decl: EnumDeclSyntax) -> EnumSignature<Never> {
        var cases: [EnumCaseSignature] = []
        var members: [Declaration<Never>] = []

        for member in decl.memberBlock.members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                cases.append(contentsOf: extractEnumCases(from: caseDecl))
            } else {
                members.append(contentsOf: extractAll(member.decl))
            }
        }

        return EnumSignature<Never>(
            accessLevel: extractAccessLevel(from: decl.modifiers),
            attributes: extractAttributes(from: decl.attributes),
            name: decl.name.text,
            genericParameters: extractGenericParameters(from: decl.genericParameterClause),
            conformances: extractConformances(from: decl.inheritanceClause),
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause),
            cases: cases,
            members: members
        )
    }

    /// Extracts a type alias declaration into a `TypeAliasSignature`.
    public static func extract(_ decl: TypeAliasDeclSyntax) -> TypeAliasSignature {
        TypeAliasSignature(
            accessLevel: extractAccessLevel(from: decl.modifiers),
            attributes: extractAttributes(from: decl.attributes),
            name: decl.name.text,
            genericParameters: extractGenericParameters(from: decl.genericParameterClause),
            existingType: decl.initializer.value.trimmedDescription,
            whereRequirements: extractWhereRequirements(from: decl.genericWhereClause)
        )
    }

    // MARK: - Variable extraction

    /// Extracts all bindings from a variable declaration.
    ///
    /// Each binding in the `PatternBindingListSyntax` produces its own declaration.
    /// For `var x = 1, y = 2`, this returns two `.property` declarations.
    private static func extractVariableBindings(
        _ decl: VariableDeclSyntax
    ) -> [Declaration<Never>] {
        let isLet = decl.bindingSpecifier.tokenKind == .keyword(.let)
        let isStatic = extractIsStatic(from: decl.modifiers)
        let accessLevel = extractAccessLevel(from: decl.modifiers)
        let attributes = extractAttributes(from: decl.attributes)

        return decl.bindings.compactMap { binding in
            extractBinding(
                binding, isLet: isLet, isStatic: isStatic,
                accessLevel: accessLevel, attributes: attributes
            )
        }
    }

    private static func extractBinding(
        _ binding: PatternBindingSyntax,
        isLet: Bool, isStatic: Bool,
        accessLevel: AccessLevel,
        attributes: [AttributeSignature]
    ) -> Declaration<Never>? {
        guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
            return nil
        }

        let type = binding.typeAnnotation?.type.trimmedDescription

        if let accessorBlock = binding.accessorBlock {
            var setter: SetterSignature<Never>?
            if case .accessors(let accessorList) = accessorBlock.accessors {
                for accessor in accessorList
                where accessor.accessorSpecifier.tokenKind == .keyword(.set) {
                    let paramName = accessor.parameters?.name.text ?? "newValue"
                    setter = SetterSignature<Never>(parameterName: paramName, body: [])
                }
            }
            return .computedProperty(
                ComputedPropertySignature<Never>(
                    accessLevel: accessLevel,
                    attributes: attributes,
                    name: name,
                    type: type ?? "Any",
                    isStatic: isStatic,
                    getter: [],
                    setter: setter
                )
            )
        }

        return .property(
            PropertySignature<Never>(
                accessLevel: accessLevel,
                attributes: attributes,
                name: name,
                type: type,
                isStatic: isStatic,
                isLet: isLet
            )
        )
    }

    // MARK: - Enum case extraction

    private static func extractEnumCases(from caseDecl: EnumCaseDeclSyntax) -> [EnumCaseSignature] {
        caseDecl.elements.map { element in
            let rawValue: String? = element.rawValue.map { rawVal in
                let text = rawVal.value.trimmedDescription
                if text.hasPrefix("\""), text.hasSuffix("\"") {
                    return String(text.dropFirst().dropLast())
                }
                return text
            }

            let associatedTypes: [String] =
                element.parameterClause?.parameters.map { param in
                    param.type.trimmedDescription
                } ?? []

            return EnumCaseSignature(
                name: element.name.text,
                rawValue: rawValue,
                associatedTypes: associatedTypes
            )
        }
    }

    // MARK: - Helpers

    private static func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public): return .public
            case .keyword(.private): return .private
            case .keyword(.fileprivate): return .fileprivate
            case .keyword(.internal): return .internal
            default: continue
            }
        }
        return .internal
    }

    private static func extractAttributes(
        from attributeList: AttributeListSyntax
    ) -> [AttributeSignature] {
        attributeList.compactMap { element -> AttributeSignature? in
            guard let attribute = element.as(AttributeSyntax.self) else { return nil }
            let name = attribute.attributeName.trimmedDescription

            guard let arguments = attribute.arguments else {
                return AttributeSignature(name: name)
            }

            switch arguments {
            case .argumentList(let labeledExprs):
                let args = labeledExprs.map { expr in
                    AttributeSignature.Argument(
                        label: expr.label?.text,
                        value: expr.expression.trimmedDescription
                    )
                }
                return AttributeSignature(
                    name: name,
                    arguments: .argumentList(args)
                )
            case .availability(let availArgs):
                let args = availArgs.map(extractAvailabilityArgument)
                return AttributeSignature(
                    name: name,
                    arguments: .availability(args)
                )
            default:
                return AttributeSignature(name: name)
            }
        }
    }

    private static func extractAvailabilityArgument(
        _ arg: AvailabilityArgumentSyntax
    ) -> AttributeSignature.AvailabilityArgument {
        switch arg.argument {
        case .token(let token):
            if token.tokenKind == .binaryOperator("*") || token.tokenKind == .wildcard {
                return .token("*")
            }
            return .token(token.text)
        case .availabilityVersionRestriction(let platformVersion):
            let platform = platformVersion.platform.text
            let version = platformVersion.version?.trimmedDescription
            return .platform(platform, version: version)
        case .availabilityLabeledArgument(let labeled):
            let label = labeled.label.text
            let value: AttributeSignature.AvailabilityValue
            switch labeled.value {
            case .string(let stringLiteral):
                let text = stringLiteral.segments.trimmedDescription
                value = .string(text)
            case .version(let versionTuple):
                value = .version(versionTuple.trimmedDescription)
            }
            return .labeled(label, value)
        }
    }

    private static func extractParameters(
        from parameterClause: FunctionParameterClauseSyntax
    ) -> [ParameterSignature] {
        parameterClause.parameters.map { param in
            let firstName = param.firstName.text
            let secondName = param.secondName?.text

            let label: String?
            let name: String
            if let second = secondName {
                label = firstName
                name = second
            } else {
                label = nil
                name = firstName
            }

            let (bareType, paramAttributes, isInout) = unwrapParameterType(param.type)

            let defaultValue = param.defaultValue?.value.trimmedDescription

            return ParameterSignature(
                label: label,
                name: name,
                type: bareType,
                attributes: paramAttributes,
                isInout: isInout,
                defaultValue: defaultValue
            )
        }
    }

    private static func unwrapParameterType(
        _ typeSyntax: TypeSyntax
    ) -> (type: String, attributes: [AttributeSignature], isInout: Bool) {
        if let attributed = typeSyntax.as(AttributedTypeSyntax.self) {
            var attrs: [AttributeSignature] = []
            var isInout = false

            for specifier in attributed.specifiers {
                if let simpleSpec = specifier.as(SimpleTypeSpecifierSyntax.self),
                   simpleSpec.specifier.tokenKind == .keyword(.inout)
                {
                    isInout = true
                }
            }

            for attribute in attributed.attributes {
                if let attr = attribute.as(AttributeSyntax.self) {
                    attrs.append(AttributeSignature(attr.attributeName.trimmedDescription))
                }
            }

            let bareType = attributed.baseType.trimmedDescription
            return (bareType, attrs, isInout)
        }

        return (typeSyntax.trimmedDescription, [], false)
    }

    private static func extractGenericParameters(
        from clause: GenericParameterClauseSyntax?
    ) -> [GenericParameterSignature] {
        guard let clause else { return [] }
        return clause.parameters.map { param in
            GenericParameterSignature(
                name: param.name.text,
                isParameterPack: param.specifier?.tokenKind == .keyword(.each),
                constraint: param.inheritedType?.trimmedDescription
            )
        }
    }

    private static func extractWhereRequirements(
        from clause: GenericWhereClauseSyntax?
    ) -> [WhereRequirement] {
        guard let clause else { return [] }
        return clause.requirements.compactMap { requirement in
            switch requirement.requirement {
            case .conformanceRequirement(let conformance):
                return WhereRequirement(
                    leftType: conformance.leftType.trimmedDescription,
                    relation: .conformance,
                    rightType: conformance.rightType.trimmedDescription
                )
            case .sameTypeRequirement(let sameType):
                return WhereRequirement(
                    leftType: sameType.leftType.trimmedDescription,
                    relation: .sameType,
                    rightType: sameType.rightType.trimmedDescription
                )
            default:
                return nil
            }
        }
    }

    private static func extractConformances(
        from clause: InheritanceClauseSyntax?
    ) -> [String] {
        guard let clause else { return [] }
        return clause.inheritedTypes.map { $0.type.trimmedDescription }
    }

    private static func extractIsStatic(from modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.static) }
    }

    private static func extractIsMutating(from modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.mutating) }
    }
}
