// MARK: - WarningMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/WarningMacro.swift
//
// The #myWarning("message") macro emits a compile-time diagnostic warning and
// expands to the Void value `()` so the call site remains a valid expression.

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum WarningMacro: ExpressionMacro {
//   public static func expansion(
//     of node: some FreestandingMacroExpansionSyntax,
//     in context: some MacroExpansionContext
//   ) throws -> ExprSyntax {
//     guard let firstElement = node.arguments.first,
//       let stringLiteral = firstElement.expression.as(StringLiteralExprSyntax.self),
//       stringLiteral.segments.count == 1,
//       case let .stringSegment(messageString)? = stringLiteral.segments.first
//     else {
//       throw CustomError.message("#myWarning macro requires a string literal")
//     }
//     context.diagnose(
//       Diagnostic(
//         node: Syntax(node),
//         message: SimpleDiagnosticMessage(
//           message: messageString.content.description,
//           diagnosticID: MessageID(domain: "test123", id: "error"),
//           severity: .warning
//         )
//       )
//     )
//     // Hard-coded raw string for the Void result — fragile and untyped.
//     return "()"
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during warning macro expansion.
public enum WarningMacroExpansionError: Error, Sendable, CustomStringConvertible {
  /// The macro argument is not a static string literal.
  case requiresStringLiteral

  public var description: String {
    switch self {
    case .requiresStringLiteral:
      return "#myWarning macro requires a string literal"
    }
  }
}

/// Implements the `#myWarning` expression macro using the MacroTemplateKit template algebra.
///
/// Emits a compile-time warning diagnostic and expands to the empty tuple `()` (Void).
/// The Void result is modeled as a zero-argument function call with an empty name, which
/// SwiftSyntax renders as `()`.
///
/// Template structure:
/// ```
/// .functionCall(function: "", arguments: [])
/// ```
public enum WarningMacro: ExpressionMacro {

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let message = try extractWarningMessage(from: node)

    emitWarning(message: message, on: node, in: context)

    // Template<Void>: () — the Void expression result
    let voidTemplate: Template<Void> = .functionCall(function: "", arguments: [])
    return Renderer.render(voidTemplate)
  }

  // MARK: - Private Helpers

  private static func extractWarningMessage(
    from node: some FreestandingMacroExpansionSyntax
  ) throws -> String {
    guard
      let firstElement = node.arguments.first,
      let stringLiteral = firstElement.expression.as(StringLiteralExprSyntax.self),
      stringLiteral.segments.count == 1,
      case let .stringSegment(messageSegment)? = stringLiteral.segments.first
    else {
      throw WarningMacroExpansionError.requiresStringLiteral
    }

    return messageSegment.content.description
  }

  private static func emitWarning(
    message: String,
    on node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) {
    let messageID = MessageID(domain: "MacroTemplateKit.WarningMacro", id: "warning")
    let diagnostic = Diagnostic(
      node: Syntax(node),
      message: WarningDiagnosticMessage(text: message, id: messageID)
    )
    context.diagnose(diagnostic)
  }
}

// MARK: - DiagnosticMessage

/// Diagnostic message carrying the user-supplied warning text.
private struct WarningDiagnosticMessage: DiagnosticMessage, Sendable {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity

  init(text: String, id: MessageID) {
    self.message = text
    self.diagnosticID = id
    self.severity = .warning
  }
}
