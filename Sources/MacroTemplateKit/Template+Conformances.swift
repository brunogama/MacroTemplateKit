// MARK: - Protocol Conformances

extension Template: Equatable where A: Equatable {
  public static func == (lhs: Template<A>, rhs: Template<A>) -> Bool {
    equalLiterals(lhs, rhs) || equalVariables(lhs, rhs) || equalControlFlow(lhs, rhs)
      || equalOperations(lhs, rhs) || equalDeclarations(lhs, rhs) || equalCollections(lhs, rhs)
  }

  private static func equalLiterals(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    guard case .literal(let lhsValue) = lhs, case .literal(let rhsValue) = rhs else { return false }
    return lhsValue == rhsValue
  }

  private static func equalVariables(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    guard case .variable(let lhsName, let lhsPayload) = lhs,
      case .variable(let rhsName, let rhsPayload) = rhs
    else { return false }
    return lhsName == rhsName && lhsPayload == rhsPayload
  }

  private static func equalControlFlow(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    switch (lhs, rhs) {
    case (
      .conditional(let lhsCond, let lhsThen, let lhsElse),
      .conditional(let rhsCond, let rhsThen, let rhsElse)
    ):
      return lhsCond == rhsCond && lhsThen == rhsThen && lhsElse == rhsElse
    case (.loop(let lhsVar, let lhsCol, let lhsBody), .loop(let rhsVar, let rhsCol, let rhsBody)):
      return lhsVar == rhsVar && lhsCol == rhsCol && lhsBody == rhsBody
    default:
      return false
    }
  }

  private static func equalOperations(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    switch (lhs, rhs) {
    case (.functionCall(let lhsFunc, let lhsArgs), .functionCall(let rhsFunc, let rhsArgs)):
      return equalFunctionCalls(lhsFunc, lhsArgs, rhsFunc, rhsArgs)
    case (
      .methodCall(let lhsBase, let lhsMethod, let lhsArgs),
      .methodCall(let rhsBase, let rhsMethod, let rhsArgs)
    ):
      return lhsBase == rhsBase && lhsMethod == rhsMethod && equalMethodArgs(lhsArgs, rhsArgs)
    case (
      .binaryOperation(let lhsLeft, let lhsOp, let lhsRight),
      .binaryOperation(let rhsLeft, let rhsOp, let rhsRight)
    ):
      return lhsLeft == rhsLeft && lhsOp == rhsOp && lhsRight == rhsRight
    case (.propertyAccess(let lhsBase, let lhsProp), .propertyAccess(let rhsBase, let rhsProp)):
      return lhsBase == rhsBase && lhsProp == rhsProp
    default:
      return false
    }
  }

  private static func equalFunctionCalls(
    _ lhsFunc: String,
    _ lhsArgs: [(label: String?, value: Template<A>)],
    _ rhsFunc: String,
    _ rhsArgs: [(label: String?, value: Template<A>)]
  ) -> Bool {
    guard lhsFunc == rhsFunc, lhsArgs.count == rhsArgs.count else { return false }
    return zip(lhsArgs, rhsArgs).allSatisfy { lhsArg, rhsArg in
      lhsArg.label == rhsArg.label && lhsArg.value == rhsArg.value
    }
  }

  private static func equalMethodArgs(
    _ lhsArgs: [(label: String?, value: Template<A>)],
    _ rhsArgs: [(label: String?, value: Template<A>)]
  ) -> Bool {
    guard lhsArgs.count == rhsArgs.count else { return false }
    return zip(lhsArgs, rhsArgs).allSatisfy { lhsArg, rhsArg in
      lhsArg.label == rhsArg.label && lhsArg.value == rhsArg.value
    }
  }

  private static func equalDeclarations(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    guard case .variableDeclaration(let lhsName, let lhsType, let lhsInit) = lhs,
      case .variableDeclaration(let rhsName, let rhsType, let rhsInit) = rhs
    else { return false }
    return lhsName == rhsName && lhsType == rhsType && lhsInit == rhsInit
  }

  private static func equalCollections(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    guard case .arrayLiteral(let lhsElements) = lhs,
      case .arrayLiteral(let rhsElements) = rhs
    else { return false }
    return lhsElements == rhsElements
  }
}

extension Template: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    _ =
      hashLiterals(&hasher) || hashVariables(&hasher) || hashControlFlow(&hasher)
      || hashOperations(&hasher) || hashDeclarations(&hasher) || hashCollections(&hasher)
  }

  @discardableResult
  private func hashLiterals(_ hasher: inout Hasher) -> Bool {
    guard case .literal(let value) = self else { return false }
    hasher.combine(0)
    hasher.combine(value)
    return true
  }

  @discardableResult
  private func hashVariables(_ hasher: inout Hasher) -> Bool {
    guard case .variable(let name, let payload) = self else { return false }
    hasher.combine(1)
    hasher.combine(name)
    hasher.combine(payload)
    return true
  }

  @discardableResult
  private func hashControlFlow(_ hasher: inout Hasher) -> Bool {
    switch self {
    case .conditional(let condition, let thenBranch, let elseBranch):
      hasher.combine(2)
      hasher.combine(condition)
      hasher.combine(thenBranch)
      hasher.combine(elseBranch)
      return true
    case .loop(let variable, let collection, let body):
      hasher.combine(3)
      hasher.combine(variable)
      hasher.combine(collection)
      hasher.combine(body)
      return true
    default:
      return false
    }
  }

  @discardableResult
  private func hashOperations(_ hasher: inout Hasher) -> Bool {
    switch self {
    case .functionCall(let function, let arguments):
      hasher.combine(4)
      hasher.combine(function)
      hashFunctionArgs(arguments, &hasher)
      return true
    case .methodCall(let base, let method, let arguments):
      hasher.combine(9)
      hasher.combine(base)
      hasher.combine(method)
      hashFunctionArgs(arguments, &hasher)
      return true
    case .binaryOperation(let left, let op, let right):
      hasher.combine(5)
      hasher.combine(left)
      hasher.combine(op)
      hasher.combine(right)
      return true
    case .propertyAccess(let base, let property):
      hasher.combine(6)
      hasher.combine(base)
      hasher.combine(property)
      return true
    default:
      return false
    }
  }

  private func hashFunctionArgs(
    _ arguments: [(label: String?, value: Template<A>)],
    _ hasher: inout Hasher
  ) {
    for (label, value) in arguments {
      hasher.combine(label)
      hasher.combine(value)
    }
  }

  @discardableResult
  private func hashDeclarations(_ hasher: inout Hasher) -> Bool {
    guard case .variableDeclaration(let name, let type, let initializer) = self else {
      return false
    }
    hasher.combine(7)
    hasher.combine(name)
    hasher.combine(type)
    hasher.combine(initializer)
    return true
  }

  @discardableResult
  private func hashCollections(_ hasher: inout Hasher) -> Bool {
    guard case .arrayLiteral(let elements) = self else { return false }
    hasher.combine(8)
    hasher.combine(elements)
    return true
  }
}
