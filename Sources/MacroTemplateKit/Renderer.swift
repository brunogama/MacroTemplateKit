import Foundation
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
    @available(
    *, unavailable, message: "Renderer cannot be instantiated; use static methods instead."
    )
    public init() {}

    /// Renders a template into SwiftSyntax expression syntax.
    ///
    /// This is a pure function with no side effects. The rendering process:
    /// - Discards type parameter `A` (metadata only)
    /// - Translates each Template case to corresponding SwiftSyntax node
    /// - Preserves expression structure and semantics
    ///
    /// Implemented via the source-emit-then-parse pipeline (`renderParsed(_:)`
    /// below): `SourceEmitter` writes Swift source text for `template` into a
    /// buffer, which is parsed once into the returned `ExprSyntax` node. The
    /// per-node structural implementation this superseded is retained as
    /// `legacyRender(_:)` for token-parity testing.
    ///
    /// - Parameter template: Template to render
    /// - Returns: SwiftSyntax expression node
    public static func render<A: Sendable>(_ template: Template<A>) throws -> ExprSyntax {
        try renderParsed(template)
    }

    /// Legacy per-node structural implementation that `render(_: Template<A>)`
    /// used before the source-emit-then-parse pipeline replaced it, retained
    /// side-by-side for token-parity testing. Not reachable from the public
    /// API; scheduled for removal once the parity suite is retired.
    static func legacyRender<A: Sendable>(_ template: Template<A>) -> ExprSyntax {
        renderLiterals(template) ?? renderVariables(template) ?? renderControlFlow(template)
            ?? renderOperations(template) ?? renderEffects(template) ?? renderDeclarations(template)
            ?? renderCollections(template) ?? renderExtensions(template)
            ?? ExprSyntax(NilLiteralExprSyntax())
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
                condition: legacyRender(condition, parenthesizedInside: .ternary, on: .left),
                thenExpression: legacyRender(thenBranch),
                elseExpression: legacyRender(elseBranch)
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
                    base: legacyRender(collection),
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
                                CodeBlockItemSyntax(item: .expr(legacyRender(body)))
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
                    base: legacyRender(base),
                    name: .identifier(method)
                ),
                leftParen: .leftParenToken(),
                arguments: renderLabeledExprList(arguments),
                rightParen: .rightParenToken()
            )
        )
    }

    /// Whether `name` is a bare Swift identifier, and therefore safe to turn
    /// into a token without parsing it first.
    ///
    /// `.variable` doubles as the kit's raw-source escape hatch — callers pass
    /// things like `".success(let value)"` through it — so the fast path must
    /// not assume its contents are an identifier. Anything else returns false,
    /// falls through to emit-and-parse, and is validated by the parse gate
    /// there. That keeps the optimisation from becoming a hole in the gate.
    private static func isPlainIdentifier(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        guard first == "_" || CharacterSet.letters.contains(first) else { return false }
        return name.unicodeScalars.dropFirst().allSatisfy {
            $0 == "_" || CharacterSet.alphanumerics.contains($0)
        }
    }

    /// Builds the handful of templates whose syntax is a single token, without
    /// going through the parser. Returns `nil` for everything else, which then
    /// takes the emit-and-parse path.
    ///
    /// Restricted to cases whose structural construction is unambiguously
    /// identical to what parsing the same text yields — identifiers and the
    /// simple literals. Anything requiring escaping decisions (strings), or any
    /// composite, is left to the parser rather than duplicated here, so the two
    /// paths cannot drift.
    private static func renderLeaf<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
        switch template {
        case .syntax(let node):
            node
        case .variable(let name, _) where isPlainIdentifier(name):
            ExprSyntax(
                DeclReferenceExprSyntax(baseName: .identifier(SourceEmitter.escapeIdentifier(name)))
            )
        case .literal(.integer(let value)):
            ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral(String(value))))
        case .literal(.boolean(let value)):
            ExprSyntax(BooleanLiteralExprSyntax(literal: .keyword(value ? .true : .false)))
        case .literal(.nil):
            ExprSyntax(NilLiteralExprSyntax())
        default:
            nil
        }
    }

    /// Renders `template` as an operand of an enclosing operator, wrapping it
    /// in a tuple expression when omitting parentheses would change how the
    /// result parses. Mirrors `SourceEmitter.emit(_:parenthesizedInside:on:)`
    /// so the two paths stay token-identical.
    private static func legacyRender<A: Sendable>(
        _ template: Template<A>,
        parenthesizedInside parent: Precedence,
        on side: Template<A>.Side
    ) -> ExprSyntax {
        let rendered = legacyRender(template)
        guard template.needsParentheses(inside: parent, on: side) else { return rendered }
        return ExprSyntax(
            TupleExprSyntax(
                elements: LabeledExprListSyntax([LabeledExprSyntax(expression: rendered)])
            )
        )
    }

    private static func renderBinaryOperation<A: Sendable>(
        _ left: Template<A>,
        _ op: Operator,
        _ right: Template<A>
    ) -> ExprSyntax {
        let parent = op.effectivePrecedence
        return ExprSyntax(
            InfixOperatorExprSyntax(
                leftOperand: legacyRender(left, parenthesizedInside: parent, on: .left),
                operator: BinaryOperatorExprSyntax(operator: .binaryOperator(op.text)),
                rightOperand: legacyRender(right, parenthesizedInside: parent, on: .right)
            )
        )
    }

    private static func renderPropertyAccess<A: Sendable>(
        _ base: Template<A>,
        _ property: String
    ) -> ExprSyntax {
        ExprSyntax(
            MemberAccessExprSyntax(
                base: legacyRender(base),
                name: .identifier(property)
            )
        )
    }

    // MARK: - Effects Rendering

    private static func renderEffects<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
        switch template {
        case .tryExpression(let inner):
            return ExprSyntax(TryExprSyntax(expression: legacyRender(inner)))
        case .awaitExpression(let inner):
            return ExprSyntax(AwaitExprSyntax(expression: legacyRender(inner)))
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

        let calledExpr = ExprSyntax(
            GenericSpecializationExprSyntax(
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
                expression: legacyRender(argument.value),
                trailingComma: isLast ? nil : .commaToken()
            )
        }
        return LabeledExprListSyntax(exprs)
    }

    // MARK: - Declarations Rendering

    private static func renderDeclarations<A: Sendable>(_ template: Template<A>) -> ExprSyntax? {
        guard case .variableDeclaration(_, _, let initializer) = template else { return nil }
        // Limitation: Only render initializer expression (full variable declaration requires statement context)
        return legacyRender(initializer)
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
                                expression: legacyRender(element),
                                trailingComma: index < elements.count - 1 ? .commaToken() : nil
                            )
                        }
                    },
                    rightSquare: .rightSquareToken()
                )
            )
        case .tupleLiteral(let elements):
            return Renderer.renderTupleLiteral(elements)
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
                    key: legacyRender(entry.key),
                    value: legacyRender(entry.value),
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
        case .subscriptCall(let base, let arguments):
            return Renderer.renderSubscriptCall(base, arguments)
        case .forceUnwrap(let expr):
            return ExprSyntax(ForceUnwrapExprSyntax(expression: legacyRender(expr)))
        case .syntax(let node):
            return node
        case .cast(let expr, let type, let kind):
            let castOperand = legacyRender(expr, parenthesizedInside: .casting, on: .left)
            // Trivia is explicit here: the `?`/`!` binds tight to `as`, and the
            // space before the type hangs off whichever token comes last.
            let mark: TokenSyntax? =
                switch kind {
                case .coerce: nil
                case .conditional: .postfixQuestionMarkToken(trailingTrivia: .space)
                case .forced: .exclamationMarkToken(trailingTrivia: .space)
                }
            return ExprSyntax(
                AsExprSyntax(
                    expression: castOperand,
                    asKeyword: .keyword(
                        .as,
                        leadingTrivia: .space,
                        trailingTrivia: mark == nil ? .space : []
                    ),
                    questionOrExclamationMark: mark,
                    type: TypeSyntax(stringLiteral: type)
                )
            )
        case .stringInterpolation(let segments):
            return renderStringInterpolation(segments)
        case .closure(let sig):
            return renderClosure(sig)
        case .assignment(let lhs, let rhs):
            return ExprSyntax(
                InfixOperatorExprSyntax(
                    leftOperand: legacyRender(lhs),
                    operator: AssignmentExprSyntax(),
                    rightOperand: legacyRender(rhs)
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
                calledExpression: legacyRender(base),
                arguments: LabeledExprListSyntax([
                    LabeledExprSyntax(expression: legacyRender(index))
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
                        expressions: LabeledExprListSyntax([LabeledExprSyntax(expression: legacyRender(expr))])
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
        let hasSignature = !sig.attributes.isEmpty || !sig.parameters.isEmpty || sig.returnType != nil

        let closureSignature: ClosureSignatureSyntax? =
            hasSignature
            ? buildClosureSignature(sig)
            : nil

        return ExprSyntax(
            ClosureExprSyntax(
                signature: closureSignature,
                statements: legacyRenderStatements(sig.body)
            )
        )
    }

    private static func buildClosureSignature<A: Sendable>(_ sig: ClosureSignature<A>)
    -> ClosureSignatureSyntax
    {
        let params = sig.parameters.enumerated().map { index, param -> ClosureParameterSyntax in
            let paramType: TypeSyntax? = param.type.map { typeName in
                TypeSyntax(stringLiteral: typeName)
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
            ReturnClauseSyntax(type: TypeSyntax(stringLiteral: typeName))
        }

        return ClosureSignatureSyntax(
            attributes: renderAttributes(sig.attributes),
            parameterClause: .parameterClause(parameterClause),
            returnClause: returnClause
        )
    }
}

extension Renderer {
    fileprivate static func renderTupleLiteral<A: Sendable>(_ elements: [Template<A>]) -> ExprSyntax {
        ExprSyntax(
            TupleExprSyntax(
                elements: LabeledExprListSyntax(
                    elements.enumerated().map { index, element in
                        LabeledExprSyntax(
                            expression: legacyRender(element),
                            trailingComma: index < elements.count - 1 ? .commaToken() : nil
                        )
                    }
                )
            )
        )
    }

    fileprivate static func renderSubscriptCall<A: Sendable>(
        _ base: Template<A>,
        _ arguments: [(label: String?, value: Template<A>)]
    ) -> ExprSyntax {
        let renderedArguments = LabeledExprListSyntax(
            arguments.enumerated().map { index, argument in
                let isLast = index == arguments.count - 1
                return LabeledExprSyntax(
                    label: argument.label.map { .identifier($0) },
                    colon: argument.label != nil ? .colonToken(trailingTrivia: .space) : nil,
                    expression: legacyRender(argument.value),
                    trailingComma: isLast ? nil : .commaToken(trailingTrivia: .space)
                )
            }
        )

        return ExprSyntax(
            SubscriptCallExprSyntax(
                calledExpression: legacyRender(base),
                arguments: renderedArguments
            )
        )
    }

}

extension Renderer {
    /// Renders a template via the source-emit-then-parse pipeline.
    ///
    /// `SourceEmitter` writes Swift source text into a buffer, which is then
    /// parsed once into an `ExprSyntax` node. This is the implementation
    /// behind the public `render(_: Template<A>)` entry point above; it
    /// remains a separate internal name so the token-parity suite can call it
    /// directly alongside `legacyRender(_:)`.
    static func renderParsed<A: Sendable>(_ template: Template<A>) throws -> ExprSyntax {
        // Leaves bypass the parser entirely. A parse allocates a
        // `RawSyntaxArena` that the returned node keeps alive, so the renderer's
        // cost is driven by how many times it is called, not by how much output
        // it produces — rendering a bare identifier is otherwise as expensive as
        // rendering a whole declaration. Building these structurally keeps a
        // caller who renders leaf expressions in a loop off that cliff.
        if let leaf = renderLeaf(template) { return leaf }

        var buffer = ""
        SourceEmitter.emit(template, into: &buffer)
        let expr: ExprSyntax = "\(raw: buffer)"
        guard !expr.hasError else {
            throw RenderError.make(kind: .expression, source: buffer, node: expr)
        }
        guard mightNeedSegmentMerge(buffer) else { return expr }
        return StringSegmentMerger().visit(expr)
    }

    /// Reports whether `buffer` could contain a Swift string-literal escape
    /// that forces SwiftParser to split a string literal into multiple
    /// `stringSegment` tokens (see `StringSegmentMerger`'s doc comment for
    /// why only escaped `\n`/`\r` trigger this). Used to skip the merger's
    /// full-tree `SyntaxRewriter` walk on the overwhelmingly common case
    /// where it would be a guaranteed no-op.
    ///
    /// Scans for a `\` followed by zero or more `#` and then `n` or `r` —
    /// exactly the escape spelling `escapeStringLiteral` emits for `\n`/`\r`,
    /// for any raw-string pound count. Deliberately conservative: a rare
    /// coincidental match (e.g. literal, non-escape text inside a raw string
    /// that happens to look like `\##n`) only costs an unnecessary merger
    /// pass, never a skipped one — false positives are acceptable, false
    /// negatives are not.
    // Internal rather than private: `Renderer.renderParsed(_: Statement<A>)`
    // (`StatementRenderer.swift`) reuses this same scan rather than
    // duplicating it, since a `Statement` buffer embeds `Template` source
    // text via `SourceEmitter.emit(_: Template<A>, into:)` and is therefore
    // just as susceptible to the escaped-newline segment-splitting quirk
    // documented on `StringSegmentMerger` below.
    static func mightNeedSegmentMerge(_ buffer: String) -> Bool {
        var previousWasBackslash = false
        for scalar in buffer.unicodeScalars {
            if previousWasBackslash {
                if scalar == "#" { continue }
                if scalar == "n" || scalar == "r" { return true }
            }
            previousWasBackslash = (scalar == "\\")
        }
        return false
    }
}

/// Compensates for a SwiftParser lexer behavior that `StringLiteralExprSyntax`'s
/// `content:` convenience initializer does not replicate: re-lexing a string
/// literal whose content contains an escaped `\n` or `\r` always splits the
/// literal into multiple `stringSegment` tokens at each escape (SwiftParser's
/// `Cursor.lexInStringLiteral`, unconditionally — not just for multiline string
/// literals), whereas `StringLiteralExprSyntax(content:)` always builds a single
/// segment token for the whole content. Left uncorrected, parsing
/// `SourceEmitter`'s buffer would produce more tokens than the structural
/// renderer for any string containing a newline or carriage return, breaking
/// token parity for a purely lexical reason with no semantic difference. This
/// rewriter merges consecutive plain `.stringSegment` elements back into one
/// (leaving `.expressionSegment` interpolation segments untouched), restoring
/// parity with the structural renderer's convention.
///
/// Internal rather than private so `TemplateEmitterParityTests` can exercise
/// it directly for interpolation-adjacent segment boundaries: `SourceEmitter`
/// does not emit `Template.stringInterpolation` yet (pending Task 3), so
/// `Renderer.renderParsed(_:)` cannot be used to reach that case today.
final class StringSegmentMerger: SyntaxRewriter {
    override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
        let rewritten = super.visit(node)
        guard let literal = rewritten.as(StringLiteralExprSyntax.self) else { return rewritten }

        var merged: [StringLiteralSegmentListSyntax.Element] = []
        for segment in literal.segments {
            if case .stringSegment(let current) = segment,
                let lastIndex = merged.indices.last,
                case .stringSegment(let previous) = merged[lastIndex]
            {
                merged[lastIndex] = .stringSegment(
                    previous.with(\.content, .stringSegment(previous.content.text + current.content.text))
                )
            } else {
                merged.append(segment)
            }
        }
        return ExprSyntax(literal.with(\.segments, StringLiteralSegmentListSyntax(merged)))
    }
}
