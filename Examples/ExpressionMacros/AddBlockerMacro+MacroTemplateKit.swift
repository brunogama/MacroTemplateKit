// MARK: - AddBlockerMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax Examples/Sources/MacroExamples/Implementation/Expression/AddBlocker.swift
//
// The #addBlocker(expr) macro warns on every binary `+` operator found in the expression
// and emits a Fix-It to change them to `-`. It then returns the (rewritten) expression.
//
// Because this macro requires a deep AST rewrite — traversing InfixOperatorExprSyntax nodes
// with a SyntaxRewriter — it is an example where MacroTemplateKit is used for the final
// *output* expression while the diagnostic-and-rewrite logic still uses SwiftSyntax directly.
// This reflects the single-responsibility pattern: MacroTemplateKit handles code generation;
// SwiftSyntax handles AST transformation.

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation (implicit — result is an ExprSyntax, not a string)

// public struct AddBlocker: ExpressionMacro {
//   class AddVisitor: SyntaxRewriter {
//     var diagnostics: [Diagnostic] = []
//     override func visit(_ node: InfixOperatorExprSyntax) -> ExprSyntax {
//       if var binOp = node.operator.as(BinaryOperatorExprSyntax.self), binOp.operator.text == "+" {
//         // ... emit warning + Fix-It ...
//         binOp.operator.tokenKind = .binaryOperator("-")
//         return ExprSyntax(node.with(\.operator, ExprSyntax(binOp)))
//       }
//       return ExprSyntax(node)
//     }
//   }
//   public static func expansion(...) throws -> ExprSyntax {
//     let visitor = AddVisitor()
//     let result = visitor.rewrite(Syntax(node))
//     for diag in visitor.diagnostics { context.diagnose(diag) }
//     // The rewritten expression is cast back — no template layer, no separation of concerns.
//     return result.asProtocol(FreestandingMacroExpansionSyntax.self)!
//       .arguments.first!.expression
//   }
// }

// MARK: - AFTER: MacroTemplateKit for output, SwiftSyntax for AST traversal

/// Implements the `#addBlocker` expression macro.
///
/// Traversal and diagnostic emission remain in `AddVisitor` (a `SyntaxRewriter`) because
/// that is the correct tool for structural AST rewriting. Once the rewritten expression
/// is extracted, it is wrapped in a `Template<Void>.variable` and rendered via
/// `Renderer.render(_:)` to produce the final `ExprSyntax`. This keeps the output path
/// type-safe and consistent with the rest of the template system.
public struct AddBlockerMacro: ExpressionMacro {

  /// Typed errors produced during add-blocker macro expansion.
  public enum ExpansionError: Error, Sendable, CustomStringConvertible {
    /// The macro was invoked without any argument expression.
    case missingArgument

    public var description: String {
      switch self {
      case .missingArgument:
        return "#addBlocker requires one expression argument"
      }
    }
  }

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let visitor = AddVisitor()
    let rewrittenSyntax = visitor.rewrite(Syntax(node))

    for diagnostic in visitor.diagnostics {
      context.diagnose(diagnostic)
    }

    guard
      let expansionNode = rewrittenSyntax.asProtocol(FreestandingMacroExpansionSyntax.self),
      let firstExpression = expansionNode.arguments.first?.expression
    else {
      throw ExpansionError.missingArgument
    }

    // MacroTemplateKit output path: wrap the rewritten ExprSyntax description
    // in a variable template and render it, preserving the operator substitution.
    let outputTemplate: Template<Void> = .variable(firstExpression.description)

    return Renderer.render(outputTemplate)
  }
}

// MARK: - AddVisitor

/// Traverses the expression AST, warning on `+` operators and rewriting them to `-`.
///
/// Kept as a `SyntaxRewriter` because structural tree rewriting is outside the scope
/// of the MacroTemplateKit template algebra; the template system handles output generation,
/// not input transformation.
private final class AddVisitor: SyntaxRewriter {

  var diagnostics: [Diagnostic] = []

  override func visit(_ node: InfixOperatorExprSyntax) -> ExprSyntax {
    guard var binaryOperator = node.operator.as(BinaryOperatorExprSyntax.self),
      binaryOperator.operator.text == "+"
    else {
      return ExprSyntax(node)
    }

    let messageID = MessageID(domain: "MacroTemplateKit.AddBlocker", id: "blockedAdd")
    let warning = AdditionWarningDiagnosticMessage(id: messageID)
    let fixIt = buildFixIt(replacing: binaryOperator.operator, messageID: messageID)

    diagnostics.append(
      Diagnostic(
        node: Syntax(node.operator),
        message: warning,
        highlights: [Syntax(node.leftOperand), Syntax(node.rightOperand)],
        fixIts: [fixIt]
      )
    )

    binaryOperator.operator.tokenKind = .binaryOperator("-")
    return ExprSyntax(node.with(\.operator, ExprSyntax(binaryOperator)))
  }

  private func buildFixIt(
    replacing token: TokenSyntax,
    messageID: MessageID
  ) -> FixIt {
    let subtractToken = TokenSyntax(
      .binaryOperator("-"),
      leadingTrivia: token.leadingTrivia,
      trailingTrivia: token.trailingTrivia,
      presence: .present
    )

    return FixIt(
      message: FixItSuggestionMessage(id: messageID),
      changes: [
        .replace(
          oldNode: Syntax(token),
          newNode: Syntax(subtractToken)
        )
      ]
    )
  }
}

// MARK: - DiagnosticMessage types

private struct AdditionWarningDiagnosticMessage: DiagnosticMessage, Sendable {
  let message: String = "blocked an add; did you mean to subtract?"
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity = .warning

  init(id: MessageID) {
    self.diagnosticID = id
  }
}

private struct FixItSuggestionMessage: FixItMessage, Sendable {
  let message: String = "use '-'"
  let fixItID: MessageID

  init(id: MessageID) {
    self.fixItID = id
  }
}
