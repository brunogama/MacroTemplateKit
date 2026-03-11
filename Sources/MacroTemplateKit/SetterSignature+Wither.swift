extension SetterSignature {
    public func withParameterName(_ parameterName: String) -> Self {
        SetterSignature(parameterName: parameterName, body: body)
    }

    public func withBody(_ body: [Statement<A>]) -> Self {
        SetterSignature(parameterName: parameterName, body: body)
    }
}
