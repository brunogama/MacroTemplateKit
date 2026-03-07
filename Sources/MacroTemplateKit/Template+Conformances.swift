// MARK: - Protocol Conformances for New Types

extension StringInterpolationSegment: Equatable where A: Equatable {
  public static func == (lhs: StringInterpolationSegment<A>, rhs: StringInterpolationSegment<A>)
    -> Bool
  {
    switch (lhs, rhs) {
    case (.text(let l), .text(let r)):
      return l == r
    case (.expression(let l), .expression(let r)):
      return l == r
    default:
      return false
    }
  }
}

extension StringInterpolationSegment: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .text(let s):
      hasher.combine(0)
      hasher.combine(s)
    case .expression(let expr):
      hasher.combine(1)
      hasher.combine(expr)
    }
  }
}

extension ClosureSignature: Equatable where A: Equatable {
  public static func == (lhs: ClosureSignature<A>, rhs: ClosureSignature<A>) -> Bool {
    guard lhs.parameters.count == rhs.parameters.count else { return false }
    let paramsEqual = zip(lhs.parameters, rhs.parameters).allSatisfy {
      $0.name == $1.name && $0.type == $1.type
    }
    return lhs.attributes == rhs.attributes
      && paramsEqual
      && lhs.returnType == rhs.returnType
      && lhs.body == rhs.body
  }
}

extension ClosureSignature: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(attributes)
    for param in parameters {
      hasher.combine(param.name)
      hasher.combine(param.type)
    }
    hasher.combine(returnType)
    hasher.combine(body)
  }
}

extension SwitchCase: Equatable where A: Equatable {
  public static func == (lhs: SwitchCase<A>, rhs: SwitchCase<A>) -> Bool {
    lhs.pattern == rhs.pattern && lhs.body == rhs.body
  }
}

extension SwitchCase: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(pattern)
    hasher.combine(body)
  }
}

extension SwitchCasePattern: Equatable where A: Equatable {
  public static func == (lhs: SwitchCasePattern<A>, rhs: SwitchCasePattern<A>) -> Bool {
    switch (lhs, rhs) {
    case (.expression(let l), .expression(let r)):
      return l == r
    case (.stringLiteral(let l), .stringLiteral(let r)):
      return l == r
    case (.defaultCase, .defaultCase):
      return true
    default:
      return false
    }
  }
}

extension SwitchCasePattern: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .expression(let expr):
      hasher.combine(0)
      hasher.combine(expr)
    case .stringLiteral(let s):
      hasher.combine(1)
      hasher.combine(s)
    case .defaultCase:
      hasher.combine(2)
    }
  }
}

// MARK: - Protocol Conformances

