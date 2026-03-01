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
      modifiers: DeclModifierListSyntax(modifierList),
      name: .identifier(sig.name),
      signature: signature,
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
    let inheritanceClause: InheritanceClauseSyntax? =
      sig.conformances.isEmpty
      ? nil
      : {
        let lastIndex = sig.conformances.count - 1
        let types = sig.conformances.enumerated().map { (index, conformance) in
          InheritedTypeSyntax(
            type: TypeSyntax(stringLiteral: conformance),
            trailingComma: index < lastIndex ? .commaToken(trailingTrivia: .space) : nil
          )
        }
        return InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax(types))
      }()

    let whereClause: GenericWhereClauseSyntax? =
      sig.whereRequirements.isEmpty
      ? nil
      : {
        let requirements = sig.whereRequirements.map { req in
          GenericRequirementSyntax(
            requirement: .init(ConformanceRequirementSyntax(
              leftType: IdentifierTypeSyntax(name: .identifier(req.typeParameter)),
              rightType: IdentifierTypeSyntax(name: .identifier(req.constraint))
            ))
          )
        }
        return GenericWhereClauseSyntax(
          requirements: GenericRequirementListSyntax(requirements)
        )
      }()

    let members = MemberBlockItemListSyntax(
      sig.members.map { member in
        MemberBlockItemSyntax(decl: render(member))
      }
    )

    return ExtensionDeclSyntax(
      extendedType: TypeSyntax(stringLiteral: sig.typeName),
      inheritanceClause: inheritanceClause,
      genericWhereClause: whereClause,
      memberBlock: MemberBlockSyntax(members: members)
    )
  }

  private static func renderStruct<A: Sendable>(_ sig: StructSignature<A>) -> StructDeclSyntax {
    let inheritanceClause: InheritanceClauseSyntax? =
      sig.conformances.isEmpty
      ? nil
      : {
        let lastIndex = sig.conformances.count - 1
        let types = sig.conformances.enumerated().map { (index, conformance) in
          InheritedTypeSyntax(
            type: TypeSyntax(stringLiteral: conformance),
            trailingComma: index < lastIndex ? .commaToken(trailingTrivia: .space) : nil
          )
        }
        return InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax(types))
      }()

    let members = MemberBlockItemListSyntax(
      sig.members.map { member in
        MemberBlockItemSyntax(decl: render(member))
      }
    )

    return StructDeclSyntax(
      modifiers: renderModifiers(accessLevel: sig.accessLevel),
      name: .identifier(sig.name),
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: members)
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
      modifiers: renderModifiers(accessLevel: sig.accessLevel),
      optionalMark: sig.isFailable ? .postfixQuestionMarkToken() : nil,
      signature: signature,
      body: body
    )
  }

  // MARK: - Modifier Helpers

  private static func renderModifiers(accessLevel: AccessLevel) -> DeclModifierListSyntax {
    guard let keyword = accessLevel.keyword else {
      return DeclModifierListSyntax([])
    }
    return DeclModifierListSyntax([
      DeclModifierSyntax(name: .keyword(keyword))
    ])
  }

  // MARK: - Parameter Helpers

  private static func renderParameterList(
    _ parameters: [ParameterSignature]
  ) -> [FunctionParameterSyntax] {
    parameters.enumerated().map { index, param -> FunctionParameterSyntax in
      let firstName = param.label.map { TokenSyntax.identifier($0) } ?? .identifier(param.name)
      let secondName = param.label != nil ? TokenSyntax.identifier(param.name) : nil
      let typeString = param.isInout ? "inout \(param.type)" : param.type

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
