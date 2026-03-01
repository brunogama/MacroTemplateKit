// MARK: - OptionSetMacro (ExtensionMacro role) using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax
//   Examples/Sources/MacroExamples/Implementation/ComplexMacros/OptionSetMacro.swift
//
// OptionSetMacro has two roles: ExtensionMacro and MemberMacro.
// This file focuses on the *extension* role, which adds the `OptionSet` conformance.
// See OptionSetMemberMacro+MacroTemplateKit.swift for the member-generation role.
//
// Given a struct decorated with @OptionSet<RawValue>, the ExtensionMacro role
// generates:
//   extension MyOptions: OptionSet {}

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// extension OptionSetMacro: ExtensionMacro {
//   public static func expansion(...) throws -> [ExtensionDeclSyntax] {
//     guard let (structDecl, _, _) = decodeExpansion(...) else { return [] }
//
//     // Guard: skip if OptionSet conformance already explicit
//     if let inheritedTypes = structDecl.inheritanceClause?.inheritedTypes,
//       inheritedTypes.contains(where: { $0.type.trimmedDescription == "OptionSet" }) {
//       return []
//     }
//
//     // String interpolation — no guarantee the type name is valid Swift syntax.
//     return [try ExtensionDeclSyntax("extension \(type): OptionSet {}")]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Adds `OptionSet` conformance to a struct decorated with `@OptionSet<RawType>`.
///
/// The ExtensionMacro role of `OptionSetMacro` produces:
/// ```swift
/// extension MyOptions: OptionSet {}
/// ```
///
/// The conformance extension is suppressed when the struct already declares
/// `OptionSet` in its inheritance clause — preventing duplicate-conformance errors.
///
/// MacroTemplateKit approach:
/// - `ExtensionSignature` carries the type name and `["OptionSet"]` conformances.
/// - Members are empty — `OptionSet` requirements (rawValue, init) are synthesised
///   by the MemberMacro role.
/// - `Renderer.renderExtensionDecl(_:)` converts the signature to `ExtensionDeclSyntax`.
///
/// Template structure:
/// ```
/// ExtensionSignature(
///   typeName:     "<type>",
///   conformances: ["OptionSet"],
///   members:      []
/// )
/// ```
public enum OptionSetExtensionMacro: ExtensionMacro {

  // MARK: - ExtensionMacro

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: OptionSetDiagnostic.requiresStruct
        )
      )
      return []
    }

    // Suppress the extension if OptionSet conformance is already declared
    // explicitly — the compiler would error on a duplicate conformance.
    guard !alreadyConformsToOptionSet(structDecl) else {
      return []
    }

    let typeName = type.trimmed.description
    let signature = ExtensionSignature<Never>(
      typeName: typeName,
      conformances: ["OptionSet"],
      whereRequirements: [],
      members: []
    )

    return [Renderer.renderExtensionDecl(signature)]
  }

  // MARK: - Private Helpers

  /// Returns `true` if `structDecl` already lists `OptionSet` in its inheritance clause.
  private static func alreadyConformsToOptionSet(_ structDecl: StructDeclSyntax) -> Bool {
    guard let inheritedTypes = structDecl.inheritanceClause?.inheritedTypes else {
      return false
    }
    return inheritedTypes.contains { inherited in
      inherited.type.trimmedDescription == "OptionSet"
    }
  }
}

// MARK: - Diagnostic Message

/// Typed diagnostic messages for `OptionSetExtensionMacro`.
private enum OptionSetDiagnostic: DiagnosticMessage {
  case requiresStruct

  var message: String {
    switch self {
    case .requiresStruct:
      return "'OptionSet' macro can only be applied to a struct"
    }
  }

  var severity: DiagnosticSeverity { .error }

  var diagnosticID: MessageID {
    MessageID(domain: "MacroTemplateKit.Examples", id: "OptionSet.\(self)")
  }
}
