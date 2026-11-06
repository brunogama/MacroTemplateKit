import MacroTemplateKit
import SwiftSyntax

/// Marks generate-workload variants that differ only in invariant storage
/// materialization and must preserve its non-EOF source exactly.
protocol StaticStorageExperimentPipeline {}

/// Renders the invariant member through the normal MacroTemplateKit path.
///
/// The hybrid experiment keeps this work separate from the input-dependent
/// accessors so each pipeline differs at exactly one construction boundary.
func renderMTKStorageMember() -> DeclSyntax {
    renderBenchmarkDeclaration(
        Declaration<Void>.property(
            PropertySignature(
                name: "_storage",
                type: "[String: Any]",
                isLet: false,
                initializer: .dictionaryLiteral([])
            )
        )
    )
}

func renderBenchmarkDeclaration(_ declaration: Declaration<Void>) -> DeclSyntax {
    do {
        return try Renderer.render(declaration)
    } catch {
        fatalError("benchmark declaration was invalid: \(error)")
    }
}

/// Renders one computed property's accessor pair in a single declaration
/// parse, then returns the two accessors as syntax nodes.
func makeMTKAccessors(for property: StoredProperty) -> [AccessorDeclSyntax] {
    let typeName = property.type.trimmedDescription
    let storageLookup = Template<Void>.cast(
        .subscriptCall(
            base: .variable("_storage"),
            arguments: [
                (label: nil, value: .literal(.string(property.name))),
                (label: "default", value: .syntax(property.defaultValue)),
            ]
        ),
        type: typeName,
        kind: .forced
    )
    let assignment = Statement<Void>.assignmentStatement(
        lhs: .subscriptAccess(
            base: .variable("_storage"),
            index: .literal(.string(property.name))
        ),
        rhs: .variable("newValue")
    )
    let declaration = Declaration<Void>.computedProperty(
        ComputedPropertySignature(
            name: property.name,
            type: typeName,
            getter: [.expression(storageLookup)],
            setter: SetterSignature(body: [assignment])
        )
    )
    let rendered = renderBenchmarkDeclaration(declaration)
    guard
        let variable = rendered.as(VariableDeclSyntax.self),
        let accessorBlock = variable.bindings.first?.accessorBlock,
        case .accessors(let list) = accessorBlock.accessors
    else {
        fatalError("mtk: rendered declaration was not a computed property")
    }
    return Array(list)
}

/// Caches a MacroTemplateKit-rendered invariant member while retaining the
/// normal dynamic accessor path.
struct MTKStaticRenderedPipeline: ASTGeneratorPipeline, StaticStorageExperimentPipeline {
    static let name = "mtk-static-rendered"
    static let summary = "Cached MacroTemplateKit storage member; dynamic accessors render normally"

    private static let storageMember = renderMTKStorageMember()

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember,
            accessors: properties.flatMap(makeMTKAccessors(for:))
        )
    }
}

/// Reconstructs the invariant member with a generated SwiftSyntax factory on
/// every expansion while retaining the normal dynamic accessor path.
struct ExpectedStaticFactoryPipeline: ASTGeneratorPipeline, StaticStorageExperimentPipeline {
    static let name = "expected-static-factory"
    static let summary = "Generated storage factory per expansion; dynamic accessors render normally"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: makeGeneratedStorageMember(),
            accessors: properties.flatMap(makeMTKAccessors(for:))
        )
    }
}

/// Reuses one generated invariant member for the life of the benchmark process
/// while retaining the normal dynamic accessor path.
struct ExpectedStaticCachedPipeline: ASTGeneratorPipeline, StaticStorageExperimentPipeline {
    static let name = "expected-static-cached"
    static let summary = "Cached generated storage member; dynamic accessors render normally"

    private static let storageMember = makeGeneratedStorageMember()

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Self.storageMember,
            accessors: properties.flatMap(makeMTKAccessors(for:))
        )
    }
}
