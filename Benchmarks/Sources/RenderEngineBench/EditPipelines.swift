import SwiftSyntax

/// The edit-shaped workload: make one small change (inject a `_storage`
/// member) into an existing, arbitrarily large struct. This is the scenario
/// the research's bottleneck #6 actually describes — the generation workload
/// cannot test it, because there the whole output is new syntax.
protocol TreeEditPipeline {
    static var name: String { get }
    static var summary: String { get }

    init()
    /// Returns the whole edited struct.
    func edit(_ structDecl: StructDeclSyntax) -> DeclSyntax
}

private func structuralStorageMember() -> MemberBlockItemSyntax {
    MemberBlockItemSyntax(decl: storageVariableDecl())
}

/// Research technique #5/#6 recommendation: a targeted structural edit with
/// `with(_:_:)`. Only the changed path (members list → member block → struct)
/// is reallocated; every unchanged subtree is shared with the input.
struct WithEditPipeline: TreeEditPipeline {
    static let name = "with-edit"
    static let summary = "Targeted with(_:_:) structural edit; unchanged subtrees shared"

    func edit(_ structDecl: StructDeclSyntax) -> DeclSyntax {
        var updatedMembers = structDecl.memberBlock.members
        updatedMembers.append(structuralStorageMember())
        return DeclSyntax(structDecl.with(\.memberBlock.members, updatedMembers))
    }
}

/// Research technique #4: a SyntaxRewriter that returns every node unchanged
/// except the one members list it modifies. Walks the whole tree, but the
/// rewriter's identity check means unchanged subtrees are never reallocated.
struct RewriterEditPipeline: TreeEditPipeline {
    static let name = "rewriter"
    static let summary = "SyntaxRewriter full walk; relies on structural sharing for unchanged nodes"

    private final class StorageInjector: SyntaxRewriter {
        override func visit(_ node: MemberBlockItemListSyntax) -> MemberBlockItemListSyntax {
            var updated = node
            updated.append(structuralStorageMember())
            return updated
        }
    }

    func edit(_ structDecl: StructDeclSyntax) -> DeclSyntax {
        let rewritten = StorageInjector(viewMode: .sourceAccurate).rewrite(structDecl)
        return DeclSyntax(rewritten.as(StructDeclSyntax.self)!)
    }
}

// The roundtrip-reparse negative control (bottleneck #6) was removed after
// delivering its verdict — see README.md and git history.
