let declaration: DeclSyntax = Renderer.render(
  Declaration.function(
    FunctionSignature(
      accessLevel: .public,
      name: "loadUser",
      parameters: [
        ParameterSignature(label: "with", name: "id", type: "String")
      ],
      isAsync: true,
      canThrow: true,
      returnType: "User",
      body: [
        .letBinding(name: "data", type: nil, initializer: fetchUser),
        .returnStatement(
          .call(
            "User",
            arguments: [
              .labeled("from", .variable("data"))
            ]
          )
        ),
      ]
    )
  )
)
