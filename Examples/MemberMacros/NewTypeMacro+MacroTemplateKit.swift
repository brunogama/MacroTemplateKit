// NewTypeMacro+MacroTemplateKit.swift
//
// Demonstrates how to rewrite swift-syntax's NewTypeMacro using
// MacroTemplateKit's typed template algebra instead of raw string interpolation.
//
// Original source:
//   swift-syntax/Examples/Sources/MacroExamples/Implementation/Member/NewTypeMacro.swift
//
// The macro attaches to a struct and generates three members that implement
// the "newtype" / "wrapper type" pattern:
//
//   @NewType(Int.self)
//   public struct UserID {}
//
// expands to:
//
//   public typealias RawValue = Int
//   public var rawValue: RawValue
//   public init(_ rawValue: RawValue) { self.rawValue = rawValue }
//
// DESIGN NOTE: MacroTemplateKit does not model `typealias` declarations.
// The typealias is therefore emitted via `DeclSyntax(stringLiteral:)` using
// the raw type extracted from the attribute as a SwiftSyntax AST token —
// no string interpolation of source text.
//
// The `var rawValue` and `init` are fully expressed through the typed API.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - NewTypeMacro — MacroTemplateKit edition

/// Generates `typealias RawValue`, `var rawValue: RawValue`, and a
/// memberwise `init` for the annotated struct.
///
/// Usage: `@NewType(SomeType.self)` applied to a `struct` declaration.
public enum NewTypeMacroMTK: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let rawTypeName = try extractRawTypeName(from: node)

    guard declaration.as(StructDeclSyntax.self) != nil else {
      throw NewTypeError.notAStruct
    }

    let accessLevel = extractAccessLevel(from: declaration)

    return [
      buildTypeAlias(rawTypeName: rawTypeName, accessLevel: accessLevel),
      buildRawValueProperty(accessLevel: accessLevel),
      buildInitializer(accessLevel: accessLevel),
    ]
  }

  // MARK: - Argument Extraction

  /// Extracts the raw type name from `@NewType(SomeType.self)`.
  ///
  /// Uses pure SwiftSyntax AST inspection — no string interpolation.
  private static func extractRawTypeName(from node: AttributeSyntax) throws -> String {
    guard
      case .argumentList(let arguments) = node.arguments,
      arguments.count == 1,
      let memberAccess = arguments.first?.expression.as(MemberAccessExprSyntax.self),
      let baseName = memberAccess.base?.as(DeclReferenceExprSyntax.self)?.baseName.text
    else {
      throw NewTypeError.invalidArgument
    }
    return baseName
  }

  /// Extracts the access level modifier from the declaration, defaulting to `internal`.
  private static func extractAccessLevel(from declaration: some DeclGroupSyntax) -> AccessLevel {
    guard let modifier = declaration.modifiers.first(where: { modifier in
      switch modifier.name.tokenKind {
      case .keyword(.public), .keyword(.private), .keyword(.fileprivate):
        return true
      default:
        return false
      }
    }) else {
      return .internal
    }

    switch modifier.name.tokenKind {
    case .keyword(.public):
      return .public
    case .keyword(.private):
      return .private
    case .keyword(.fileprivate):
      return .fileprivate
    default:
      return .internal
    }
  }

  // MARK: - Member Builders

  /// Builds `typealias RawValue = <RawType>` as a `DeclSyntax`.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   "\(access)typealias RawValue = \(rawType)"
  ///
  /// AFTER: MacroTemplateKit + raw SwiftSyntax
  ///
  /// MacroTemplateKit does not model `typealias`. The declaration is
  /// constructed via `TypeAliasDeclSyntax` AST nodes with no string
  /// interpolation of source text; the raw type name is inserted as an
  /// `IdentifierTypeSyntax` token.
  private static func buildTypeAlias(rawTypeName: String, accessLevel: AccessLevel) -> DeclSyntax {
    var modifiers: [DeclModifierSyntax] = []
    if let keyword = accessLevel.keyword {
      modifiers.append(DeclModifierSyntax(name: .keyword(keyword)))
    }

    let typeAliasDecl = TypeAliasDeclSyntax(
      modifiers: DeclModifierListSyntax(modifiers),
      name: .identifier("RawValue"),
      initializer: TypeInitializerClauseSyntax(
        value: IdentifierTypeSyntax(name: .identifier(rawTypeName))
      )
    )

    return DeclSyntax(typeAliasDecl)
  }

  /// Builds `var rawValue: RawValue` using MacroTemplateKit's `Declaration.property`.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   "\(access)var rawValue: RawValue"
  ///
  /// AFTER: MacroTemplateKit
  ///
  ///   Declaration.property(PropertySignature(
  ///     accessLevel: accessLevel,
  ///     name: "rawValue",
  ///     type: "RawValue",
  ///     isLet: false,
  ///     initializer: nil
  ///   ))
  private static func buildRawValueProperty(accessLevel: AccessLevel) -> DeclSyntax {
    let propertyDeclaration = Declaration<Void>.property(
      PropertySignature(
        accessLevel: accessLevel,
        name: "rawValue",
        type: "RawValue",
        isLet: false,
        initializer: nil
      )
    )
    return Renderer.render(propertyDeclaration)
  }

  /// Builds `init(_ rawValue: RawValue) { self.rawValue = rawValue }` using
  /// MacroTemplateKit's `Declaration.initDecl`.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   "\(access)init(_ rawValue: RawValue) { self.rawValue = rawValue }"
  ///
  /// AFTER: MacroTemplateKit
  ///
  ///   Declaration.initDecl(InitializerSignature(
  ///     accessLevel: accessLevel,
  ///     parameters: [ParameterSignature(label: "_", name: "rawValue", type: "RawValue")],
  ///     body: [.assignmentStatement(lhs: selfRawValue, rhs: rawValueRef)]
  ///   ))
  private static func buildInitializer(accessLevel: AccessLevel) -> DeclSyntax {
    // `self.rawValue = rawValue`
    let selfRawValue = Template<Void>.propertyAccess(
      base: .variable("self"),
      property: "rawValue"
    )
    let rawValueReference = Template<Void>.variable("rawValue")

    let assignBody = Statement<Void>.assignmentStatement(
      lhs: selfRawValue,
      rhs: rawValueReference
    )

    let initSignature = InitializerSignature<Void>(
      accessLevel: accessLevel,
      parameters: [
        ParameterSignature(
          label: "_",
          name: "rawValue",
          type: "RawValue"
        )
      ],
      body: [assignBody]
    )

    return Renderer.render(Declaration<Void>.initDecl(initSignature))
  }
}

// MARK: - Errors

/// Errors emitted during NewType macro expansion.
enum NewTypeError: Error, Sendable {
  /// The argument was not in the form `SomeType.self`.
  case invalidArgument

  /// The macro was applied to a non-struct declaration.
  case notAStruct
}
