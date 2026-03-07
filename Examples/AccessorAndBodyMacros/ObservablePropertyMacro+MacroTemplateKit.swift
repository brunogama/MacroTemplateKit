// MARK: - ObservablePropertyMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/ComplexMacros/ObservableMacro.swift
//
// @ObservableProperty attaches to a stored property in an @Observable-marked type.
// It replaces the stored property with a computed property that notifies an
// ObservationRegistrar before and after each mutation.
//
// Usage (on a property inside an @Observable struct/class):
//   @ObservableProperty
//   var name: String
//
// Expansion:
//   var name: String {
//     get {
//       _registrar.beginAccess(\.name)
//       defer { _registrar.endAccess() }
//       return _storage.name
//     }
//     set {
//       _registrar.beginAccess(\.name)
//       _registrar.register(observable: self, willSet: \.name, to: newValue)
//       defer {
//         _registrar.register(observable: self, didSet: \.name)
//         _registrar.endAccess()
//       }
//       _storage.name = newValue
//     }
//   }

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public struct ObservablePropertyMacro: AccessorMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     providingAccessorsOf declaration: some DeclSyntaxProtocol,
//     in context: some MacroExpansionContext
//   ) throws -> [AccessorDeclSyntax] {
//     guard let property = declaration.as(VariableDeclSyntax.self),
//       let binding = property.bindings.first,
//       let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
//       binding.accessorBlock == nil
//     else { return [] }
//
//     let getAccessor: AccessorDeclSyntax =
//       """
//       get {
//         _registrar.beginAccess(\\.\(identifier))
//         defer { _registrar.endAccess() }
//         return _storage.\(identifier)
//       }
//       """
//
//     let setAccessor: AccessorDeclSyntax =
//       """
//       set {
//         _registrar.beginAccess(\\.\(identifier))
//         _registrar.register(observable: self, willSet: \\.\(identifier), to: newValue)
//         defer {
//           _registrar.register(observable: self, didSet: \\.\(identifier))
//           _registrar.endAccess()
//         }
//         _storage.\(identifier) = newValue
//       }
//       """
//
//     return [getAccessor, setAccessor]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during ObservableProperty macro expansion.
public enum ObservablePropertyMacroExpansionError: Error, Sendable {
  /// The attached declaration is not a simple stored variable without an existing accessor.
  case unsupportedDeclaration
}

/// Accessor macro that instruments a stored property with observation callbacks.
///
/// Generates `get` and `set` accessors that bracket all reads and writes with
/// calls to `_registrar` (an `ObservationRegistrar` synthesised by `@Observable`).
///
/// MacroTemplateKit approach:
/// - Key-path expressions (`\.name`) are not natively representable in Template<A>
///   because key-path literals require first-class language support. They are
///   modelled as `.variable("\\.\(name)")` which emits the correct
///   identifier token text via `DeclReferenceExprSyntax`.
/// - Method calls on `_registrar` use `.methodCall(base:method:arguments:)`.
/// - `defer` blocks use `.deferStatement([Statement<Void>])`.
/// - The full accessor bodies are built from `[Statement<Void>]` arrays and
///   converted to `CodeBlockItemListSyntax` via `Renderer.renderStatements(_:)`.
public struct ObservablePropertyMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    let propertyName = try extractPropertyName(from: declaration)
    return buildAccessorDeclarations(propertyName: propertyName)
  }

  // MARK: - Private Helpers

  private static func extractPropertyName(
    from declaration: some DeclSyntaxProtocol
  ) throws -> String {
    guard
      let property = declaration.as(VariableDeclSyntax.self),
      let binding = property.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      binding.accessorBlock == nil
    else {
      throw ObservablePropertyMacroExpansionError.unsupportedDeclaration
    }
    return identifier.text
  }

  private static func buildAccessorDeclarations(
    propertyName: String
  ) -> [AccessorDeclSyntax] {
    let registrar: Template<Void> = .variable("_registrar")
    let storage: Template<Void> = .variable("_storage")
    let selfVariable: Template<Void> = .variable("self")
    let newValue: Template<Void> = .variable("newValue")

    // Key-path literals are represented as verbatim identifier text.
    let keyPath: Template<Void> = .variable("\\.\(propertyName)")

    // _registrar.beginAccess(\.propertyName)
    let beginAccess: Template<Void> = .methodCall(
      base: registrar,
      method: "beginAccess",
      arguments: [(label: nil, value: keyPath)]
    )

    // _registrar.endAccess()
    let endAccess: Template<Void> = .methodCall(
      base: registrar,
      method: "endAccess",
      arguments: []
    )

    // _storage.propertyName
    let storageProperty: Template<Void> = .propertyAccess(
      base: storage,
      property: propertyName
    )

    // Getter body:
    //   _registrar.beginAccess(\.propertyName)
    //   defer { _registrar.endAccess() }
    //   return _storage.propertyName
    let getterStatements: [Statement<Void>] = [
      .expression(beginAccess),
      .deferStatement([.expression(endAccess)]),
      .returnStatement(storageProperty),
    ]

    // _registrar.register(observable: self, willSet: \.propertyName, to: newValue)
    let willSetNotification: Template<Void> = .methodCall(
      base: registrar,
      method: "register",
      arguments: [
        (label: "observable", value: selfVariable),
        (label: "willSet", value: keyPath),
        (label: "to", value: newValue),
      ]
    )

    // _registrar.register(observable: self, didSet: \.propertyName)
    let didSetNotification: Template<Void> = .methodCall(
      base: registrar,
      method: "register",
      arguments: [
        (label: "observable", value: selfVariable),
        (label: "didSet", value: keyPath),
      ]
    )

    // _storage.propertyName = newValue
    let storageAssignment: Statement<Void> = .assignmentStatement(
      lhs: storageProperty,
      rhs: newValue
    )

    // Setter body:
    //   _registrar.beginAccess(\.propertyName)
    //   _registrar.register(observable: self, willSet: \.propertyName, to: newValue)
    //   defer {
    //     _registrar.register(observable: self, didSet: \.propertyName)
    //     _registrar.endAccess()
    //   }
    //   _storage.propertyName = newValue
    let setterStatements: [Statement<Void>] = [
      .expression(beginAccess),
      .expression(willSetNotification),
      .deferStatement([
        .expression(didSetNotification),
        .expression(endAccess),
      ]),
      storageAssignment,
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
