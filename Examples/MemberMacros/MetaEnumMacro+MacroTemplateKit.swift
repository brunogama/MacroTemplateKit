// MetaEnumMacro+MacroTemplateKit.swift
//
// Demonstrates how to rewrite swift-syntax's MetaEnumMacro using
// MacroTemplateKit's typed template algebra instead of raw string interpolation.
//
// Original source:
//   swift-syntax/Examples/Sources/MacroExamples/Implementation/Member/MetaEnumMacro.swift
//
// The macro attaches to an enum and generates a nested `Meta` enum whose
// cases mirror the parent, plus an `init(_ parent: ParentType)` switch:
//
//   @MetaEnum
//   enum Planet { case mercury, venus, earth, mars }
//
// expands to:
//
//   enum Meta {
//     case mercury
//     case venus
//     case earth
//     case mars
//
//     init(_ parent: Planet) {
//       switch parent {
//       case .mercury: self = .mercury
//       case .venus:   self = .venus
//       case .earth:   self = .earth
//       case .mars:    self = .mars
//       }
//     }
//   }
//
// DESIGN NOTE: MacroTemplateKit does not model `enumDecl` or `case` declarations.
// This example uses:
//   - `Declaration.initDecl` + `Statement.switchStatement` for the typed init.
//   - Raw `EnumDeclSyntax` / `EnumCaseDeclSyntax` for enum structure.
//
// The switch body — the most complex part — is fully expressed through the
// typed Statement/Template algebra.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - MetaEnumMacro — MacroTemplateKit edition

