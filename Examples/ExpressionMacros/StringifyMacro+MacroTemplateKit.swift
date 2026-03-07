// MARK: - StringifyMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/StringifyMacro.swift
//
// The #stringify(x + y) macro expands to (x + y, "x + y") — a tuple containing
// the evaluated expression and its source-code string representation.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum StringifyMacro: ExpressionMacro {
//   public static func expansion(
//     of node: some FreestandingMacroExpansionSyntax,
//     in context: some MacroExpansionContext
//   ) -> ExprSyntax {
//     guard let argument = node.arguments.first?.expression else {
//       fatalError("compiler bug: the macro does not have any arguments")
//     }
//     // String interpolation builds the tuple directly — no type safety, no AST guarantees.
//     return "(\(argument), \(literal: argument.description))"
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Implements the `#stringify` expression macro using the MacroTemplateKit template algebra.
///
/// Expands `#stringify(expr)` into `(expr, "expr")` — an `(T, String)` tuple — without
/// raw string interpolation. The tuple is modeled as an unlabeled two-element function
/// call, which SwiftSyntax renders as a parenthesised comma-separated expression list.
///
/// Template structure:
/// ```
/// .functionCall(
///   function: "",         // empty name → no callee, bare tuple
///   arguments: [
///     (nil, .variable("argument")),         // the original expression
///     (nil, .literal(.string(sourceText)))  // its stringified source
///   ]
/// )
/// ```
public enum StringifyMacro: ExpressionMacro {

  /// Typed error produced when the macro receives no arguments.
  public enum ExpansionError: Error, Sendable {
    /// The macro was invoked without any argument expression.
    case missingArgument
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let argument = node.arguments.first?.expression else {
      throw ExpansionError.missingArgument
    }

    let sourceText = argument.description

    // Template<Void>: tuple of (argument, "argument description")
    // MacroTemplateKit does not have a dedicated tuple case, so we model
    // the parenthesised pair as a two-argument function call with no callee name.
    // Rendered output: (argument, "sourceText")
    let tupleTemplate: Template<Void> = .functionCall(
      function: "",
      arguments: [
        (label: nil, value: .variable(sourceText)),
        (label: nil, value: .literal(.string(sourceText))),
      ]
    )

    return Renderer.render(tupleTemplate)
  }
}
