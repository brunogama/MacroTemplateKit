extension ComputedPropertySignature {
    public func withAccessLevel(_ accessLevel: AccessLevel) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withAttributes(_ attributes: [AttributeSignature]) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withName(_ name: String) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withType(_ type: String) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withIsStatic(_ isStatic: Bool) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withGetter(_ getter: [Statement<A>]) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }

    public func withSetter(_ setter: SetterSignature<A>?) -> Self {
        ComputedPropertySignature(
            accessLevel: accessLevel, attributes: attributes, name: name,
            type: type, isStatic: isStatic, getter: getter, setter: setter
        )
    }
}
