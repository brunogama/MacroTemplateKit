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
  /// - Parameter declaration: Declaration to render
  /// - Returns: SwiftSyntax declaration node
  public static func render<A: Sendable>(_ declaration: Declaration<A>) -> DeclSyntax {
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

    let body = CodeBlockSyntax(statements: renderStatements(sig.body))

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
    let initializer = sig.initializer.map { InitializerClauseSyntax(value: render($0)) }

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

    let getterBody = CodeBlockSyntax(statements: renderStatements(sig.getter))
    let getter = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: getterBody
    )

    var accessors: AccessorDeclListSyntax
    if let setterSig = sig.setter {
      let setterBody = CodeBlockSyntax(statements: renderStatements(setterSig.body))
      let setter = AccessorDeclSyntax(
        accessorSpecifier: .keyword(.set),
        parameters: AccessorParametersSyntax(
          name: .identifier(setterSig.parameterName)
        ),
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
        MemberBlockItemSyntax(decl: render(member))
      }
    )

    return ExtensionDeclSyntax(
      extendedType: TypeSyntax(stringLiteral: sig.typeName),
      inheritanceClause: renderInheritanceClause(sig.conformances),
      genericWhereClause: renderGenericWhereClause(sig.whereRequirements),
      memberBlock: MemberBlockSyntax(members: members)
    )
  }

  private static func renderStruct<A: Sendable>(_ sig: StructSignature<A>) -> StructDeclSyntax {
    let members = MemberBlockItemListSyntax(
      sig.members.map { member in
        MemberBlockItemSyntax(decl: render(member))
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
        MemberBlockItemSyntax(decl: render(member))
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

    let body = CodeBlockSyntax(statements: renderStatements(sig.body))

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

  private static func renderAttributes(_ attributes: [AttributeSignature]) -> AttributeListSyntax {
    AttributeListSyntax(
      attributes.map { attribute in
        AttributeListSyntax.Element(
          AttributeSyntax(stringLiteral: renderAttributeSource(attribute))
        )
      }
    )
  }

  private static func renderAttributeSource(_ attribute: AttributeSignature) -> String {
    var source = "@\(attribute.name)"
    if let arguments = attribute.arguments {
      source += "(\(renderAttributeArgumentsSource(arguments)))"
    }
    return source
  }

  private static func renderAttributeArgumentsSource(
    _ arguments: AttributeSignature.Arguments
  ) -> String {
    switch arguments {
    case .argumentList(let arguments):
      return arguments.map { argument in
        if let label = argument.label {
          return "\(label): \(argument.value)"
        }
        return argument.value
      }.joined(separator: ", ")
    case .availability(let arguments):
      return arguments.map(renderAvailabilityArgumentSource).joined(separator: ", ")
    }
  }

  private static func renderAvailabilityArgumentSource(
    _ argument: AttributeSignature.AvailabilityArgument
  ) -> String {
    switch argument {
    case .token(let token):
      return token
    case .platform(let platform, let version):
      guard let version else { return platform }
      return "\(platform) \(version)"
    case .labeled(let label, let value):
      return "\(label): \(renderAvailabilityValueSource(value))"
    }
  }

  private static func renderAvailabilityValueSource(
    _ value: AttributeSignature.AvailabilityValue
  ) -> String {
    switch value {
    case .string(let string):
      return "\"\(string)\""
    case .version(let version):
      return version
    }
  }

  private static func renderAttribute(_ attribute: AttributeSignature) -> AttributeSyntax {
    let renderedArguments = renderAttributeArguments(attribute.arguments)

    return AttributeSyntax(
      atSign: .atSignToken(),
      attributeName: TypeSyntax(stringLiteral: attribute.name),
      leftParen: renderedArguments != nil ? .leftParenToken() : nil,
      arguments: renderedArguments,
      rightParen: renderedArguments != nil ? .rightParenToken() : nil
    )
  }

  private static func renderAttributeArguments(
    _ arguments: AttributeSignature.Arguments?
  ) -> AttributeSyntax.Arguments? {
    guard let arguments else { return nil }

    switch arguments {
    case .argumentList(let arguments):
      let labeledArguments = LabeledExprListSyntax(
        arguments.enumerated().map { index, argument in
          LabeledExprSyntax(
            label: argument.label.map { .identifier($0) },
            colon: argument.label != nil ? .colonToken() : nil,
            expression: ExprSyntax(stringLiteral: argument.value),
            trailingComma: index < arguments.count - 1 ? .commaToken(trailingTrivia: .space) : nil
          )
        }
      )
      return .argumentList(labeledArguments)
    case .availability(let arguments):
      let availabilityArguments = AvailabilityArgumentListSyntax(
        arguments.enumerated().map { index, argument in
          renderAvailabilityArgument(argument, isLast: index == arguments.count - 1)
        }
      )
      return .availability(availabilityArguments)
    }
  }

  private static func renderAvailabilityArgument(
    _ argument: AttributeSignature.AvailabilityArgument,
    isLast: Bool
  ) -> AvailabilityArgumentSyntax {
    let trailingComma = isLast ? nil : TokenSyntax.commaToken(trailingTrivia: .space)

    switch argument {
    case .token(let token):
      return AvailabilityArgumentSyntax(
        argument: .token(renderAvailabilityToken(token)),
        trailingComma: trailingComma
      )
    case .platform(let platform, let version):
      return AvailabilityArgumentSyntax(
        argument: .availabilityVersionRestriction(
          PlatformVersionSyntax(
            platform: .identifier(platform),
            version: version.map(renderVersionTuple)
          )),
        trailingComma: trailingComma
      )
    case .labeled(let label, let value):
      return AvailabilityArgumentSyntax(
        argument: .availabilityLabeledArgument(
          AvailabilityLabeledArgumentSyntax(
            label: .identifier(label),
            value: renderAvailabilityValue(value)
          )),
        trailingComma: trailingComma
      )
    }
  }

  private static func renderAvailabilityToken(_ token: String) -> TokenSyntax {
    switch token {
    case "*":
      return .wildcardToken()
    case "deprecated":
      return .keyword(.deprecated)
    case "unavailable":
      return .keyword(.unavailable)
    default:
      return .identifier(token)
    }
  }

  private static func renderAvailabilityValue(
    _ value: AttributeSignature.AvailabilityValue
  ) -> AvailabilityLabeledArgumentSyntax.Value {
    switch value {
    case .string(let string):
      return .string(renderSimpleStringLiteral(string))
    case .version(let version):
      return .version(renderVersionTuple(version))
    }
  }

  private static func renderSimpleStringLiteral(_ string: String) -> SimpleStringLiteralExprSyntax {
    SimpleStringLiteralExprSyntax(
      openingQuote: .stringQuoteToken(),
      segments: SimpleStringLiteralSegmentListSyntax([
        StringSegmentSyntax(content: .stringSegment(string))
      ]),
      closingQuote: .stringQuoteToken()
    )
  }

  private static func renderVersionTuple(_ version: String) -> VersionTupleSyntax {
    let parts = version.split(separator: ".").map(String.init)
    let major = parts.first ?? "0"
    let components = parts.dropFirst().map { component in
      VersionComponentSyntax(number: .integerLiteral(component))
    }

    return VersionTupleSyntax(
      major: .integerLiteral(major),
      components: VersionComponentListSyntax(components)
    )
  }

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
