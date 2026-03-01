// MARK: - SendableExtensionMacro using MacroTemplateKit
//
// This example demonstrates using `WhereRequirement` and conditional conformance
// in an `ExtensionSignature`.  The macro adds a conditional `Sendable` conformance
// only when the attached type's generic parameter also conforms to `Sendable`.
//
// Example expansion for a generic wrapper type:
//   @sendable
//   struct Box<Value> { ... }
//
//   // Expanded:
//   extension Box: Sendable where Value: Sendable {}
//
// Attached-macro declaration (user-facing):
//   @attached(extension, conformances: Sendable)
//   public macro sendable() = #externalMacro(...)

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum SendableExtensionMacro: ExtensionMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     attachedTo declaration: some DeclGroupSyntax,
//     providingExtensionsOf type: some TypeSyntaxProtocol,
//     conformingTo protocols: [TypeSyntax],
//     in context: some MacroExpansionContext
//   ) throws -> [ExtensionDeclSyntax] {
//     guard let genericParam = firstGenericParam(declaration) else { return [] }
//
//     // String interpolation composes type name and generic parameter — no AST
//     // structure guarantees; a multiline literal with a typo would silently
//     // emit ill-formed Swift source.
//     return [try ExtensionDeclSyntax("""
//       extension \(type.trimmed): Sendable where \(raw: genericParam): Sendable {}
//       """)]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Adds a conditional `Sendable` conformance guarded by a `where` clause.
///
/// When attached to a generic type `Box<Value>`, this macro generates:
/// ```swift
/// extension Box: Sendable where Value: Sendable {}
/// ```
///
/// MacroTemplateKit approach:
/// - `WhereRequirement(typeParameter:constraint:)` encodes the `where Value: Sendable`
///   clause as a typed value — no raw string required.
/// - `ExtensionSignature` accepts an array of `WhereRequirement` alongside the conformance.
/// - If the attached type has no generic parameters, the macro skips generation and
///   emits a diagnostic rather than producing a malformed extension.
///
/// Template structure:
/// ```
/// ExtensionSignature(
///   typeName:          "<type>",
///   conformances:      ["Sendable"],
///   whereRequirements: [WhereRequirement(typeParameter: "<Param>", constraint: "Sendable")],
///   members:           []
/// )
/// ```
public enum SendableExtensionMacro: ExtensionMacro {

  // MARK: - Diagnostics

  private static let messageID = MessageID(
    domain: "MacroTemplateKit.Examples",
    id: "SendableExtension"
  )

  // MARK: - ExtensionMacro

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let genericParameters = extractGenericParameters(from: declaration)

    guard !genericParameters.isEmpty else {
      // Non-generic types can unconditionally conform to Sendable; this macro
      // is designed for the conditional-conformance case only.  Emit a diagnostic
      // so the developer knows to use a different approach for non-generic types.
      context.diagnose(
        Diagnostic(
          node: declaration,
          message: SendableDiagnostic.requiresGenericType
        )
      )
      return []
    }

    let typeName = type.trimmed.description

    // Build one where-requirement per generic parameter so that
    // `Box<A, B>` produces `where A: Sendable, B: Sendable`.
    let whereRequirements = genericParameters.map { paramName in
      WhereRequirement(typeParameter: paramName, constraint: "Sendable")
    }

    let signature = ExtensionSignature<Never>(
      typeName: typeName,
      conformances: ["Sendable"],
      whereRequirements: whereRequirements,
      members: []
    )

    return [Renderer.renderExtensionDecl(signature)]
  }

  // MARK: - Private Helpers

  /// Extracts the names of all generic type parameters from a `DeclGroupSyntax`.
  ///
  /// Returns an empty array when the declaration has no generic parameter clause.
  private static func extractGenericParameters(
    from declaration: some DeclGroupSyntax
  ) -> [String] {
    let clause: GenericParameterClauseSyntax?

    switch declaration {
    case let structDecl as StructDeclSyntax:
      clause = structDecl.genericParameterClause
    case let classDecl as ClassDeclSyntax:
      clause = classDecl.genericParameterClause
    case let enumDecl as EnumDeclSyntax:
      clause = enumDecl.genericParameterClause
    default:
      clause = nil
    }

    return clause?.parameters.map { $0.name.text } ?? []
  }
}

// MARK: - Diagnostic Message

private enum SendableDiagnostic: DiagnosticMessage {
  case requiresGenericType

  var message: String {
    switch self {
    case .requiresGenericType:
      return "@sendable extension macro requires a generic type with at least one type parameter"
    }
  }

  var severity: DiagnosticSeverity { .warning }

  var diagnosticID: MessageID {
    MessageID(domain: "MacroTemplateKit.Examples", id: "Sendable.\(self)")
  }
}