extension Template: Equatable where A: Equatable {
  public static func == (lhs: Template<A>, rhs: Template<A>) -> Bool {
    equalLiterals(lhs, rhs) || equalVariables(lhs, rhs) || equalControlFlow(lhs, rhs)
      || equalOperations(lhs, rhs) || equalEffects(lhs, rhs) || equalDeclarations(lhs, rhs)
      || equalCollections(lhs, rhs) || equalExtensions(lhs, rhs)
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
    case (
      .genericCall(let lhsFunc, let lhsTypes, let lhsArgs),
      .genericCall(let rhsFunc, let rhsTypes, let rhsArgs)
    ):
      return lhsFunc == rhsFunc && lhsTypes == rhsTypes && equalMethodArgs(lhsArgs, rhsArgs)
    default:
      return false
    }
  }

  private static func equalEffects(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    switch (lhs, rhs) {
    case (.tryExpression(let lhsInner), .tryExpression(let rhsInner)):
      return lhsInner == rhsInner
    case (.awaitExpression(let lhsInner), .awaitExpression(let rhsInner)):
      return lhsInner == rhsInner
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
    switch (lhs, rhs) {
    case (.arrayLiteral(let lhsElements), .arrayLiteral(let rhsElements)):
      return lhsElements == rhsElements
    case (.tupleLiteral(let lhsElements), .tupleLiteral(let rhsElements)):
      return lhsElements == rhsElements
    case (.dictionaryLiteral(let lhsEntries), .dictionaryLiteral(let rhsEntries)):
      guard lhsEntries.count == rhsEntries.count else { return false }
      return zip(lhsEntries, rhsEntries).allSatisfy { l, r in
        l.key == r.key && l.value == r.value
      }
    default:
      return false
    }
  }

  private static func equalExtensions(_ lhs: Template<A>, _ rhs: Template<A>) -> Bool {
    switch (lhs, rhs) {
    case (.subscriptAccess(let lb, let li), .subscriptAccess(let rb, let ri)):
      return lb == rb && li == ri
    case (.subscriptCall(let lhsBase, let lhsArgs), .subscriptCall(let rhsBase, let rhsArgs)):
      return lhsBase == rhsBase && equalMethodArgs(lhsArgs, rhsArgs)
    case (.forceUnwrap(let l), .forceUnwrap(let r)):
      return l == r
    case (.stringInterpolation(let l), .stringInterpolation(let r)):
      return l == r
    case (.closure(let l), .closure(let r)):
      return l == r
    case (.assignment(let ll, let lr), .assignment(let rl, let rr)):
      return ll == rl && lr == rr
    case (.selfAccess(let l), .selfAccess(let r)):
      return l == r
    default:
      return false
    }
  }
}

extension Template: Hashable where A: Hashable {
  public func hash(into hasher: inout Hasher) {
    _ =
      hashLiterals(&hasher) || hashVariables(&hasher) || hashControlFlow(&hasher)
      || hashOperations(&hasher) || hashEffects(&hasher) || hashDeclarations(&hasher)
      || hashCollections(&hasher) || hashExtensions(&hasher)
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
    case .genericCall(let function, let typeArguments, let arguments):
      hasher.combine(12)
      hasher.combine(function)
      hasher.combine(typeArguments)
      hashFunctionArgs(arguments, &hasher)
      return true
    default:
      return false
    }
  }

  @discardableResult
  private func hashEffects(_ hasher: inout Hasher) -> Bool {
    switch self {
    case .tryExpression(let inner):
      hasher.combine(10)
      hasher.combine(inner)
      return true
    case .awaitExpression(let inner):
      hasher.combine(11)
      hasher.combine(inner)
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
    switch self {
    case .arrayLiteral(let elements):
      hasher.combine(8)
      hasher.combine(elements)
      return true
    case .tupleLiteral(let elements):
      hasher.combine(20)
      hasher.combine(elements)
      return true
    case .dictionaryLiteral(let entries):
      hasher.combine(13)
      for entry in entries {
        hasher.combine(entry.key)
        hasher.combine(entry.value)
      }
      return true
    default:
      return false
    }
  }

  @discardableResult
  private func hashExtensions(_ hasher: inout Hasher) -> Bool {
    switch self {
    case .subscriptAccess(let base, let index):
      hasher.combine(14)
      hasher.combine(base)
      hasher.combine(index)
      return true
    case .subscriptCall(let base, let arguments):
      hasher.combine(21)
      hasher.combine(base)
      hashFunctionArgs(arguments, &hasher)
      return true
    case .forceUnwrap(let inner):
      hasher.combine(15)
      hasher.combine(inner)
      return true
    case .stringInterpolation(let segments):
      hasher.combine(16)
      hasher.combine(segments)
      return true
    case .closure(let sig):
      hasher.combine(17)
      hasher.combine(sig)
      return true
    case .assignment(let lhs, let rhs):
      hasher.combine(18)
      hasher.combine(lhs)
      hasher.combine(rhs)
      return true
    case .selfAccess(let typeName):
      hasher.combine(19)
      hasher.combine(typeName)
      return true
    default:
      return false
    }
  }
}
