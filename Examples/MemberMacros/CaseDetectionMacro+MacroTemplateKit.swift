// CaseDetectionMacro+MacroTemplateKit.swift
//
// Demonstrates how to rewrite swift-syntax's CaseDetectionMacro using
// MacroTemplateKit's typed template algebra instead of raw string interpolation.
//
// Original source:
//   swift-syntax/Examples/Sources/MacroExamples/Implementation/Member/CaseDetectionMacro.swift
//
// The macro attaches to an enum and generates a `var isXxx: Bool` computed
// property for every case, e.g.:
//
//   @CaseDetection
//   enum Direction { case north, south, east, west }
//
// expands to:
//
//   var isNorth: Bool { get { if case .north = self { return true }; return false } }
//   var isSouth: Bool { ... }
//   ...
//
// DESIGN NOTE: The `if case` pattern is not directly representable in
// MacroTemplateKit's Template algebra (it requires SwiftSyntax's
// `MatchingPatternConditionSyntax`). The getter body is therefore constructed
// with two `Statement`s — an `ifStatement` using a `.literal(.boolean(true))`
// condition placeholder that the caller replaces with the real pattern — OR,
// more practically, the if-case is emitted as a `.expression(.variable(...))`
// string-token and the surrounding `returnStatement` nodes use the typed API.
//
// This file shows the pragmatic hybrid: MacroTemplateKit for the property
// scaffold; raw SwiftSyntax only for the `if case` pattern condition that the
// library cannot yet express.

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - CaseDetectionMacro — MacroTemplateKit edition

/// Generates `var isXxx: Bool` computed properties for every enum case.
///
/// Applies `@CaseDetection` to any enum to gain Boolean case-testing properties
/// without boilerplate.
public enum CaseDetectionMacroMTK: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let caseNames = declaration.memberBlock.members
      .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
      .compactMap { $0.elements.first?.name.text }

    return caseNames.map { caseName in
      buildCaseProperty(caseName: caseName)
    }
  }

  // MARK: - Private Helpers

  /// Builds one `var isXxx: Bool` declaration for the given case name.
  ///
  /// - Parameter caseName: Raw enum case name (e.g. "north").
  /// - Returns: Rendered `DeclSyntax` for the computed property.
  private static func buildCaseProperty(caseName: String) -> DeclSyntax {
    let propertyName = "is" + initialUppercased(caseName)

    // BEFORE: raw string interpolation
    //
    // let decl: DeclSyntax = """
    // var \(raw: propertyName): Bool {
    //   if case .\(raw: caseName) = self {
    //     return true
    //   }
    //   return false
    // }
    // """
    // return decl

    // AFTER: MacroTemplateKit
    //
    // The getter uses two typed statements:
    //   1. An if-statement whose condition is the `if case` expression.
    //      Because `if case .x = y` requires MatchingPatternConditionSyntax —
    //      not yet in the Template algebra — we embed it as a pre-formatted
    //      SwiftSyntax IfExprSyntax and wrap it in a `.expression` statement.
    //   2. A typed `returnStatement(.literal(.boolean(false)))`.

    let ifCaseExpr: ExprSyntax = buildIfCaseExpr(caseName: caseName)

    let getter: [Statement<Void>] = [
      .expression(.variable("__placeholder__", payload: ())),  // replaced below
      .returnStatement(.literal(.boolean(false))),
    ]

    // Build the property scaffold via the typed Declaration API.
    let propertyDeclaration = Declaration<Void>.computedProperty(
      ComputedPropertySignature(
        name: propertyName,
        type: "Bool",
        getter: getter
      )
    )

    // Render to get the scaffold DeclSyntax, then surgically replace the
    // placeholder statement with the real `if case` expression.
    let scaffold = Renderer.render(propertyDeclaration)
    return replaceIfCasePlaceholder(in: scaffold, with: ifCaseExpr, caseName: caseName)
  }

  /// Builds the `if case .x = self { return true }` expression using raw SwiftSyntax.
  ///
  /// MacroTemplateKit does not yet model `MatchingPatternConditionSyntax`, so
  /// this helper constructs only the if-case node directly. All surrounding
  /// structure (property scaffold, return false) is handled by MacroTemplateKit.
  private static func buildIfCaseExpr(caseName: String) -> ExprSyntax {
    let pattern = ExpressionPatternSyntax(
      expression: MemberAccessExprSyntax(name: .identifier(caseName))
    )
    let condition = MatchingPatternConditionSyntax(
      pattern: PatternSyntax(pattern),
      initializer: InitializerClauseSyntax(
        value: DeclReferenceExprSyntax(baseName: .keyword(.self))
      )
    )
    let returnTrue = CodeBlockItemSyntax(
      item: .stmt(StmtSyntax(ReturnStmtSyntax(
        expression: BooleanLiteralExprSyntax(true)
      )))
    )
    let ifExpr = IfExprSyntax(
      conditions: ConditionElementListSyntax([
        ConditionElementSyntax(condition: .matchingPattern(condition))
      ]),
      body: CodeBlockSyntax(statements: CodeBlockItemListSyntax([returnTrue]))
    )
    return ExprSyntax(ifExpr)
  }

  /// Replaces the `__placeholder__` expression statement with the real if-case
  /// expression in the rendered declaration syntax.
  ///
  /// This is the minimal unsafe escape hatch: everything except the `if case`
  /// node is generated through MacroTemplateKit's typed API.
  private static func replaceIfCasePlaceholder(
    in decl: DeclSyntax,
    with ifCaseExpr: ExprSyntax,
    caseName: String
  ) -> DeclSyntax {
    // Walk the rendered tree looking for the placeholder DeclReferenceExprSyntax
    // whose baseName is "__placeholder__" and replace it.
    let rewriter = PlaceholderRewriter(replacement: ifCaseExpr)
    return DeclSyntax(rewriter.rewrite(Syntax(decl)))
  }

  /// Capitalises the first character of a string.
  private static func initialUppercased(_ name: String) -> String {
    guard let initial = name.first else {
      return name
    }
    return "\(initial.uppercased())\(name.dropFirst())"
  }
}

// MARK: - Placeholder Rewriter

/// Rewrites the `__placeholder__` expression node inserted by MacroTemplateKit
/// with the real SwiftSyntax expression.
private final class PlaceholderRewriter: SyntaxRewriter {
  private let replacement: ExprSyntax

  init(replacement: ExprSyntax) {
    self.replacement = replacement
  }

  override func visit(_ node: DeclReferenceExprSyntax) -> ExprSyntax {
    guard node.baseName.text == "__placeholder__" else {
      return ExprSyntax(node)
    }
    return replacement
  }
}
