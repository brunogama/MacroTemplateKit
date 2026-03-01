// MARK: - EquatableExtensionMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax
//   Examples/Sources/MacroExamples/Implementation/Extension/EquatableExtensionMacro.swift
//
// This @attached(extension) macro adds an `extension TypeName: Equatable {}` to
// whatever type it decorates. The compiler synthesises the `==` implementation
// automatically once the conformance declaration is present.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum EquatableExtensionMacro: ExtensionMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     attachedTo declaration: some DeclGroupSyntax,
//     providingExtensionsOf type: some TypeSyntaxProtocol,
//     conformingTo protocols: [TypeSyntax],
//     in context: some MacroExpansionContext
//   ) throws -> [ExtensionDeclSyntax] {
//     // String interpolation: type-system knows nothing about the structure.
//     // A typo in "Equatable" would compile and silently produce invalid code.
//     let equatableExtension = try ExtensionDeclSyntax("extension \(type.trimmed): Equatable {}")
//     return [equatableExtension]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Adds `Equatable` conformance to any type via an extension.
///
/// The macro is attached with `@attached(extension, conformances: Equatable)` and
/// expands to `extension TypeName: Equatable {}`.  The compiler synthesises the
/// `==` operator for structs and enums automatically; class types require a manual
/// implementation inside the expanded extension.
///
/// MacroTemplateKit approach:
/// - `ExtensionSignature` carries the type name and conformance list as typed Swift strings.
/// - `Renderer.renderExtensionDecl(_:)` produces a well-formed `ExtensionDeclSyntax`.
/// - No string interpolation or template literals are used anywhere.
///
/// Template structure:
/// ```
/// Declaration<Never>.extensionDecl(
///   ExtensionSignature(
///     typeName:     "<type>",
///     conformances: ["Equatable"],
///     members:      []           // compiler synthesises ==
///   )
/// )
/// ```
public enum EquatableExtensionMacro: ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Resolve the concrete type name from the attached declaration.
    // `trimmedDescription` strips leading/trailing trivia so the rendered
    // extension header is clean.
    let typeName = type.trimmed.description

    let signature = ExtensionSignature<Never>(
      typeName: typeName,
      conformances: ["Equatable"],
      whereRequirements: [],
      members: []
    )

    let extensionDecl = Renderer.renderExtensionDecl(signature)
    return [extensionDecl]
  }
}
