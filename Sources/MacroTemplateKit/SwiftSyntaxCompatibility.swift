import SwiftSyntax

enum SwiftSyntaxCompatibility {
  static func genericArgument(_ type: TypeSyntax) -> GenericArgumentSyntax {
    #if canImport(SwiftSyntax603)
      GenericArgumentSyntax(argument: .type(type))
    #else
      GenericArgumentSyntax(argument: type)
    #endif
  }

  static func genericParameter(
    _ parameter: GenericParameterSignature,
    trailingComma: TokenSyntax?
  ) -> GenericParameterSyntax {
    #if canImport(SwiftSyntax603)
      GenericParameterSyntax(
        specifier: parameter.isParameterPack ? .keyword(.each) : nil,
        name: .identifier(parameter.name),
        colon: parameter.constraint == nil ? nil : .colonToken(),
        inheritedType: parameter.constraint.map { TypeSyntax(stringLiteral: $0) },
        trailingComma: trailingComma
      )
    #else
      GenericParameterSyntax(
        eachKeyword: parameter.isParameterPack ? .keyword(.each) : nil,
        name: .identifier(parameter.name),
        colon: parameter.constraint == nil ? nil : .colonToken(),
        inheritedType: parameter.constraint.map { TypeSyntax(stringLiteral: $0) },
        trailingComma: trailingComma
      )
    #endif
  }

  static func isParameterPack(_ parameter: GenericParameterSyntax) -> Bool {
    #if canImport(SwiftSyntax603)
      parameter.specifier?.tokenKind == .keyword(.each)
    #else
      parameter.eachKeyword?.tokenKind == .keyword(.each)
    #endif
  }

  static func lateTypeSpecifiers(_ type: AttributedTypeSyntax) -> [String] {
    #if canImport(SwiftSyntax603)
      type.lateSpecifiers.map { typeSpecifierText($0) }
    #else
      []
    #endif
  }

  static func typeSpecifierText(_ specifier: some SyntaxProtocol) -> String {
    specifier.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
  }

  static func sameTypeRequirement(
    leftType: TypeSyntax,
    rightType: TypeSyntax
  ) -> GenericRequirementSyntax.Requirement {
    #if canImport(SwiftSyntax603)
      .sameTypeRequirement(
        SameTypeRequirementSyntax(
          leftType: .init(leftType),
          equal: .binaryOperator("=="),
          rightType: .init(rightType)
        )
      )
    #else
      .sameTypeRequirement(
        SameTypeRequirementSyntax(
          leftType: leftType,
          equal: .binaryOperator("=="),
          rightType: rightType
        )
      )
    #endif
  }
}
