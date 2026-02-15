import SwiftSyntax
import SwiftSyntaxBuilder

/// Natural transformation from `Template<A>` to SwiftSyntax `ExprSyntax`.
///
/// The renderer is a pure function that converts template AST nodes into
/// SwiftSyntax expression nodes suitable for macro expansion. The type parameter `A`
/// is discarded during rendering since it represents compile-time metadata only.
///
/// This transformation is natural: it preserves the structure of the template
/// while translating to SwiftSyntax's representation.
public struct Renderer {
  /// Renders a template into SwiftSyntax expression syntax.
  ///
  /// This is a pure function with no side effects. The rendering process:
  /// - Discards type parameter `A` (metadata only)
  /// - Translates each Template case to corresponding SwiftSyntax node
  /// - Preserves expression structure and semantics
  ///
  /// - Parameter template: Template to render
  /// - Returns: SwiftSyntax expression node
  public static func render<A>(_ template: Template<A>) -> ExprSyntax {
    renderLiterals(template) ?? renderVariables(template) ?? renderControlFlow(template)
      ?? renderOperations(template) ?? renderDeclarations(template) ?? renderCollections(template)
      ?? ExprSyntax(NilLiteralExprSyntax())
  }

  // MARK: - Literal Rendering

  private static func renderLiterals<A>(_ template: Template<A>) -> ExprSyntax? {
    guard case .literal(let value) = template else { return nil }
    return renderLiteral(value)
  }

  private static func renderLiteral(_ value: LiteralValue) -> ExprSyntax {
    renderNumericLiteral(value) ?? renderStringLiteral(value) ?? renderBooleanOrNilLiteral(value)
      ?? ExprSyntax(NilLiteralExprSyntax())
  }

  private static func renderNumericLiteral(_ value: LiteralValue) -> ExprSyntax? {
    switch value {
    case .integer(let int):
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("\(int)")))
    case .double(let double):
      return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral("\(double)")))
    default:
      return nil
    }
  }

  private static func renderStringLiteral(_ value: LiteralValue) -> ExprSyntax? {
    guard case .string(let string) = value else { return nil }
    return ExprSyntax(StringLiteralExprSyntax(content: string))
  }

  private static func renderBooleanOrNilLiteral(_ value: LiteralValue) -> ExprSyntax? {
    switch value {
    case .boolean(let bool):
      return ExprSyntax(BooleanLiteralExprSyntax(bool))
    case .nil:
      return ExprSyntax(NilLiteralExprSyntax())
    default:
      return nil
    }
  }

  // MARK: - Variable Rendering

  private static func renderVariables<A>(_ template: Template<A>) -> ExprSyntax? {
    guard case .variable(let name, _) = template else { return nil }
    return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
  }

  // MARK: - Control Flow Rendering

  private static func renderControlFlow<A>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .conditional(let condition, let thenBranch, let elseBranch):
      return renderConditional(condition, thenBranch, elseBranch)
    case .loop(let variable, let collection, let body):
      return renderLoop(variable, collection, body)
    default:
      return nil
    }
  }

  private static func renderConditional<A>(
    _ condition: Template<A>,
    _ thenBranch: Template<A>,
    _ elseBranch: Template<A>
  ) -> ExprSyntax {
    ExprSyntax(
      TernaryExprSyntax(
        condition: render(condition),
        thenExpression: render(thenBranch),
        elseExpression: render(elseBranch)
      )
    )
  }

  private static func renderLoop<A>(
    _ variable: String,
    _ collection: Template<A>,
    _ body: Template<A>
  ) -> ExprSyntax {
    // Loop rendered as .forEach closure pattern (expressions can't represent for-in statements)
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: render(collection),
          name: .identifier("forEach")
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            expression: ClosureExprSyntax(
              signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                  ClosureShorthandParameterListSyntax {
                    ClosureShorthandParameterSyntax(name: .identifier(variable))
                  }
                )
              ),
              statements: CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(render(body)))
              }
            )
          )
        },
        rightParen: .rightParenToken()
      )
    )
  }

  // MARK: - Operations Rendering

  private static func renderOperations<A>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .functionCall(let function, let arguments):
      return renderFunctionCall(function, arguments)
    case .methodCall(let base, let method, let arguments):
      return renderMethodCall(base, method, arguments)
    case .binaryOperation(let left, let op, let right):
      return renderBinaryOperation(left, op, right)
    case .propertyAccess(let base, let property):
      return renderPropertyAccess(base, property)
    default:
      return nil
    }
  }

  private static func renderFunctionCall<A>(
    _ function: String,
    _ arguments: [(label: String?, value: Template<A>)]
  ) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier(function)),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          for argument in arguments {
            LabeledExprSyntax(
              label: argument.label.map { .identifier($0) },
              expression: render(argument.value)
            )
          }
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func renderMethodCall<A>(
    _ base: Template<A>,
    _ method: String,
    _ arguments: [(label: String?, value: Template<A>)]
  ) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: render(base),
          name: .identifier(method)
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          for argument in arguments {
            LabeledExprSyntax(
              label: argument.label.map { .identifier($0) },
              expression: render(argument.value)
            )
          }
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func renderBinaryOperation<A>(
    _ left: Template<A>,
    _ op: String,
    _ right: Template<A>
  ) -> ExprSyntax {
    ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: render(left),
        operator: BinaryOperatorExprSyntax(operator: .binaryOperator(op)),
        rightOperand: render(right)
      )
    )
  }

  private static func renderPropertyAccess<A>(
    _ base: Template<A>,
    _ property: String
  ) -> ExprSyntax {
    ExprSyntax(
      MemberAccessExprSyntax(
        base: render(base),
        name: .identifier(property)
      )
    )
  }

  // MARK: - Declarations Rendering

  private static func renderDeclarations<A>(_ template: Template<A>) -> ExprSyntax? {
    guard case .variableDeclaration(_, _, let initializer) = template else { return nil }
    // Limitation: Only render initializer expression (full variable declaration requires statement context)
    return render(initializer)
  }

  // MARK: - Collections Rendering

  private static func renderCollections<A>(_ template: Template<A>) -> ExprSyntax? {
    guard case .arrayLiteral(let elements) = template else { return nil }
    return ExprSyntax(
      ArrayExprSyntax(
        leftSquare: .leftSquareToken(),
        elements: ArrayElementListSyntax {
          for (index, element) in elements.enumerated() {
            ArrayElementSyntax(
              expression: render(element),
              trailingComma: index < elements.count - 1 ? .commaToken() : nil
            )
          }
        },
        rightSquare: .rightSquareToken()
      )
    )
  }
}
