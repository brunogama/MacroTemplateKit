// MARK: - RemoteBodyMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Tests/SwiftSyntaxMacroExpansionTest/BodyMacroTests.swift
//
// The @Remote body macro replaces a function's body with a remote-call dispatch.
// It introspects the function signature to extract the name and parameter names,
// then generates a body that packages all arguments into a dictionary and forwards
// the call to a `remoteCall(function:arguments:)` implementation.
//
// Usage:
//   @Remote
//   func fetchUser(id: Int, includeDetails: Bool) async throws -> User
//
// Expansion:
//   func fetchUser(id: Int, includeDetails: Bool) async throws -> User {
//     return try await remoteCall(function: "fetchUser", arguments: ["id": id, "includeDetails": includeDetails])
//   }
//
// This is a BodyMacro — it replaces the entire function body rather than attaching
// accessors or peers. The BodyMacro protocol is experimental in swift-syntax
// (@_spi(ExperimentalLanguageFeatures)) and is included here for completeness.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// struct RemoteBodyMacro: BodyMacro {
//   static func expansion(
//     of node: AttributeSyntax,
//     providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
//     in context: some MacroExpansionContext
//   ) throws -> [CodeBlockItemSyntax] {
//     guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else { return [] }
//
//     let funcBaseName = funcDecl.name.text
//     let paramNames = funcDecl.signature.parameterClause.parameters.map { param in
//       param.parameterName ?? TokenSyntax(.wildcard, presence: .present)
//     }
//
//     // The arguments dictionary is built with raw string interpolation.
//     // Each param name is interpolated as a literal key and a bare identifier value.
//     let passedArgs = DictionaryExprSyntax(
//       content: .elements(
//         DictionaryElementListSyntax {
//           for paramName in paramNames {
//             DictionaryElementSyntax(
//               key: ExprSyntax("\(literal: paramName.text)"),
//               value: DeclReferenceExprSyntax(baseName: paramName)
//             )
//           }
//         }
//       )
//     )
//
//     return [
//       """
//       return try await remoteCall(function: \(literal: funcBaseName), arguments: \(passedArgs))
//       """
//     ]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during Remote body macro expansion.
public enum RemoteBodyMacroExpansionError: Error, Sendable {
  /// The attached declaration is not a function.
  case notAFunction
}

/// Body macro that replaces a function body with an async remote-call dispatch.
///
/// Extracts the function name and all parameter names, then generates:
///
/// ```swift
/// return try await remoteCall(function: "name", arguments: ["param1": param1, ...])
/// ```
///
/// MacroTemplateKit approach:
/// - The arguments dictionary is built with `.dictionaryLiteral([(key:value:)])`,
///   where each key is `.literal(.string(paramName))` and each value is
///   `.variable(paramName)`.
/// - The `remoteCall` invocation uses `.functionCall(function:arguments:)`.
/// - `try await` wrapping is expressed with `.tryExpression(.awaitExpression(...))`,
///   or equivalently the `.tryAwait(_:)` fluent factory.
/// - The single `return` statement is `.returnStatement(template)`.
/// - `Renderer.renderStatements(_:)` converts the statement array to
///   `CodeBlockItemListSyntax` for use in the `BodyMacro` return type.
@_spi(ExperimentalLanguageFeatures)
public struct RemoteBodyMacro: BodyMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      throw RemoteBodyMacroExpansionError.notAFunction
    }

    let functionName = funcDecl.name.text
    let parameterNames = extractParameterNames(from: funcDecl)
    let bodyStatements = buildBodyStatements(
      functionName: functionName,
      parameterNames: parameterNames
    )

    return Array(Renderer.renderStatements(bodyStatements))
  }

  // MARK: - Private Helpers

  private static func extractParameterNames(
    from funcDecl: FunctionDeclSyntax
  ) -> [String] {
    funcDecl.signature.parameterClause.parameters.compactMap { param in
      param.parameterName?.text
    }
  }

  private static func buildBodyStatements(
    functionName: String,
    parameterNames: [String]
  ) -> [Statement<Void>] {
    // Build ["paramName": paramName, ...] as a dictionary literal.
    let argumentDictionary: Template<Void> = .dictionaryLiteral(
      parameterNames.map { name in
        (
          key: Template<Void>.literal(.string(name)),
          value: Template<Void>.variable(name)
        )
      }
    )

    // Build remoteCall(function: "functionName", arguments: [...])
    let remoteCallExpression: Template<Void> = .functionCall(
      function: "remoteCall",
      arguments: [
        (label: "function", value: .literal(.string(functionName))),
        (label: "arguments", value: argumentDictionary),
      ]
    )

    // Wrap with try await: try await remoteCall(...)
    let tryAwaitExpression: Template<Void> = .tryAwait(remoteCallExpression)

    return [.returnStatement(tryAwaitExpression)]
  }
}
