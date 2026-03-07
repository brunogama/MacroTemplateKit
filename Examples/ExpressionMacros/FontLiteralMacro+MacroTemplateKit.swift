// MARK: - FontLiteralMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/FontLiteralMacro.swift
//
// The #fontLiteral(name:size:weight:) macro expands to .init(fontLiteralName:size:weight:),
// renaming the first argument label from "name" to "fontLiteralName" so the result is
// initializer-compatible with types that conform to ExpressibleByFontLiteral.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum FontLiteralMacro: ExpressionMacro {
//   public static func expansion(
//     of node: some FreestandingMacroExpansionSyntax,
//     in context: some MacroExpansionContext
//   ) throws -> ExprSyntax {
//     let argList = replaceFirstLabel(of: node.arguments, with: "fontLiteralName")
//     // Raw string interpolation reassembles the argument list — no type safety.
//     return ".init(\(argList))"
//   }
// }
//
// private func replaceFirstLabel(
//   of tuple: LabeledExprListSyntax,
//   with newLabel: String
// ) -> LabeledExprListSyntax {
//   if tuple.isEmpty { return tuple }
//   var tuple = tuple
//   tuple[tuple.startIndex].label = .identifier(newLabel)
//   tuple[tuple.startIndex].colon  = .colonToken()
//   return tuple
// }

// MARK: - AFTER: MacroTemplateKit

/// Typed errors produced during font literal macro expansion.
public enum FontLiteralMacroExpansionError: Error, Sendable, CustomStringConvertible {
  /// The macro was invoked without arguments.
  case missingArguments

  public var description: String {
    switch self {
    case .missingArguments:
      return "#fontLiteral requires name:, size:, and weight: arguments"
    }
  }
}

/// Implements the `#fontLiteral` expression macro using the MacroTemplateKit template algebra.
///
/// Transforms the macro call-site argument list by renaming the first label from
/// `"name"` to `"fontLiteralName"` and forwarding the remaining arguments verbatim.
/// The expansion calls `.init(fontLiteralName:size:weight:)` on the inferred type,
/// which must conform to `ExpressibleByFontLiteral`.
///
/// Template structure:
/// ```
/// .methodCall(
///   base: .literal(.nil),     // "." prefix member access — rendered as `.init`
///   method: "init",
///   arguments: [
///     (label: "fontLiteralName", value: nameExpr),
///     (label: "size",            value: sizeExpr),
///     (label: "weight",          value: weightExpr),
///   ]
/// )
/// ```
///
/// > Note: `.methodCall` on a `nil` literal renders the empty base before `.init`,
/// > producing the `.init(...)` member-access initializer form expected by
/// > `ExpressibleByFontLiteral`.
public enum FontLiteralMacro: ExpressionMacro {

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let arguments = node.arguments
    guard !arguments.isEmpty else {
      throw FontLiteralMacroExpansionError.missingArguments
    }

    let templateArguments = buildTemplateArguments(from: arguments)

    // Template<Void>: .init(fontLiteralName: name, size: size, weight: weight)
    // The nil-literal base renders as nothing, giving us the bare `.init(...)` form.
    let template: Template<Void> = .methodCall(
      base: .literal(.nil),
      method: "init",
      arguments: templateArguments
    )

    return Renderer.render(template)
  }

  // MARK: - Private Helpers

  private static func buildTemplateArguments(
    from arguments: LabeledExprListSyntax
  ) -> [(label: String?, value: Template<Void>)] {
    arguments.enumerated().map { index, element in
      let label = resolvedLabel(for: element, at: index)
      let value = Template<Void>.variable(element.expression.description)
      return (label: label, value: value)
    }
  }

  /// Returns the argument label, renaming index-0 from `"name"` to `"fontLiteralName"`.
  private static func resolvedLabel(
    for element: LabeledExprSyntax,
    at index: Int
  ) -> String? {
    guard index == 0 else {
      return element.label?.text
    }
    return "fontLiteralName"
  }
}
