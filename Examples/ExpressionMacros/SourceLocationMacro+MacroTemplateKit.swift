// MARK: - SourceLocationMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/SourceLocationMacro.swift
//
// The source-location family of macros (#fileID, #filePath, #line, #column) each query
// the expansion context for the call-site location and return a scalar expression.
// The context already provides ExprSyntax values, so MacroTemplateKit wraps them via
// .variable to maintain a uniform output path through Renderer.render(_:).

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: direct ExprSyntax passthrough (no template layer)

// public struct NativeFileIDMacro: ExpressionMacro {
//   public static func expansion(
//     of node: some FreestandingMacroExpansionSyntax,
//     in context: some MacroExpansionContext
//   ) -> ExprSyntax {
//     // Returns the context-provided ExprSyntax directly — no consistent output path.
//     return context.location(of: node, at: .afterLeadingTrivia, filePathMode: .fileID)!.file
//   }
// }
// // ... NativeFilePathMacro, NativeLineMacro, NativeColumnMacro follow the same pattern.

// MARK: - AFTER: MacroTemplateKit

/// Implements the `#nativeFileID` expression macro.
///
/// Queries `MacroExpansionContext.location` for the call-site file identifier
/// (module/filename form, e.g., `"MyModule/File.swift"`) and returns it as
/// a string literal template.
///
/// Template structure:
/// ```
/// .literal(.string(fileID))
/// ```
public struct NativeFileIDMacro: ExpressionMacro {

  /// Typed error when location information is unavailable.
  public enum ExpansionError: Error, Sendable {
    /// The expansion context could not compute a source location.
    case locationUnavailable
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let location = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .fileID)
    else {
      throw ExpansionError.locationUnavailable
    }

    // Extract the string content from the file expression provided by the context.
    // The context ExprSyntax is a StringLiteralExprSyntax; we read its text and
    // re-render it through MacroTemplateKit to keep the output path consistent.
    let fileDescription = location.file.description
    let template: Template<Void> = .literal(.string(fileDescription))
    return Renderer.render(template)
  }
}

/// Implements the `#nativeFilePath` expression macro.
///
/// Queries `MacroExpansionContext.location` for the full filesystem path
/// (e.g., `"/Users/user/project/Sources/File.swift"`) and returns it as
/// a string literal template.
///
/// Template structure:
/// ```
/// .literal(.string(filePath))
/// ```
public struct NativeFilePathMacro: ExpressionMacro {

  /// Typed error when location information is unavailable.
  public enum ExpansionError: Error, Sendable {
    /// The expansion context could not compute a source location.
    case locationUnavailable
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let location = context.location(of: node, at: .afterLeadingTrivia, filePathMode: .filePath)
    else {
      throw ExpansionError.locationUnavailable
    }

    let fileDescription = location.file.description
    let template: Template<Void> = .literal(.string(fileDescription))
    return Renderer.render(template)
  }
}

/// Implements the `#nativeLine` expression macro.
///
/// Queries `MacroExpansionContext.location` for the 1-based source line number
/// and returns it as an integer literal template.
///
/// Template structure:
/// ```
/// .variable(lineExprDescription)    // the integer literal from the context
/// ```
public struct NativeLineMacro: ExpressionMacro {

  /// Typed error when location information is unavailable.
  public enum ExpansionError: Error, Sendable {
    /// The expansion context could not compute a source location.
    case locationUnavailable
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let location = context.location(of: node) else {
      throw ExpansionError.locationUnavailable
    }

    // The context provides an integer literal ExprSyntax for line/column.
    // We forward it through a variable template so the output path passes
    // through Renderer.render consistently with the rest of the macro.
    let lineDescription = location.line.description
    let template: Template<Void> = .variable(lineDescription, payload: ())
    return Renderer.render(template)
  }
}

/// Implements the `#nativeColumn` expression macro.
///
/// Queries `MacroExpansionContext.location` for the 1-based source column number
/// and returns it as an integer literal template.
///
/// Template structure:
/// ```
/// .variable(columnExprDescription)  // the integer literal from the context
/// ```
public struct NativeColumnMacro: ExpressionMacro {

  /// Typed error when location information is unavailable.
  public enum ExpansionError: Error, Sendable {
    /// The expansion context could not compute a source location.
    case locationUnavailable
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    guard let location = context.location(of: node) else {
      throw ExpansionError.locationUnavailable
    }

    let columnDescription = location.column.description
    let template: Template<Void> = .variable(columnDescription, payload: ())
    return Renderer.render(template)
  }
}
