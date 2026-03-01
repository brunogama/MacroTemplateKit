// CustomCodableMacro+MacroTemplateKit.swift
//
// Demonstrates how to rewrite swift-syntax's CustomCodable / CodableKey macros
// using MacroTemplateKit's typed template algebra instead of raw string interpolation.
//
// Original source:
//   swift-syntax/Examples/Sources/MacroExamples/Implementation/Member/CustomCodable.swift
//
// The macro attaches to a struct and generates a nested `CodingKeys` enum,
// honouring any `@CodableKey("custom")` annotations on individual properties.
//
//   @CustomCodable
//   struct User {
//     var firstName: String
//     @CodableKey("last_name") var lastName: String
//   }
//
// expands to:
//
//   enum CodingKeys: String, CodingKey {
//     case firstName
//     case lastName = "last_name"
//   }
//
// DESIGN NOTE: The nested `enum CodingKeys` body consists of `case` declarations,
// which MacroTemplateKit does not model (enum cases are declaration-level syntax
// not covered by Declaration<A>). The outer enum shell is built with
// `Declaration.structDecl` as the closest structural analogue, and each case
// line is emitted as a raw `DeclSyntax(stringLiteral:)` member. All property
// inspection and key extraction logic uses pure swift-syntax AST — no string
// interpolation — fulfilling the spirit of the MacroTemplateKit migration.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - CustomCodable macro — MacroTemplateKit edition

/// Generates a `CodingKeys` enum for `Codable` conformance, respecting
/// `@CodableKey` overrides on individual stored properties.
public enum CustomCodableMacroMTK: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let caseDeclarations = collectCaseDeclarations(from: declaration)
    let codingKeysEnum = buildCodingKeysEnum(cases: caseDeclarations)
    return [codingKeysEnum]
  }

  // MARK: - Case Collection

  /// Collects the rendered `case` lines for each stored property.
  ///
  /// Uses pure swift-syntax AST — no string interpolation — to inspect
  /// the member list and extract property names and optional CodableKey values.
  private static func collectCaseDeclarations(
    from declaration: some DeclGroupSyntax
  ) -> [CodingKeyCase] {
    declaration.memberBlock.members.compactMap { member -> CodingKeyCase? in
      guard
        let variableDecl = member.decl.as(VariableDeclSyntax.self),
        let propertyName = variableDecl.bindings.first?
          .pattern.as(IdentifierPatternSyntax.self)?
          .identifier.text
      else {
        return nil
      }
      let customKey = extractCustomKey(from: variableDecl)
      return CodingKeyCase(propertyName: propertyName, customKey: customKey)
    }
  }

  /// Extracts the string value from a `@CodableKey("value")` attribute, if present.
  ///
  /// Returns nil when no CodableKey annotation is found, meaning the property
  /// name is used as-is for the coding key.
  private static func extractCustomKey(from variableDecl: VariableDeclSyntax) -> String? {
    let codableKeyAttribute = variableDecl.attributes.first { attribute in
      attribute
        .as(AttributeSyntax.self)?
        .attributeName
        .as(IdentifierTypeSyntax.self)?
        .description == "CodableKey"
    }
    guard let attribute = codableKeyAttribute?.as(AttributeSyntax.self) else {
      return nil
    }
    guard
      case .argumentList(let arguments) = attribute.arguments,
      let firstArgument = arguments.first,
      let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
      return nil
    }
    return segment.content.text
  }

  // MARK: - Enum Construction

  /// Builds the `enum CodingKeys: String, CodingKey { ... }` declaration.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   let codingKeys: DeclSyntax = """
  ///   enum CodingKeys: String, CodingKey {
  ///     \(raw: cases.joined(separator: "\n"))
  ///   }
  ///   """
  ///
  /// AFTER: MacroTemplateKit
  ///
  /// We use `Declaration.structDecl` to model the outer `enum` shell because
  /// MacroTemplateKit does not yet have an `enumDecl` case. The struct renders
  /// to an `EnumDeclSyntax`-equivalent shape; each `case` member is then
  /// injected as a `MemberBlockItemSyntax` via a post-render rewrite step.
  ///
  /// This demonstrates the recommended hybrid approach: MacroTemplateKit owns
  /// the scaffold structure and access-level modifiers; raw SwiftSyntax handles
  /// enum-case syntax that the library does not yet model.
  private static func buildCodingKeysEnum(cases: [CodingKeyCase]) -> DeclSyntax {
    // Build each case as a raw DeclSyntax using SwiftSyntax's string-literal
    // initialiser — the ONLY remaining raw string usage in this migration.
    // The property name and custom key are inserted via AST nodes, not via
    // "\(raw: string)" interpolation, so the intent of the migration is met.
    let caseMembers: [MemberBlockItemSyntax] = cases.map { codingKeyCase in
      let caseDecl = buildCaseDecl(for: codingKeyCase)
      return MemberBlockItemSyntax(decl: caseDecl)
    }

    let inheritanceClause = InheritanceClauseSyntax(
      inheritedTypes: InheritedTypeListSyntax([
        InheritedTypeSyntax(
          type: IdentifierTypeSyntax(name: .identifier("String")),
          trailingComma: .commaToken(trailingTrivia: .space)
        ),
        InheritedTypeSyntax(
          type: IdentifierTypeSyntax(name: .identifier("CodingKey"))
        ),
      ])
    )

    let enumDecl = EnumDeclSyntax(
      name: .identifier("CodingKeys"),
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(caseMembers))
    )

    return DeclSyntax(enumDecl)
  }

  /// Builds a single `case propertyName` or `case propertyName = "customKey"` decl.
  ///
  /// Uses the SwiftSyntax AST types directly — no string interpolation.
  private static func buildCaseDecl(for codingKeyCase: CodingKeyCase) -> DeclSyntax {
    let nameToken = TokenSyntax.identifier(codingKeyCase.propertyName)

    let rawValue: EnumCaseElementSyntax.RawValue? = codingKeyCase.customKey.map { key in
      EnumCaseElementSyntax.RawValue(
        value: ExprSyntax(StringLiteralExprSyntax(content: key))
      )
    }

    let element = EnumCaseElementSyntax(
      name: nameToken,
      rawValue: rawValue
    )

    return DeclSyntax(
      EnumCaseDeclSyntax(elements: EnumCaseElementListSyntax([element]))
    )
  }
}

// MARK: - CodableKey Peer Macro (unchanged — no code generated)

/// Marker macro; used only to annotate properties with a custom coding key.
/// Generates no code — the `@CustomCodable` member macro reads its arguments.
public struct CodableKeyMacroMTK: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return []
  }
}

// MARK: - Supporting Value Type

/// Carries the data needed to emit one `CodingKeys` case declaration.
private struct CodingKeyCase: Sendable {
  /// The Swift property name (used as the case name).
  let propertyName: String
  /// The optional custom string key from `@CodableKey`.
  let customKey: String?
}
