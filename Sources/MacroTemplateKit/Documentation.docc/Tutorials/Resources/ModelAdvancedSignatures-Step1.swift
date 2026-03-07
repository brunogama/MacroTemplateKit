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
