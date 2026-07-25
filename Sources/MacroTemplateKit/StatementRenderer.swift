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
  /// Implemented via the source-emit-then-parse pipeline (`renderParsed(_:)`
  /// below). The per-node structural implementation this superseded is
  ///
  /// - Parameter statement: Statement to render
  /// - Returns: SwiftSyntax code block item containing the rendered statement
  public static func render<A: Sendable>(_ statement: Statement<A>) throws -> CodeBlockItemSyntax {
    try renderParsed(statement)
  }


  /// Renders multiple statements to CodeBlockItemListSyntax.
  ///
  /// - Parameter statements: Array of statements to render
  /// - Returns: SwiftSyntax code block item list
  public static func renderStatements<A: Sendable>(
    _ statements: [Statement<A>]
  ) throws -> CodeBlockItemListSyntax {
    CodeBlockItemListSyntax(try statements.map { try render($0) })
  }


  // MARK: - Private Statement Helpers










  // MARK: - Guard Let Binding


  // MARK: - Switch Statement



  // MARK: - Assignment Statement

}

extension Renderer {
  /// Renders a statement via the source-emit-then-parse pipeline (see
  /// `Renderer.renderParsed(_: Template<A>)` in `Renderer.swift` for the same
  /// technique one level down, at expression granularity).
  ///
  /// `SourceEmitter` writes Swift source text for the statement (embedding
  /// `Template` source text for every nested expression) into a buffer,
  /// which is then parsed once into a `CodeBlockItemSyntax` node.
  /// `CodeBlockItemSyntax` has a string-interpolation initializer in
  /// swift-syntax 603.0.2, so no `CodeBlockItemListSyntax(...).first!`
  /// fallback is needed here. This is the implementation behind the public
  /// `render(_: Statement<A>)` entry point above, kept under a separate
  /// internal name so tests can call it without going through `try`-wrapping
  /// at every call site.
  static func renderParsed<A: Sendable>(_ statement: Statement<A>) throws -> CodeBlockItemSyntax {
    var buffer = ""
    SourceEmitter.emit(statement, into: &buffer)
    let item = CodeBlockItemSyntax("\(raw: buffer)")
    guard !item.hasError else {
      throw RenderError.make(kind: .statement, source: buffer, node: item)
    }
    guard mightNeedSegmentMerge(buffer) else { return item }
    return StringSegmentMerger().visit(item)
  }
}
