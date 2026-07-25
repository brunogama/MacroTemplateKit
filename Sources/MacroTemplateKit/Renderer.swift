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
    /// per-node structural implementation this superseded has been removed;
    /// output is now pinned by the golden token streams in `GoldenStreamTests`.
    ///
    /// - Parameter template: Template to render
    /// - Returns: SwiftSyntax expression node
    public static func render<A: Sendable>(_ template: Template<A>) throws -> ExprSyntax {
        try renderParsed(template)
    }

    // MARK: - Literal Rendering

    // MARK: - Variable Rendering

    // MARK: - Control Flow Rendering

    // MARK: - Operations Rendering

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

    // MARK: - Effects Rendering

    // MARK: - Generic Call Rendering

    // MARK: - Labeled Expression List Helper

    // MARK: - Declarations Rendering

    // MARK: - Collections Rendering

    // MARK: - Extension Cases Rendering

}

extension Renderer {

}

extension Renderer {
    /// Renders a template via the source-emit-then-parse pipeline.
    ///
    /// `SourceEmitter` writes Swift source text into a buffer, which is then
    /// parsed once into an `ExprSyntax` node. This is the implementation
    /// behind the public `render(_: Template<A>)` entry point above; it
    /// remains a separate internal name so the token-parity suite can call it
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
    ///
    /// Internal rather than private: `Renderer.renderParsed(_: Statement<A>)`
    /// (`StatementRenderer.swift`) reuses this same scan rather than
    /// duplicating it, since a `Statement` buffer embeds `Template` source
    /// text via `SourceEmitter.emit(_: Template<A>, into:)` and is therefore
    /// just as susceptible to the escaped-newline segment-splitting quirk
    /// documented on `StringSegmentMerger` below.
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
