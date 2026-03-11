extension FunctionSignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withIsStatic(_ isStatic: Bool) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withIsMutating(_ isMutating: Bool) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withName(_ name: String) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withGenericParameters(
        _ genericParameters: [GenericParameterSignature]
    ) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withParameters(_ parameters: [ParameterSignature]) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withIsAsync(_ isAsync: Bool) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withCanThrow(_ canThrow: Bool) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withReturnType(_ returnType: String?) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func withBody(_ body: [Statement<A>]) -> Self {
        FunctionSignature(
            accessLevel: accessLevel, attributes: attributes, isStatic: isStatic,
            isMutating: isMutating, name: name, genericParameters: genericParameters,
            parameters: parameters, isAsync: isAsync, canThrow: canThrow,
            returnType: returnType, whereRequirements: whereRequirements, body: body
        )
    }

    public func addingParameter(_ parameter: ParameterSignature) -> Self {
        withParameters(parameters + [parameter])
    }

    public func removingParameter(named name: String) -> Self {
        withParameters(parameters.filter { $0.name != name })
    }

    public func addingAttribute(_ attribute: AttributeSignature) -> Self {
        withAttributes(attributes + [attribute])
    }
}
