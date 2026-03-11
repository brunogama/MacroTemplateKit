extension PropertySignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withName(_ name: String) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withType(_ type: String?) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withIsStatic(_ isStatic: Bool) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withIsLet(_ isLet: Bool) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }

    public func withInitializer(_ initializer: Template<A>?) -> Self {
        PropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, isLet: isLet, initializer: initializer
        )
    }
}
