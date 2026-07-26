import SwiftSyntax

func makeAdvancedDeclaration() throws -> DeclSyntax {
    let signature = FunctionSignature<Void>(
        accessLevel: .public,
        attributes: [.mainActor],
        name: "register",
        genericParameters: [
            GenericParameterSignature(name: "Service", constraint: "Sendable"),
            GenericParameterSignature(name: "Dependency", isParameterPack: true),
        ],
        parameters: [
            ParameterSignature(label: "_", name: "service", type: "Service"),
            ParameterSignature(name: "dependencies", type: "repeat each Dependency"),
        ],
        whereRequirements: [
            .sameType("Service.ID", "String"),
            .conformance("each Dependency", "Sendable"),
        ],
        body: []
    )
    let callbackParameter = ParameterSignature<Void>(
        name: "handler",
        type: "() -> Void",
        attributes: [.escaping]
    )

    return try Renderer.render(
        Declaration.function(
            FunctionSignature(
                accessLevel: signature.accessLevel,
                attributes: signature.attributes,
                name: signature.name,
                genericParameters: signature.genericParameters,
                parameters: signature.parameters + [callbackParameter],
                whereRequirements: signature.whereRequirements,
                body: signature.body
            )
        )
    )
}
