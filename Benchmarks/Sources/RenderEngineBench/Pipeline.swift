import SwiftSyntax

/// One stored property extracted from the fixture struct.
///
/// Extraction is shared across pipelines so the benchmark isolates the
/// *generation* stage — the switchable part — rather than mixing in
/// differences in how each variant reads the input tree.
struct StoredProperty {
    let name: String
    let type: TypeSyntax
    let defaultValue: ExprSyntax
}

/// Everything a DictionaryStorage-style expansion produces for one struct:
/// the `_storage` backing member plus a getter/setter pair per stored property.
struct ExpansionOutput {
    var storageMember: DeclSyntax
    var accessors: [AccessorDeclSyntax]
}

/// A switchable AST-generation strategy.
///
/// Every pipeline receives the same extracted input and must produce
/// token-equivalent output; only the construction technique differs.
protocol ASTGeneratorPipeline {
    /// Short identifier used on the command line and in result tables.
    static var name: String { get }
    /// Which claim from the research report this variant exercises.
    static var summary: String { get }

    init()
    func expand(properties: [StoredProperty]) -> ExpansionOutput
}

/// `var _storage: [String: Any] = [:]` built with raw SwiftSyntax
/// initializers — the one structural builder shared by every site that needs
/// the storage member as a node (the structural generate pipeline and both
/// edit pipelines).
func storageVariableDecl() -> VariableDeclSyntax {
    let dictionaryType = DictionaryTypeSyntax(
        key: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String"))),
        colon: .colonToken(trailingTrivia: .space),
        value: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Any")))
    )
    let binding = PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier("_storage")),
        typeAnnotation: TypeAnnotationSyntax(
            colon: .colonToken(trailingTrivia: .space),
            type: TypeSyntax(dictionaryType),
            trailingTrivia: .space
        ),
        initializer: InitializerClauseSyntax(
            equal: .equalToken(trailingTrivia: .space),
            value: DictionaryExprSyntax(content: .colon(.colonToken()))
        )
    )
    return VariableDeclSyntax(
        bindingSpecifier: .keyword(.var, trailingTrivia: .space),
        bindings: PatternBindingListSyntax([binding])
    )
}

/// Extracts stored properties (`var name: Type = default`) from a struct
/// using targeted typed accessors — the O(members) direct-access style the
/// research recommends (technique #3). Runs inside the timed region because
/// a real macro pays this cost on every expansion.
func extractStoredProperties(from structDecl: StructDeclSyntax) -> [StoredProperty] {
    structDecl.memberBlock.members.compactMap { member -> StoredProperty? in
        guard
            let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil,
            let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            name != "_storage",
            let type = binding.typeAnnotation?.type,
            let defaultValue = binding.initializer?.value
        else {
            return nil
        }
        return StoredProperty(name: name, type: type, defaultValue: defaultValue)
    }
}
