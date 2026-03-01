// MARK: - URLMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/URLMacro.swift
//
// The #URL("https://swift.org/") macro validates the URL string at compile time and
// expands to URL(string: "https://swift.org/")! — a non-optional URL — if valid,
// or emits a compile-time error if the literal is malformed.

import Foundation
import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum URLMacro: ExpressionMacro {
//   public static func expansion(
//     of node: some FreestandingMacroExpansionSyntax,
//     in context: some MacroExpansionContext
//   ) throws -> ExprSyntax {
//     guard let argument = node.arguments.first?.expression,
//       let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
//       segments.count == 1,
//       case .stringSegment(let literalSegment)? = segments.first
//     else {
//       throw CustomError.message("#URL requires a static string literal")
//     }
//     guard URL(string: literalSegment.content.text) != nil else {
//       throw CustomError.message("malformed url: \(argument)")
//     }
//     // Force-unwrap embedded in raw string — no type-safe AST representation.
//     return "URL(string: \(argument))!"
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during URL macro expansion.
public enum URLMacroExpansionError: Error, Sendable, CustomStringConvertible {
  /// The macro argument is not a static string literal.
  case requiresStaticStringLiteral

  /// The provided string cannot be parsed as a URL.
  case malformedURL(String)

  public var description: String {
    switch self {
    case .requiresStaticStringLiteral:
      return "#URL requires a static string literal"
    case .malformedURL(let raw):
      return "malformed url: \(raw)"
    }
  }
}

/// Implements the `#URL` expression macro using the MacroTemplateKit template algebra.
///
/// Validates that the macro argument is a single-segment static string literal and
/// that the string can be parsed by `Foundation.URL`. On success it expands to:
/// ```swift
/// URL(string: "https://example.com")!
/// ```
///
/// Template structure:
/// ```
/// .forceUnwrap(
///   .functionCall(
///     function: "URL",
///     arguments: [(label: "string", value: .literal(.string(urlString)))]
///   )
/// )
/// ```
public enum URLMacro: ExpressionMacro {

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let urlString = try extractValidatedURLString(from: node)

    // Template<Void>: URL(string: "urlString")!
    let template: Template<Void> = .forceUnwrap(
      .functionCall(
        function: "URL",
        arguments: [
          (label: "string", value: .literal(.string(urlString)))
        ]
      )
    )

    return Renderer.render(template)
  }

  // MARK: - Private Helpers

  private static func extractValidatedURLString(
    from node: some FreestandingMacroExpansionSyntax
  ) throws -> String {
    guard
      let argument = node.arguments.first?.expression,
      let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
      segments.count == 1,
      case .stringSegment(let literalSegment)? = segments.first
    else {
      throw URLMacroExpansionError.requiresStaticStringLiteral
    }

    let rawString = literalSegment.content.text

    guard URL(string: rawString) != nil else {
      throw URLMacroExpansionError.malformedURL(rawString)
    }

    return rawString
  }
}
