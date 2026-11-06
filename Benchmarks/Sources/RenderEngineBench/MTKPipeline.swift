import MacroTemplateKit
import SwiftSyntax

/// Builds the expansion out of MacroTemplateKit values.
///
/// Each computed property is expressed as a single `Declaration` and rendered
/// in **one** call; its accessors are then read back out. Because they come
/// from one parse they share a single syntax arena, which is what keeps
/// retained memory down — the renderer's cost is dominated by the *number* of
/// render calls, not by total output size.
///
/// An earlier version of this pipeline rendered leaf expressions one at a time
/// and assembled the surrounding accessors with handwritten SwiftSyntax, at
/// three renders per property. That was not a style choice: until
/// `Template.cast` and the bare `set { }` form existed, the kit could not
/// express `_storage["name", default: x] as! Type` at all. Both gaps are now
/// closed, so the pipeline measures idiomatic usage rather than a workaround.
struct MTKPipeline: ASTGeneratorPipeline, StaticStorageExperimentPipeline {
    static let name = "mtk"
    static let summary = "MacroTemplateKit templates, one render per whole computed property"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: renderMTKStorageMember(),
            accessors: properties.flatMap(makeMTKAccessors(for:))
        )
    }
}
