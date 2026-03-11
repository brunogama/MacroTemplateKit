extension ExtensionSignature {
    public func withTypeName(_ typeName: String) -> Self {
        ExtensionSignature(
            typeName: typeName, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withConformances(_ conformances: [String]) -> Self {
        ExtensionSignature(
            typeName: typeName, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        ExtensionSignature(
            typeName: typeName, conformances: conformances,
            whereRequirements: whereRequirements, members: members
        )
    }

    public func withMembers(_ members: [Declaration<A>]) -> Self {
        ExtensionSignature(
            typeName: typeName, conformances: conformances,
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
