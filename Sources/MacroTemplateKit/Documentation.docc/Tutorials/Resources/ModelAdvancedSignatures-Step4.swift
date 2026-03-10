let declaration: DeclSyntax = Renderer.render(
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
