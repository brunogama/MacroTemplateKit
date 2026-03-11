extension EnumSignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withName(_ name: String) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withGenericParameters(
        _ genericParameters: [GenericParameterSignature]
    ) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withConformances(_ conformances: [String]) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withCases(_ cases: [EnumCaseSignature]) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func withMembers(_ members: [Declaration<A>]) -> Self {
        EnumSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, conformances: conformances,
            whereRequirements: whereRequirements, cases: cases, members: members
        )
    }

    public func addingCase(_ enumCase: EnumCaseSignature) -> Self {
        withCases(cases + [enumCase])
    }

    public func addingMember(_ member: Declaration<A>) -> Self {
        withMembers(members + [member])
    }

    public func addingConformance(_ conformance: String) -> Self {
        withConformances(conformances + [conformance])
    }
}
