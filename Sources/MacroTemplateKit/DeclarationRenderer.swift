import SwiftSyntax
import SwiftSyntaxBuilder

/// Declaration-level rendering utilities.
///
/// Provides pure functions to transform `Declaration<A>` templates into SwiftSyntax
/// declaration nodes (`DeclSyntax`). Declaration rendering is the top-level transformation
/// layer for complete Swift declarations (functions, properties, extensions, structs).
extension Renderer {
  // MARK: - Declaration Rendering

  /// Renders a Declaration to SwiftSyntax DeclSyntax.
  ///
  /// Converts declaration-level templates to complete Swift declarations. The rendering process:
  /// - Translates each Declaration case to corresponding SwiftSyntax declaration node
  /// - Handles functions, properties, computed properties, extensions, and structs
  /// - Recursively renders statement bodies and nested declarations
  ///
  /// Implemented via the source-emit-then-parse pipeline (`renderParsed(_:)`
  /// below). The per-node structural implementation this superseded is
  ///
  /// - Parameter declaration: Declaration to render
  /// - Returns: SwiftSyntax declaration node
  public static func render<A: Sendable>(_ declaration: Declaration<A>) throws -> DeclSyntax {
    try renderParsed(declaration)
  }

  /// Renders an extension signature to a concrete `ExtensionDeclSyntax`.
  ///
  /// `ExtensionMacro.expansion(...)` is required to return
  /// `[ExtensionDeclSyntax]`, not `[DeclSyntax]`. Without this entry point
  /// every extension macro has to downcast the general `render(_:)` result
  /// and force-unwrap it — pushing an unwrap that can only fail on a bug in
  /// this library into the author's macro, which is precisely the trade
  /// `RenderError` exists to avoid.
  ///
  /// - Throws: `RenderError` if the emitted source does not parse, or parses
  ///   as something other than an extension.
  public static func renderExtensionDecl<A: Sendable>(
    _ signature: ExtensionSignature<A>
  ) throws -> ExtensionDeclSyntax {
    let declaration = try render(Declaration.extensionDecl(signature))
    guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
      throw RenderError(
        kind: .declaration,
        source: declaration.description,
        diagnostics: [
          "expected an extension declaration, parsed as \(declaration.kind)"
        ]
      )
    }
    return extensionDecl
  }

  // MARK: - Private Declaration Helpers

  // MARK: - Modifier Helpers

  // MARK: - Parameter Helpers
}

extension Renderer {
  /// Renders a declaration via the source-emit-then-parse pipeline (see
  /// `Renderer.renderParsed(_: Template<A>)` in `Renderer.swift` and
  /// `Renderer.renderParsed(_: Statement<A>)` in `StatementRenderer.swift`
  /// for the same technique one and two levels down, at expression and
  /// statement granularity).
  ///
  /// `SourceEmitter` writes Swift source text for the declaration
  /// (embedding `Template`/`Statement` source text for every nested
  /// expression/statement body via `SourceEmitter+Declarations.swift`)
  /// into a buffer, which is then parsed once into a `DeclSyntax` node.
  /// This is the implementation behind the public
  /// `render(_: Declaration<A>)` entry point above; it remains a separate
  /// internal name so the token-parity suite can call it directly
  static func renderParsed<A: Sendable>(_ declaration: Declaration<A>) throws -> DeclSyntax {
    var buffer = ""
    buffer.reserveCapacity(128)
    SourceEmitter.emit(declaration, into: &buffer)
    let decl: DeclSyntax = "\(raw: buffer)"
    guard !decl.hasError else {
      throw RenderError.make(kind: .declaration, source: buffer, node: decl)
    }
    return mergeStringSegmentsIfNeeded(decl, emittedSource: buffer)
  }
}
