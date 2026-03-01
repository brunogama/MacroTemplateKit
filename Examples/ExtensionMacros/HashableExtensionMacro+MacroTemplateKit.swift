// MARK: - HashableExtensionMacro using MacroTemplateKit
//
// This is a companion to EquatableExtensionMacro, demonstrating the same
// pattern for `Hashable` conformance.  Since `Hashable` refines `Equatable`,
// this extension also satisfies the Equatable requirement.
//
// Attached-macro declaration (user-facing):
//   @attached(extension, conformances: Hashable, Equatable)
//   public macro hashable() = #externalMacro(...)

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum HashableExtensionMacro: ExtensionMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     attachedTo declaration: some DeclGroupSyntax,
//     providingExtensionsOf type: some TypeSyntaxProtocol,
//     conformingTo protocols: [TypeSyntax],
//     in context: some MacroExpansionContext
//   ) throws -> [ExtensionDeclSyntax] {
//     // Two separate string-interpolated extensions — no shared abstraction.
//     let hashable  = try ExtensionDeclSyntax("extension \(type.trimmed): Hashable {}")
//     let equatable = try ExtensionDeclSyntax("extension \(type.trimmed): Equatable {}")
//     return [hashable, equatable]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Adds `Hashable` (and, transitively, `Equatable`) conformance to any type.
///
/// The macro expands to two extensions:
/// ```swift
/// extension TypeName: Hashable {}
/// extension TypeName: Equatable {}
/// ```
///
/// MacroTemplateKit approach:
/// - A private `makeConformanceExtension` helper builds each `ExtensionSignature` and
///   delegates to `Renderer.renderExtensionDecl(_:)`.
/// - The helper eliminates the duplication that plagues the raw-interpolation version.
/// - Extension members stay empty; the compiler synthesises both `hash(into:)` and `==`.
///
/// Template structure (repeated for each protocol):
/// ```
/// ExtensionSignature(
///   typeName:     "<type>",
///   conformances: ["<protocol>"],
///   members:      []
/// )
/// ```
public enum HashableExtensionMacro: ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let typeName = type.trimmed.description

    // Build one extension per synthesised conformance using the shared helper.
    // Order matters: Hashable must appear before Equatable so the compiler
    // sees the stronger conformance first.
    let conformanceNames = ["Hashable", "Equatable"]
    return conformanceNames.map { makeConformanceExtension(typeName: typeName, conformance: $0) }
  }

  // MARK: - Private Helpers

  /// Creates a single empty conformance extension for `typeName`.
  ///
  /// - Parameters:
  ///   - typeName:    The Swift type receiving the conformance.
  ///   - conformance: The protocol name to add (e.g., `"Hashable"`).
  /// - Returns: A `ExtensionDeclSyntax` of the form `extension TypeName: Protocol {}`.
  private static func makeConformanceExtension(
    typeName: String,
    conformance: String
  ) -> ExtensionDeclSyntax {
    let signature = ExtensionSignature<Never>(
      typeName: typeName,
      conformances: [conformance],
      whereRequirements: [],
      members: []
    )
    return Renderer.renderExtensionDecl(signature)
  }
}
