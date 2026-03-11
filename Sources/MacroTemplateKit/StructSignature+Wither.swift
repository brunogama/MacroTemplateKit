extension StructSignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withName(_ name: String) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withGenericParameters(
        _ genericParameters: [GenericParameterSignature]
    ) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withConformances(_ conformances: [String]) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withMembers(_ members: [Declaration<A>]) -> Self {
        StructSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func addingMember(_ member: Declaration<A>) -> Self {
        withMembers(members + [member])
    }

    public func addingConformance(_ conformance: String) -> Self {
        withConformances(conformances + [conformance])
    }
}
