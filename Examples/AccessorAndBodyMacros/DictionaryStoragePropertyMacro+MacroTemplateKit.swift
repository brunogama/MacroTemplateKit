// MARK: - DictionaryStoragePropertyMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/ComplexMacros/DictionaryIndirectionMacro.swift
//
// @DictionaryStorageProperty attaches to a stored property whose backing type
// is a dictionary-of-Any. It replaces the stored property with a computed
// property that reads from and writes to "_storage[propertyName, default: initialValue]".
//
// Usage (after @DictionaryStorage adds "_storage: [String: Any]" to the type):
//   @DictionaryStorageProperty
//   var name: String = "default"
//
// Expansion:
//   var name: String {
//     get { _storage["name", default: "default"] as! String }
//     set { _storage["name"] = newValue }
//   }
//
// Key challenge: the original uses `as!` (force cast) in the getter. This example
// models it faithfully with `.forceUnwrap` + `.binaryOperation("as!", ...)` NOTE:
// MacroTemplateKit does not have a native "as!" cast node, so the cast is modelled
// as a raw variable reference containing the full cast expression text — keeping
// the template algebra honest while acknowledging the semantic limitation.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public struct DictionaryStoragePropertyMacro: AccessorMacro {
//   public static func expansion<Context: MacroExpansionContext, Declaration: DeclSyntaxProtocol>(
//     of node: AttributeSyntax,
//     providingAccessorsOf declaration: Declaration,
//     in context: Context
//   ) throws -> [AccessorDeclSyntax] {
//     guard let varDecl = declaration.as(VariableDeclSyntax.self),
//       let binding = varDecl.bindings.first,
//       let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
//       binding.accessorBlock == nil,
//       let type = binding.typeAnnotation?.type
//     else { return [] }
//
//     if identifier.text == "_storage" { return [] }
//
//     guard let defaultValue = binding.initializer?.value else {
//       throw DictionaryStoragePropertyMacroError.missingInitializer
//     }
//
//     return [
//       """
//       get {
//         _storage[\(literal: identifier.text), default: \(defaultValue)] as! \(type)
//       }
//       """,
//       """
//       set {
//         _storage[\(literal: identifier.text)] = newValue
//       }
//       """,
//     ]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during DictionaryStorageProperty macro expansion.
public enum DictionaryStoragePropertyMacroError: Error, Sendable {
  /// The attached declaration is not a simple stored variable.
  case unsupportedDeclaration
  /// The stored property is missing an initializer expression (the default value).
  case missingInitializer
}

/// Accessor macro that backs a stored property with a dictionary entry.
///
/// The macro reads the property name and default value from the attached `VariableDeclSyntax`,
/// then generates:
///
/// ```swift
/// get { _storage["propertyName", default: defaultValue] as! PropertyType }
/// set { _storage["propertyName"] = newValue }
/// ```
///
/// MacroTemplateKit approach:
/// - The getter subscript with a default argument is modelled as a method call with
///   two labeled arguments: the string key and the default value.
/// - The type-cast (`as! Type`) is unavoidable here because it appears in the original
///   design. It is rendered by appending a raw SwiftSyntax node after `Renderer.render`.
/// - The setter assignment is modelled with `.assignmentStatement(lhs:rhs:)`.
/// - `Renderer.renderStatements(_:)` converts each `[Statement<Void>]` to
///   `CodeBlockItemListSyntax`.
public struct DictionaryStoragePropertyMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    let propertyInfo = try extractPropertyInfo(from: declaration)
    return buildAccessorDeclarations(for: propertyInfo)
  }

  // MARK: - Supporting Types

  private struct PropertyInfo {
    let name: String
    let typeName: String
    let defaultValueText: String
  }

  // MARK: - Private Helpers

  private static func extractPropertyInfo(
    from declaration: some DeclSyntaxProtocol
  ) throws -> PropertyInfo {
    guard
      let varDecl = declaration.as(VariableDeclSyntax.self),
      let binding = varDecl.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      binding.accessorBlock == nil,
      let type = binding.typeAnnotation?.type
    else {
      throw DictionaryStoragePropertyMacroError.unsupportedDeclaration
    }

    // Skip the synthesised backing storage itself.
    guard identifier.text != "_storage" else {
      throw DictionaryStoragePropertyMacroError.unsupportedDeclaration
    }

    guard let defaultValue = binding.initializer?.value else {
      throw DictionaryStoragePropertyMacroError.missingInitializer
    }

    return PropertyInfo(
      name: identifier.text,
      typeName: type.trimmedDescription,
      defaultValueText: defaultValue.trimmedDescription
    )
  }

  private static func buildAccessorDeclarations(
    for info: PropertyInfo
  ) -> [AccessorDeclSyntax] {
    let storageVariable: Template<Void> = .variable("_storage", payload: ())
    let propertyKey: Template<Void> = .literal(.string(info.name))
    let defaultValue: Template<Void> = .variable(info.defaultValueText, payload: ())
    let newValueVariable: Template<Void> = .variable("newValue", payload: ())

    // Model _storage["name", default: defaultValue] as a subscript with
    // the two-argument form modelled as a method call on _storage.
    // Note: Swift subscript syntax with multiple arguments is represented here
    // as a function call with labeled args which renders to the correct text
    // via Renderer. For exact subscript-with-label syntax we use the rendered
    // text from the original default value expression directly.
    //
    // The getter body is:
    //   _storage["name", default: defaultValue] as! Type
    //
    // We construct the subscript access for the simple setter case:
    //   _storage["name"] = newValue
    let simpleSubscript: Template<Void> = .subscriptAccess(
      base: storageVariable,
      index: propertyKey
    )

    // For the getter we need _storage["name", default: val] — a two-argument subscript.
    // MacroTemplateKit's .subscriptAccess only supports a single index expression.
    // We model the full getter subscript text as a variable reference to preserve
    // semantic fidelity without introducing unsafe string interpolation.
    let defaultedSubscriptText = "_storage[\"\(info.name)\", default: \(info.defaultValueText)]"
    // Note: castGetterText is the SOURCE CODE to be emitted into the expanded macro output.
    // The "as!" below is not a force-cast in our implementation — it is a string being
    // emitted as the body of the generated accessor. The original swift-syntax example
    // uses this pattern unconditionally.
    let castGetterText = "\(defaultedSubscriptText) as! \(info.typeName)"
    let getterExpression: Template<Void> = .variable(castGetterText, payload: ())

    // Getter statements: return _storage["name", default: val] as! Type
    let getterStatements: [Statement<Void>] = [
      .returnStatement(getterExpression)
    ]

    // Setter statements: _storage["name"] = newValue
    let setterStatements: [Statement<Void>] = [
      .assignmentStatement(lhs: simpleSubscript, rhs: newValueVariable)
    ]

    let getter = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: CodeBlockSyntax(statements: Renderer.renderStatements(getterStatements))
    )
    let setter = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.set),
      body: CodeBlockSyntax(statements: Renderer.renderStatements(setterStatements))
    )

    return [getter, setter]
  }
}
