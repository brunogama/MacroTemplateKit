import SwiftSyntax
import SwiftSyntaxBuilder

/// Statement-level rendering utilities.
///
/// Provides pure functions to transform `Statement<A>` templates into SwiftSyntax
/// statement nodes (`CodeBlockItemSyntax`). Statement rendering is a critical layer
/// between the template AST and executable Swift code.
extension Renderer {
  // MARK: - Statement Rendering

  /// Renders a Statement to SwiftSyntax CodeBlockItemSyntax.
  ///
  /// Converts statement-level templates to executable Swift code. The rendering process:
  /// - Translates each Statement case to corresponding SwiftSyntax statement/declaration node
  /// - Handles variable bindings (let/var), control flow (guard/if), returns, and throws
  /// - Embeds expression templates via `render(_: Template<A>)` for nested expressions
  ///
  /// - Parameter statement: Statement to render
  /// - Returns: SwiftSyntax code block item containing the rendered statement
  public static func render<A: Sendable>(_ statement: Statement<A>) -> CodeBlockItemSyntax {
    switch statement {
    case .letBinding(let name, let type, let initializer):
      return renderLetBinding(name: name, type: type, initializer: initializer)

    case .varBinding(let name, let type, let initializer):
      return renderVarBinding(name: name, type: type, initializer: initializer)

    case .guardStatement(let condition, let elseBody):
      return renderGuard(condition: condition, elseBody: elseBody)

    case .ifStatement(let condition, let thenBody, let elseBody):
      return renderIf(condition: condition, thenBody: thenBody, elseBody: elseBody)

    case .returnStatement(let expr):
      return renderReturn(expression: expr)

    case .throwStatement(let expr):
      return renderThrow(expression: expr)

    case .deferStatement(let body):
      return renderDefer(body: body)

    case .expression(let expr):
      return CodeBlockItemSyntax(item: .expr(render(expr)))

    case .guardLetBinding(let name, let type, let initializer, let elseBody):
      return renderGuardLetBinding(name: name, type: type, initializer: initializer, elseBody: elseBody)

    case .switchStatement(let subject, let cases):
      return renderSwitchStatement(subject: subject, cases: cases)

    case .assignmentStatement(let lhs, let rhs):
      return renderAssignmentStatement(lhs: lhs, rhs: rhs)
    }
  }

  /// Renders multiple statements to CodeBlockItemListSyntax.
  ///
  /// - Parameter statements: Array of statements to render
  /// - Returns: SwiftSyntax code block item list
  public static func renderStatements<A: Sendable>(
    _ statements: [Statement<A>]
  ) -> CodeBlockItemListSyntax {
    CodeBlockItemListSyntax(statements.map { render($0) })
  }

  // MARK: - Private Statement Helpers

