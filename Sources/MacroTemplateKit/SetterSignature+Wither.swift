extension SetterSignature {
  /// Sets an explicit setter parameter name (`set(rawValue) { ... }`).
  ///
  /// Pass `nil` to drop back to the bare `set { ... }` form.
  public func withParameterName(_ parameterName: String?) -> Self {
    SetterSignature(parameterName: parameterName, body: body)
  }

  public func withBody(_ body: [Statement<A>]) -> Self {
    SetterSignature(parameterName: parameterName, body: body)
  }
}
