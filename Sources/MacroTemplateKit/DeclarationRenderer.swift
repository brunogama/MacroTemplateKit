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
        SourceEmitter.emit(declaration, into: &buffer)
        let decl: DeclSyntax = "\(raw: buffer)"
        guard !decl.hasError else {
            throw RenderError.make(kind: .declaration, source: buffer, node: decl)
        }
        guard mightNeedSegmentMerge(buffer) else { return decl }
        return StringSegmentMerger().visit(decl)
    }
}
