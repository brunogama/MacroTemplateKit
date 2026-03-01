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
  public static func render<A: Sendable>(_ template: Template<A>) -> ExprSyntax {
    renderLiterals(template) ?? renderVariables(template) ?? renderControlFlow(template)
      ?? renderOperations(template) ?? renderEffects(template) ?? renderDeclarations(template)
      ?? renderCollections(template) ?? renderExtensions(template) ?? ExprSyntax(NilLiteralExprSyntax())
  }

  // MARK: - Literal Rendering

  private static func renderLiterals<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
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

  private static func renderVariables<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    guard case .variable(let name, _) = template else { return nil }
    return ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
  }

  // MARK: - Control Flow Rendering

  private static func renderControlFlow<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .conditional(let condition, let thenBranch, let elseBranch):
      return renderConditional(condition, thenBranch, elseBranch)
    case .loop(let variable, let collection, let body):
      return renderLoop(variable, collection, body)
    default:
      return nil
    }
  }

  private static func renderConditional<A: Sendable>(
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

  private static func renderLoop<A: Sendable>(
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

  private static func renderOperations<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .functionCall(let function, let arguments):
      return renderFunctionCall(function, arguments)
    case .methodCall(let base, let method, let arguments):
      return renderMethodCall(base, method, arguments)
    case .binaryOperation(let left, let op, let right):
      return renderBinaryOperation(left, op, right)
    case .propertyAccess(let base, let property):
      return renderPropertyAccess(base, property)
    case .genericCall(let function, let typeArguments, let arguments):
      return renderGenericCall(function, typeArguments, arguments)
    default:
      return nil
    }
  }

  private static func renderFunctionCall<A: Sendable>(
    _ function: String,
    _ arguments: [(label: String?, value: Template<A>)]
  ) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier(function)),
        leftParen: .leftParenToken(),
        arguments: renderLabeledExprList(arguments),
        rightParen: .rightParenToken()
      )
    )
  }

  private static func renderMethodCall<A: Sendable>(
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
        arguments: renderLabeledExprList(arguments),
        rightParen: .rightParenToken()
      )
    )
  }

  private static func renderBinaryOperation<A: Sendable>(
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

  private static func renderPropertyAccess<A: Sendable>(
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

  // MARK: - Effects Rendering

  private static func renderEffects<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .tryExpression(let inner):
      return ExprSyntax(TryExprSyntax(expression: render(inner)))
    case .awaitExpression(let inner):
      return ExprSyntax(AwaitExprSyntax(expression: render(inner)))
    default:
      return nil
    }
  }

  // MARK: - Generic Call Rendering

  private static func renderGenericCall<A: Sendable>(
    _ function: String,
    _ typeArguments: [String],
    _ arguments: [(label: String?, value: Template<A>)]
  ) -> ExprSyntax {
    let genericArgs = typeArguments.map { typeArg in
      GenericArgumentSyntax(argument: .type(TypeSyntax(stringLiteral: typeArg)))
    }

    let calledExpr = ExprSyntax(GenericSpecializationExprSyntax(
      expression: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(function))),
      genericArgumentClause: GenericArgumentClauseSyntax(
        arguments: GenericArgumentListSyntax(genericArgs)
      )
    ))

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: calledExpr,
        leftParen: .leftParenToken(),
        arguments: renderLabeledExprList(arguments),
        rightParen: .rightParenToken()
      )
    )
  }

  // MARK: - Labeled Expression List Helper

  /// Renders labeled argument lists with proper colon and trailing comma tokens.
  private static func renderLabeledExprList<A: Sendable>(
    _ arguments: [(label: String?, value: Template<A>)]
  ) -> LabeledExprListSyntax {
    let exprs = arguments.enumerated().map { index, argument -> LabeledExprSyntax in
      let isLast = index == arguments.count - 1
      return LabeledExprSyntax(
        label: argument.label.map { .identifier($0) },
        colon: argument.label != nil ? .colonToken() : nil,
        expression: render(argument.value),
        trailingComma: isLast ? nil : .commaToken()
      )
    }
    return LabeledExprListSyntax(exprs)
  }

  // MARK: - Declarations Rendering

  private static func renderDeclarations<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    guard case .variableDeclaration(_, _, let initializer) = template else { return nil }
    // Limitation: Only render initializer expression (full variable declaration requires statement context)
    return render(initializer)
  }

  // MARK: - Collections Rendering

  private static func renderCollections<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .arrayLiteral(let elements):
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
    case .dictionaryLiteral(let entries):
      return renderDictionaryLiteral(entries)
    default:
      return nil
    }
  }

  private static func renderDictionaryLiteral<A: Sendable>(
    _ entries: [(key: Template<A>, value: Template<A>)]
  ) -> ExprSyntax {
    if entries.isEmpty {
      return ExprSyntax(
        DictionaryExprSyntax(content: .colon(.colonToken()))
      )
    }
    let elements = DictionaryElementListSyntax(
      entries.enumerated().map { index, entry -> DictionaryElementSyntax in
        DictionaryElementSyntax(
          key: render(entry.key),
          value: render(entry.value),
          trailingComma: index < entries.count - 1 ? .commaToken() : nil
        )
      }
    )
    return ExprSyntax(DictionaryExprSyntax(content: .elements(elements)))
  }

  // MARK: - Extension Cases Rendering

  private static func renderExtensions<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
    switch template {
    case .subscriptAccess(let base, let index):
      return renderSubscriptAccess(base, index)
    case .forceUnwrap(let expr):
      return ExprSyntax(ForceUnwrapExprSyntax(expression: render(expr)))
    case .stringInterpolation(let segments):
      return renderStringInterpolation(segments)
    case .closure(let sig):
      return renderClosure(sig)
    case .assignment(let lhs, let rhs):
      return ExprSyntax(
        InfixOperatorExprSyntax(
          leftOperand: render(lhs),
          operator: AssignmentExprSyntax(),
          rightOperand: render(rhs)
        )
      )
    case .selfAccess(let typeName):
      return ExprSyntax(
        MemberAccessExprSyntax(
          base: ExprSyntax(TypeExprSyntax(type: IdentifierTypeSyntax(name: .identifier(typeName)))),
          name: .keyword(.self)
        )
      )
    default:
      return nil
    }
  }

  private static func renderSubscriptAccess<A: Sendable>(
    _ base: Template<A>,
    _ index: Template<A>
  ) -> ExprSyntax {
    ExprSyntax(
      SubscriptCallExprSyntax(
        calledExpression: render(base),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(expression: render(index))
        ])
      )
    )
  }

  private static func renderStringInterpolation<A: Sendable>(
    _ segments: [StringInterpolationSegment<A>]
  ) -> ExprSyntax {
    let syntaxSegments = segments.map { segment -> StringLiteralSegmentListSyntax.Element in
      switch segment {
      case .text(let s):
        return .stringSegment(StringSegmentSyntax(content: .stringSegment(s)))
      case .expression(let expr):
        return .expressionSegment(
          ExpressionSegmentSyntax(
            expressions: LabeledExprListSyntax([LabeledExprSyntax(expression: render(expr))])
          )
        )
      }
    }
    return ExprSyntax(
      StringLiteralExprSyntax(
        openingQuote: .stringQuoteToken(),
        segments: StringLiteralSegmentListSyntax(syntaxSegments),
        closingQuote: .stringQuoteToken()
      )
    )
  }

  private static func renderClosure<A: Sendable>(_ sig: ClosureSignature<A>) -> ExprSyntax {
    let hasSignature = !sig.parameters.isEmpty || sig.returnType != nil

    let closureSignature: ClosureSignatureSyntax? = hasSignature
      ? buildClosureSignature(sig)
      : nil

    return ExprSyntax(
      ClosureExprSyntax(
        signature: closureSignature,
        statements: renderStatements(sig.body)
      )
    )
  }

  private static func buildClosureSignature<A: Sendable>(_ sig: ClosureSignature<A>) -> ClosureSignatureSyntax {
    let params = sig.parameters.enumerated().map { index, param -> ClosureParameterSyntax in
      let paramType: TypeSyntax? = param.type.map { typeName in
        TypeSyntax(IdentifierTypeSyntax(name: .identifier(typeName)))
      }
      return ClosureParameterSyntax(
        firstName: .identifier(param.name),
        type: paramType,
        trailingComma: index < sig.parameters.count - 1 ? .commaToken() : nil
      )
    }

    let parameterClause = ClosureParameterClauseSyntax(
      parameters: ClosureParameterListSyntax(params)
    )

    let returnClause: ReturnClauseSyntax? = sig.returnType.map { typeName in
      ReturnClauseSyntax(type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(typeName))))
    }

    return ClosureSignatureSyntax(
      parameterClause: .parameterClause(parameterClause),
      returnClause: returnClause
    )
  }
}
