// MARK: - ComputedPropertyAccessorMacro using MacroTemplateKit
//
// This example demonstrates how to use MacroTemplateKit's Declaration.computedProperty()
// directly to generate a full computed property declaration from an AccessorMacro.
//
// While AccessorMacro returns [AccessorDeclSyntax] (individual accessor blocks),
// DeclarationMacro can return full VariableDeclSyntax nodes via Declaration.computedProperty().
// This example bridges both approaches:
//
// 1. AccessorMacro: Shows using Renderer.renderStatements for individual accessor bodies.
// 2. DeclarationMacro: Shows using Declaration.computedProperty() for a full computed property.
//
// Use case: A @Clamped(min:max:) accessor macro that ensures a numeric property
// is always constrained to a valid range, storing the raw value in an underscore-prefixed
// backing field.
//
// Usage:
//   @Clamped(min: 0, max: 100)
//   var progress: Double = 0.0
//
// Expansion (accessor macro side — adds accessors to the existing declaration):
//   var progress: Double {
//     get { _progress }
//     set { _progress = min(max(newValue, 0.0), 100.0) }
//   }
//
// And separately (peer macro side — would add the backing storage):
//   private var _progress: Double = 0.0

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public struct ClampedAccessorMacro: AccessorMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     providingAccessorsOf declaration: some DeclSyntaxProtocol,
//     in context: some MacroExpansionContext
//   ) throws -> [AccessorDeclSyntax] {
//     guard let varDecl = declaration.as(VariableDeclSyntax.self),
//       let binding = varDecl.bindings.first,
//       let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
//       let minArg = ...,
//       let maxArg = ...
//     else { return [] }
//
//     let backing = "_\(identifier.text)"
//     return [
//       "get { \(raw: backing) }",
//       """
//       set {
//         \(raw: backing) = min(max(newValue, \(minArg)), \(maxArg))
//       }
//       """,
//     ]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during Clamped macro expansion.
public enum ClampedAccessorMacroError: Error, Sendable {
  /// The attached declaration is not a simple stored property.
  case unsupportedDeclaration
  /// The macro requires exactly two numeric arguments: min and max.
  case missingClampArguments
}

