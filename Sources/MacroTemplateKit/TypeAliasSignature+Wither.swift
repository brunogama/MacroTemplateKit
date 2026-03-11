extension TypeAliasSignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }

    public func withName(_ name: String) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }

    public func withGenericParameters(
        _ genericParameters: [GenericParameterSignature]
    ) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }

    public func withExistingType(_ existingType: String) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }

    public func withWhereRequirements(
        _ whereRequirements: [WhereRequirement]
    ) -> Self {
        TypeAliasSignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            genericParameters: genericParameters, existingType: existingType,
            whereRequirements: whereRequirements
        )
    }
}
