// MARK: - EnvironmentValueMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Accessor/EnvironmentValueMacro.swift
//
// The @EnvironmentValue(for: MyKey.self) macro attaches to a stored property in an
// EnvironmentValues extension and generates a get/set accessor pair that routes
// reads and writes through the supplied EnvironmentKey subscript.
//
// Usage:
//   extension EnvironmentValues {
//     @EnvironmentValue(for: MyEnvironmentKey.self)
//     var myCustomValue: String
//   }
//
// Expansion:
//   extension EnvironmentValues {
//     var myCustomValue: String {
//       get { self[MyEnvironmentKey.self] }
//       set { self[MyEnvironmentKey.self] = newValue }
//     }
//   }

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public struct EnvironmentValueMacro: AccessorMacro {
//   public static func expansion(
//     of node: AttributeSyntax,
//     providingAccessorsOf declaration: some DeclSyntaxProtocol,
//     in context: some MacroExpansionContext
//   ) throws -> [AccessorDeclSyntax] {
//     guard
//       case let .argumentList(arguments) = node.arguments,
//       let argument = arguments.first
//     else { return [] }
//
//     return [
//       "get { self[\(argument.expression)] }",
//       "set { self[\(argument.expression)] = newValue }",
//     ]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during EnvironmentValue macro expansion.
public enum EnvironmentValueMacroExpansionError: Error, Sendable {
  /// The macro attribute has no argument list or the argument list is empty.
  case missingKeyArgument
}

/// Accessor macro that generates an `EnvironmentKey`-backed get/set pair.
///
/// Attach to a stored property in an `EnvironmentValues` extension and supply
/// the `EnvironmentKey` metatype as the argument. The macro expands to:
///
/// ```swift
/// get { self[KeyType.self] }
/// set { self[KeyType.self] = newValue }
/// ```
///
/// MacroTemplateKit approach:
/// - The `get` body is modelled with `.returnStatement(.subscriptAccess(...))`.
/// - The `set` body is modelled with `.assignmentStatement(lhs:rhs:)`.
/// - `Renderer.renderStatements(_:)` converts `[Statement<Void>]` to
///   `CodeBlockItemListSyntax`, which is wrapped in `AccessorDeclSyntax` nodes
///   — the type required by the `AccessorMacro` protocol.
public struct EnvironmentValueMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    let keyExpressionText = try extractKeyExpressionText(from: node)
    return buildAccessorDeclarations(keyExpressionText: keyExpressionText)
  }

  // MARK: - Private Helpers

  private static func extractKeyExpressionText(
    from node: AttributeSyntax
  ) throws -> String {
    guard
      case let .argumentList(arguments) = node.arguments,
      let firstArgument = arguments.first
    else {
      throw EnvironmentValueMacroExpansionError.missingKeyArgument
    }
    return firstArgument.expression.description
  }

  private static func buildAccessorDeclarations(
    keyExpressionText: String
  ) -> [AccessorDeclSyntax] {
    // Model self[KeyType.self] as a subscript access expression.
    // The key expression text is preserved verbatim from the attribute argument.
    let selfVariable: Template<Void> = .variable("self")
    let keyExpression: Template<Void> = .variable(keyExpressionText)
    let subscriptAccess: Template<Void> = .subscriptAccess(
      base: selfVariable,
      index: keyExpression
    )
    let newValueVariable: Template<Void> = .variable("newValue")

    // Getter statements: return self[KeyType.self]
    let getterStatements: [Statement<Void>] = [
      .returnStatement(subscriptAccess)
    ]

    // Setter statements: self[KeyType.self] = newValue
    let setterStatements: [Statement<Void>] = [
      .assignmentStatement(lhs: subscriptAccess, rhs: newValueVariable)
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