/// Accessor macro that enforces a numeric range via a backing storage variable.
///
/// Expands to a `get`/`set` pair that reads from and writes to `_propertyName`,
/// clamping the written value to `[min, max]` on every mutation.
///
/// MacroTemplateKit approach:
/// - The getter is a single `.returnStatement(.variable("_name"))`.
/// - The setter uses nested `.methodCall` nodes to model `min(max(newValue, minVal), maxVal)`.
/// - Both are assembled into `[Statement<Void>]` and rendered with
///   `Renderer.renderStatements(_:)` → `CodeBlockItemListSyntax` → `AccessorDeclSyntax`.
///
/// This example also demonstrates:
/// - Extracting numeric attribute arguments from `AttributeSyntax`.
/// - Building nested function-call templates for `min`/`max` clamping.
public struct ClampedAccessorMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    let propertyName = try extractPropertyName(from: declaration)
    let clampBounds = try extractClampBounds(from: node)
    return buildAccessorDeclarations(
      propertyName: propertyName,
      minimumBound: clampBounds.minimum,
      maximumBound: clampBounds.maximum
    )
  }

  // MARK: - Supporting Types

  private struct ClampBounds {
    let minimum: String
    let maximum: String
  }

  // MARK: - Private Helpers

  private static func extractPropertyName(
    from declaration: some DeclSyntaxProtocol
  ) throws -> String {
    guard
      let varDecl = declaration.as(VariableDeclSyntax.self),
      let binding = varDecl.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      binding.accessorBlock == nil
    else {
      throw ClampedAccessorMacroError.unsupportedDeclaration
    }
    return identifier.text
  }

  private static func extractClampBounds(
    from node: AttributeSyntax
  ) throws -> ClampBounds {
    guard
      case let .argumentList(arguments) = node.arguments,
      arguments.count >= 2,
      let minArgument = arguments.first(where: { $0.label?.text == "min" }),
      let maxArgument = arguments.first(where: { $0.label?.text == "max" })
    else {
      throw ClampedAccessorMacroError.missingClampArguments
    }
    return ClampBounds(
      minimum: minArgument.expression.trimmedDescription,
      maximum: maxArgument.expression.trimmedDescription
    )
  }

  private static func buildAccessorDeclarations(
    propertyName: String,
    minimumBound: String,
    maximumBound: String
  ) -> [AccessorDeclSyntax] {
    let backingName = "_\(propertyName)"
    let backingVariable: Template<Void> = .variable(backingName, payload: ())
    let newValue: Template<Void> = .variable("newValue", payload: ())
    let minimumValue: Template<Void> = .variable(minimumBound, payload: ())
    let maximumValue: Template<Void> = .variable(maximumBound, payload: ())

    // Getter: return _propertyName
    let getterStatements: [Statement<Void>] = [
      .returnStatement(backingVariable)
    ]

    // Clamping expression: min(max(newValue, minimumBound), maximumBound)
    // Inner call: max(newValue, minimumBound)
    let innerClamp: Template<Void> = .functionCall(
      function: "max",
      arguments: [
        (label: nil, value: newValue),
        (label: nil, value: minimumValue),
      ]
    )

    // Outer call: min(innerClamp, maximumBound)
    let outerClamp: Template<Void> = .functionCall(
      function: "min",
      arguments: [
        (label: nil, value: innerClamp),
        (label: nil, value: maximumValue),
      ]
    )

    // Setter: _propertyName = min(max(newValue, minimumBound), maximumBound)
    let setterStatements: [Statement<Void>] = [
      .assignmentStatement(lhs: backingVariable, rhs: outerClamp)
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

// MARK: - Full Computed Property via Declaration.computedProperty()

/// Demonstrates using `Declaration.computedProperty()` + `Renderer.render(_:)`
/// to generate a full `VariableDeclSyntax` (rather than individual `AccessorDeclSyntax` nodes).
///
/// This approach is useful when implementing `DeclarationMacro` (freestanding `#expand`)
/// or when building declaration lists in `MemberMacro` implementations.
///
/// The example generates:
/// ```swift
/// var clampedProgress: Double {
///   get { _progress }
///   set { _progress = min(max(newValue, 0.0), 100.0) }
/// }
/// ```
public enum ComputedPropertyFromDeclarationExample {
  /// Builds a clamped computed property declaration using `Declaration.computedProperty()`.
  ///
  /// - Parameters:
  ///   - propertyName: The public property name.
  ///   - backingName: The underscore-prefixed backing variable name.
  ///   - typeName: The Swift type of the property (e.g., "Double").
  ///   - minimumBound: The minimum clamping bound as source text (e.g., "0.0").
  ///   - maximumBound: The maximum clamping bound as source text (e.g., "100.0").
  /// - Returns: A `DeclSyntax` node representing the computed property.
  public static func makeClampedProperty(
    propertyName: String,
    backingName: String,
    typeName: String,
    minimumBound: String,
    maximumBound: String
  ) -> DeclSyntax {
    let backingVariable: Template<Void> = .variable(backingName, payload: ())
    let newValue: Template<Void> = .variable("newValue", payload: ())
    let minimumValue: Template<Void> = .variable(minimumBound, payload: ())
    let maximumValue: Template<Void> = .variable(maximumBound, payload: ())

    // Getter: return _backingName
    let getterBody: [Statement<Void>] = [
      .returnStatement(backingVariable)
    ]

    // Setter: _backingName = min(max(newValue, min), max)
    let innerClamp: Template<Void> = .functionCall(
      function: "max",
      arguments: [
        (label: nil, value: newValue),
        (label: nil, value: minimumValue),
      ]
    )
    let outerClamp: Template<Void> = .functionCall(
      function: "min",
      arguments: [
        (label: nil, value: innerClamp),
        (label: nil, value: maximumValue),
      ]
    )

    let setterBody: [Statement<Void>] = [
      .assignmentStatement(lhs: backingVariable, rhs: outerClamp)
    ]

    // Build the full computed property declaration using MacroTemplateKit's
    // Declaration.computedProperty() case with ComputedPropertySignature and SetterSignature.
    let computedProperty: Declaration<Void> = .computedProperty(
      ComputedPropertySignature<Void>(
        accessLevel: .public,
        name: propertyName,
        type: typeName,
        getter: getterBody,
        setter: SetterSignature<Void>(
          parameterName: "newValue",
          body: setterBody
        )
      )
    )

    return Renderer.render(computedProperty)
  }
}