/// Generates a nested `Meta` enum that mirrors all cases of the parent enum,
/// with an initializer mapping from parent to meta values.
public struct MetaEnumMacroMTK: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw MetaEnumError.notAnEnum
    }

    let parentTypeName = enumDecl.name.with(\.trailingTrivia, []).text
    let childCaseNames = extractCaseNames(from: enumDecl)
    let accessModifier = enumDecl.modifiers.first(where: \.isNeededAccessLevelModifier)

    let metaEnum = buildMetaEnum(
      parentTypeName: parentTypeName,
      caseNames: childCaseNames,
      accessModifier: accessModifier,
      uniqueParamName: context.makeUniqueName("parent").text
    )

    return [metaEnum]
  }

  // MARK: - Case Name Extraction

  /// Extracts all case names from the enum declaration using pure AST traversal.
  private static func extractCaseNames(from enumDecl: EnumDeclSyntax) -> [String] {
    enumDecl.memberBlock.members.flatMap { member -> [String] in
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        return []
      }
      return caseDecl.elements.map { $0.name.text }
    }
  }

  // MARK: - Meta Enum Construction

  /// Builds the complete `enum Meta { ... }` declaration.
  ///
  /// BEFORE: raw string interpolation (simplified from original):
  ///
  ///   let caseDecls = childCases.map { "  case \($0.name)" }.joined(separator: "\n")
  ///   return """
  ///   \(access)enum Meta {
  ///   \(raw: caseDecls)
  ///   \(makeMetaInit())
  ///   }
  ///   """
  ///
  /// AFTER: MacroTemplateKit + raw SwiftSyntax for enum structure.
  ///
  /// The init body (the switch) is the most complex part and is handled
  /// entirely by the typed Statement/Template algebra.
  private static func buildMetaEnum(
    parentTypeName: String,
    caseNames: [String],
    accessModifier: DeclModifierSyntax?,
    uniqueParamName: String
  ) -> DeclSyntax {
    let caseMemberItems = caseNames.map { caseName -> MemberBlockItemSyntax in
      let element = EnumCaseElementSyntax(name: .identifier(caseName))
      let caseDecl = EnumCaseDeclSyntax(elements: EnumCaseElementListSyntax([element]))
      return MemberBlockItemSyntax(decl: DeclSyntax(caseDecl))
    }

    let initDecl = buildMetaInit(
      parentTypeName: parentTypeName,
      caseNames: caseNames,
      accessModifier: accessModifier,
      paramName: uniqueParamName
    )

    let initMemberItem = MemberBlockItemSyntax(decl: initDecl)

    var modifiers: [DeclModifierSyntax] = []
    if let access = accessModifier {
      modifiers.append(access)
    }

    let metaEnumDecl = EnumDeclSyntax(
      modifiers: DeclModifierListSyntax(modifiers),
      name: .identifier("Meta"),
      memberBlock: MemberBlockSyntax(
        members: MemberBlockItemListSyntax(caseMemberItems + [initMemberItem])
      )
    )

    return DeclSyntax(metaEnumDecl)
  }

  // MARK: - Init Construction

  /// Builds the `init(_ parent: ParentType)` declaration using MacroTemplateKit.
  ///
  /// BEFORE: raw string interpolation (from original MetaEnumMacro.makeMetaInit):
  ///
  ///   let caseStatements = childCases.map { childCase in
  ///     """
  ///       case .\(childCase.name):
  ///         self = .\(childCase.name)
  ///     """
  ///   }.joined(separator: "\n")
  ///   return """
  ///   \(access)init(_ \(parentParamName): \(parentTypeName)) {
  ///     switch \(parentParamName) {
  ///   \(raw: caseStatements)
  ///     }
  ///   }
  ///   """
  ///
  /// AFTER: MacroTemplateKit
  ///
  ///   Declaration.initDecl(InitializerSignature(
  ///     body: [.switchStatement(subject: .variable(paramName), cases: [...])]
  ///   ))
  ///
  /// Every switch case — `case .x: self = .x` — is a typed SwitchCase with
  /// an assignmentStatement body. No string interpolation needed.
  private static func buildMetaInit(
    parentTypeName: String,
    caseNames: [String],
    accessModifier: DeclModifierSyntax?,
    paramName: String
  ) -> DeclSyntax {
    let switchCases = caseNames.map { caseName -> SwitchCase<Void> in
      buildSwitchCase(caseName: caseName)
    }

    let switchStatement = Statement<Void>.switchStatement(
      subject: .variable(paramName, payload: ()),
      cases: switchCases
    )

    let accessLevel = accessLevelFromModifier(accessModifier)

    let initSignature = InitializerSignature<Void>(
      accessLevel: accessLevel,
      parameters: [
        ParameterSignature(
          label: "_",
          name: paramName,
          type: parentTypeName
        )
      ],
      body: [switchStatement]
    )

    return Renderer.render(Declaration<Void>.initDecl(initSignature))
  }

  /// Builds one switch case: `case .caseName: self = .caseName`.
  ///
  /// The pattern `.caseName` is expressed as a `Template.propertyAccess` with
  /// an empty-string base so that the renderer produces `.caseName` (member
  /// access on an implicit base), matching Swift's implicit enum member syntax.
  private static func buildSwitchCase(caseName: String) -> SwitchCase<Void> {
    // Pattern: `.caseName` — member access on implicit base.
    let casePattern = Template<Void>.propertyAccess(
      base: .variable("", payload: ()),
      property: caseName
    )

    // Body: `self = .caseName`
    let selfAssignment = Statement<Void>.assignmentStatement(
      lhs: .variable("self", payload: ()),
      rhs: .propertyAccess(
        base: .variable("", payload: ()),
        property: caseName
      )
    )

    return SwitchCase<Void>(
      pattern: .expression(casePattern),
      body: [selfAssignment]
    )
  }

  // MARK: - Modifier Helpers

  /// Maps an optional `DeclModifierSyntax` to an `AccessLevel`.
  private static func accessLevelFromModifier(_ modifier: DeclModifierSyntax?) -> AccessLevel {
    guard let modifier else {
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
}

// MARK: - Error

/// Errors emitted during MetaEnum macro expansion.
enum MetaEnumError: Error, Sendable {
  /// The macro was applied to a non-enum declaration.
  case notAnEnum
}

// MARK: - DeclModifierSyntax Helper

extension DeclModifierSyntax {
  /// Returns true for modifiers that affect the public API surface.
  fileprivate var isNeededAccessLevelModifier: Bool {
    switch name.tokenKind {
    case .keyword(.public):
      return true
    default:
      return false
    }
  }
}