  private static func renderLetBinding<A: Sendable>(
    name: String,
    type: String?,
    initializer: Template<A>
  ) -> CodeBlockItemSyntax {
    let pattern = IdentifierPatternSyntax(identifier: .identifier(name))
    let typeAnnotation = type.map { TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: $0)) }

    let binding = PatternBindingSyntax(
      pattern: PatternSyntax(pattern),
      typeAnnotation: typeAnnotation,
      initializer: InitializerClauseSyntax(value: render(initializer))
    )

    let varDecl = VariableDeclSyntax(
      bindingSpecifier: .keyword(.let),
      bindings: PatternBindingListSyntax([binding])
    )

    return CodeBlockItemSyntax(item: .decl(DeclSyntax(varDecl)))
  }

  private static func renderVarBinding<A: Sendable>(
    name: String,
    type: String?,
    initializer: Template<A>
  ) -> CodeBlockItemSyntax {
    let pattern = IdentifierPatternSyntax(identifier: .identifier(name))
    let typeAnnotation = type.map { TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: $0)) }

    let binding = PatternBindingSyntax(
      pattern: PatternSyntax(pattern),
      typeAnnotation: typeAnnotation,
      initializer: InitializerClauseSyntax(value: render(initializer))
    )

    let varDecl = VariableDeclSyntax(
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )

    return CodeBlockItemSyntax(item: .decl(DeclSyntax(varDecl)))
  }

  private static func renderGuard<A: Sendable>(
    condition: Template<A>,
    elseBody: [Statement<A>]
  ) -> CodeBlockItemSyntax {
    let conditionElement = ConditionElementSyntax(
      condition: .expression(render(condition))
    )

    let guardStmt = GuardStmtSyntax(
      conditions: ConditionElementListSyntax([conditionElement]),
      body: CodeBlockSyntax(statements: renderStatements(elseBody))
    )

    return CodeBlockItemSyntax(item: .stmt(StmtSyntax(guardStmt)))
  }

  private static func renderIf<A: Sendable>(
    condition: Template<A>,
    thenBody: [Statement<A>],
    elseBody: [Statement<A>]?
  ) -> CodeBlockItemSyntax {
    let conditionElement = ConditionElementSyntax(
      condition: .expression(render(condition))
    )

    let elseClause: IfExprSyntax.ElseBody? = elseBody.map { body in
      .codeBlock(CodeBlockSyntax(statements: renderStatements(body)))
    }

    let ifExpr = IfExprSyntax(
      conditions: ConditionElementListSyntax([conditionElement]),
      body: CodeBlockSyntax(statements: renderStatements(thenBody)),
      elseKeyword: elseBody != nil ? .keyword(.else) : nil,
      elseBody: elseClause
    )

    return CodeBlockItemSyntax(item: .expr(ExprSyntax(ifExpr)))
  }

  private static func renderReturn<A: Sendable>(expression: Template<A>?) -> CodeBlockItemSyntax {
    let returnStmt = ReturnStmtSyntax(expression: expression.map { render($0) })
    return CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
  }

  private static func renderThrow<A: Sendable>(expression: Template<A>) -> CodeBlockItemSyntax {
    let throwStmt = ThrowStmtSyntax(expression: render(expression))
    return CodeBlockItemSyntax(item: .stmt(StmtSyntax(throwStmt)))
  }

  private static func renderDefer<A: Sendable>(body: [Statement<A>]) -> CodeBlockItemSyntax {
    let deferStmt = DeferStmtSyntax(
      body: CodeBlockSyntax(statements: renderStatements(body))
    )
    return CodeBlockItemSyntax(item: .stmt(StmtSyntax(deferStmt)))
  }

  // MARK: - Guard Let Binding

  private static func renderGuardLetBinding<A: Sendable>(
    name: String,
    type: String?,
    initializer: Template<A>,
    elseBody: [Statement<A>]
  ) -> CodeBlockItemSyntax {
    let typeAnnotation: TypeAnnotationSyntax? = type.map { typeName in
      TypeAnnotationSyntax(
        type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(typeName)))
      )
    }

    let binding = OptionalBindingConditionSyntax(
      bindingSpecifier: .keyword(.let),
      pattern: PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(name))),
      typeAnnotation: typeAnnotation,
      initializer: InitializerClauseSyntax(value: render(initializer))
    )

    let conditionElement = ConditionElementSyntax(
      condition: .optionalBinding(binding)
    )

    let guardStmt = GuardStmtSyntax(
      conditions: ConditionElementListSyntax([conditionElement]),
      body: CodeBlockSyntax(statements: renderStatements(elseBody))
    )

    return CodeBlockItemSyntax(item: .stmt(StmtSyntax(guardStmt)))
  }

  // MARK: - Switch Statement

  private static func renderSwitchStatement<A: Sendable>(
    subject: Template<A>,
    cases: [SwitchCase<A>]
  ) -> CodeBlockItemSyntax {
    let switchCaseSyntaxItems: [SwitchCaseListSyntax.Element] = cases.map { switchCase in
      let caseSyntax = renderSwitchCase(switchCase)
      return SwitchCaseListSyntax.Element(caseSyntax)
    }

    let switchExpr = SwitchExprSyntax(
      subject: render(subject),
      cases: SwitchCaseListSyntax(switchCaseSyntaxItems)
    )

    return CodeBlockItemSyntax(item: .expr(ExprSyntax(switchExpr)))
  }

  private static func renderSwitchCase<A: Sendable>(_ switchCase: SwitchCase<A>) -> SwitchCaseSyntax {
    let label: SwitchCaseSyntax.Label
    switch switchCase.pattern {
    case .expression(let expr):
      let caseItem = SwitchCaseItemSyntax(
        pattern: PatternSyntax(ExpressionPatternSyntax(expression: render(expr)))
      )
      label = .case(SwitchCaseLabelSyntax(caseItems: SwitchCaseItemListSyntax([caseItem])))
    case .stringLiteral(let s):
      let strExpr = ExprSyntax(StringLiteralExprSyntax(content: s))
      let caseItem = SwitchCaseItemSyntax(
        pattern: PatternSyntax(ExpressionPatternSyntax(expression: strExpr))
      )
      label = .case(SwitchCaseLabelSyntax(caseItems: SwitchCaseItemListSyntax([caseItem])))
    case .defaultCase:
      label = .default(SwitchDefaultLabelSyntax())
    }

    return SwitchCaseSyntax(
      label: label,
      statements: renderStatements(switchCase.body)
    )
  }

  // MARK: - Assignment Statement

  private static func renderAssignmentStatement<A: Sendable>(
    lhs: Template<A>,
    rhs: Template<A>
  ) -> CodeBlockItemSyntax {
    let assignExpr = InfixOperatorExprSyntax(
      leftOperand: render(lhs),
      operator: AssignmentExprSyntax(),
      rightOperand: render(rhs)
    )
    return CodeBlockItemSyntax(item: .expr(ExprSyntax(assignExpr)))
  }
}
