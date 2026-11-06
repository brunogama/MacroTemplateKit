import SwiftSyntax
import SwiftSyntaxMacros

public struct GeneratedAnswerMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    makeExpectedAnswerExpression()
  }
}
