extension InitializerSignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withIsFailable(_ isFailable: Bool) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withGenericParameters(
        _ genericParameters: [GenericParameterSignature]
    ) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withParameters(_ parameters: [ParameterSignature]) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withCanThrow(_ canThrow: Bool) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func withBody(_ body: [Statement<A>]) -> Self {
        InitializerSignature(
            accessLevel: accessLevel, attributes: attributes, isFailable: isFailable,
            genericParameters: genericParameters, parameters: parameters,
            canThrow: canThrow, whereRequirements: whereRequirements, body: body
        )
    }

    public func addingParameter(_ parameter: ParameterSignature) -> Self {
        withParameters(parameters + [parameter])
    }

    public func removingParameter(named name: String) -> Self {
        withParameters(parameters.filter { $0.name != name })
    }
}
