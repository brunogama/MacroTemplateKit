import SwiftSyntax

// MARK: - Access Level

/// Swift access level modifiers for declarations.
///
/// Maps directly to Swift's access control keywords.
public enum AccessLevel: Equatable, Hashable, Sendable {
  case `public`
  case `internal`
  case `fileprivate`
  case `private`

  /// Returns nil for internal (default), SwiftSyntax Keyword otherwise.
  public var keyword: Keyword? {
    switch self {
    case .internal: nil
    case .public: .public
    case .private: .private
    case .fileprivate: .fileprivate
    }
  }
}

/// Declaration-level code generation templates.
///
/// `Declaration<A>` extends the Template algebra to handle top-level Swift declarations.
/// Combined with `Template<A>` (expressions) and `Statement<A>` (statements), this provides
/// a complete AST for macro code generation without string interpolation.
///
/// # Functor Laws
///
/// Declaration satisfies the functor laws:
/// - Identity: `decl.map(id) == decl`
/// - Composition: `decl.map(f).map(g) == decl.map(g ∘ f)`
///
/// # Cases
///
/// The enum provides 5 declaration patterns:
/// 1. `.function` - Function declarations with async/throws/parameters/body
/// 2. `.property` - Stored property declarations (let/var)
/// 3. `.computedProperty` - Computed properties with getter/setter
/// 4. `.extensionDecl` - Extension declarations with members
/// 5. `.structDecl` - Struct declarations with members
public indirect enum Declaration<A> {
  // MARK: - Function Declaration

  /// Function declaration with full signature support.
  ///
  /// Renders to:
  /// ```swift
  /// func name(label param: Type, ...) async throws -> ReturnType {
  ///   statements...
  /// }
  /// ```
  ///
  /// SwiftSyntax equivalent: `FunctionDeclSyntax`
  case function(FunctionSignature<A>)

  // MARK: - Property Declarations

  /// Stored property declaration (let or var).
  ///
  /// Renders to:
  /// ```swift
  /// static? let/var name: Type = initializer
  /// ```
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `PatternBindingSyntax`
  case property(PropertySignature<A>)

  /// Computed property with getter and optional setter.
  ///
  /// Renders to:
  /// ```swift
  /// static? var name: Type {
  ///   get { statements... }
  ///   set { statements... }
  /// }
  /// ```
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `AccessorBlockSyntax`
  case computedProperty(ComputedPropertySignature<A>)

  // MARK: - Type Declarations

  /// Extension declaration with member declarations.
  ///
  /// Renders to:
  /// ```swift
  /// extension TypeName: Protocol1, Protocol2 {
  ///   members...
  /// }
  /// ```
  ///
  /// SwiftSyntax equivalent: `ExtensionDeclSyntax`
  case extensionDecl(ExtensionSignature<A>)

  /// Struct declaration with member declarations.
  ///
  /// Renders to:
  /// ```swift
  /// struct Name: Protocol1, Protocol2 {
  ///   members...
  /// }
  /// ```
  ///
  /// SwiftSyntax equivalent: `StructDeclSyntax`
  case structDecl(StructSignature<A>)

  /// Initializer declaration.
  ///
  /// Renders to:
  /// ```swift
  /// public init(label param: Type = default, ...) throws {
  ///   statements...
  /// }
  /// ```
  ///
  /// SwiftSyntax equivalent: `InitializerDeclSyntax`
  case initDecl(InitializerSignature<A>)
}

// MARK: - Supporting Types

/// Function signature with all declaration components.
public struct FunctionSignature<A>: Sendable where A: Sendable {
  /// Access level (public, internal, private, fileprivate).
  public let accessLevel: AccessLevel

  /// Function name.
  public let name: String

  /// Parameter list with labels, names, and types.
  public let parameters: [ParameterSignature]

  /// Whether function is async.
  public let isAsync: Bool

  /// Whether function can throw.
  public let canThrow: Bool

  /// Return type (nil for Void).
  public let returnType: String?

  /// Function body statements.
  public let body: [Statement<A>]

  public init(
    accessLevel: AccessLevel = .internal,
    name: String,
    parameters: [ParameterSignature] = [],
    isAsync: Bool = false,
    canThrow: Bool = false,
    returnType: String? = nil,
    body: [Statement<A>] = []
  ) {
    self.accessLevel = accessLevel
    self.name = name
    self.parameters = parameters
    self.isAsync = isAsync
    self.canThrow = canThrow
    self.returnType = returnType
    self.body = body
  }
}

/// Parameter signature for function parameters.
public struct ParameterSignature: Equatable, Hashable, Sendable {
  /// External label (nil for no label, "_" for explicit no label).
  public let label: String?

  /// Internal parameter name.
  public let name: String

  /// Parameter type.
  public let type: String

  /// Whether parameter is inout.
  public let isInout: Bool

  /// Default value expression as raw string (e.g., ".shared", "nil", "42").
  public let defaultValue: String?

  public init(
    label: String? = nil,
    name: String,
    type: String,
    isInout: Bool = false,
    defaultValue: String? = nil
  ) {
    self.label = label
    self.name = name
    self.type = type
    self.isInout = isInout
    self.defaultValue = defaultValue
  }
}

/// Property signature for stored properties.
public struct PropertySignature<A>: Sendable where A: Sendable {
  /// Access level (public, internal, private, fileprivate).
  public let accessLevel: AccessLevel
  public let name: String
  public let type: String?
  public let isStatic: Bool
  public let isLet: Bool
  public let initializer: Template<A>?

  public init(
    accessLevel: AccessLevel = .internal,
    name: String,
    type: String? = nil,
    isStatic: Bool = false,
    isLet: Bool = true,
    initializer: Template<A>? = nil
  ) {
    self.accessLevel = accessLevel
    self.name = name
    self.type = type
    self.isStatic = isStatic
    self.isLet = isLet
    self.initializer = initializer
  }
}

/// Computed property signature with accessors.
public struct ComputedPropertySignature<A>: Sendable where A: Sendable {
  public let name: String
  public let type: String
  public let isStatic: Bool
  public let getter: [Statement<A>]
  public let setter: SetterSignature<A>?

  public init(
    name: String,
    type: String,
    isStatic: Bool = false,
    getter: [Statement<A>],
    setter: SetterSignature<A>? = nil
  ) {
    self.name = name
    self.type = type
    self.isStatic = isStatic
    self.getter = getter
    self.setter = setter
  }
}

/// Setter signature with parameter name and body.
public struct SetterSignature<A>: Sendable where A: Sendable {
  /// Setter parameter name (default: "newValue").
  public let parameterName: String

  /// Setter body statements.
  public let body: [Statement<A>]

  public init(parameterName: String = "newValue", body: [Statement<A>]) {
    self.parameterName = parameterName
    self.body = body
  }
}

/// Extension signature with type name and members.
public struct ExtensionSignature<A>: Sendable where A: Sendable {
  public let typeName: String
  public let conformances: [String]
  public let members: [Declaration<A>]

  public init(
    typeName: String,
    conformances: [String] = [],
    members: [Declaration<A>] = []
  ) {
    self.typeName = typeName
    self.conformances = conformances
    self.members = members
  }
}

/// Struct signature with name and members.
public struct StructSignature<A>: Sendable where A: Sendable {
  /// Access level (public, internal, private, fileprivate).
  public let accessLevel: AccessLevel
  public let name: String
  public let conformances: [String]
  public let members: [Declaration<A>]

  public init(
    accessLevel: AccessLevel = .internal,
    name: String,
    conformances: [String] = [],
    members: [Declaration<A>] = []
  ) {
    self.accessLevel = accessLevel
    self.name = name
    self.conformances = conformances
    self.members = members
  }
}

/// Initializer signature for init declarations.
public struct InitializerSignature<A>: Sendable where A: Sendable {
  /// Access level (public, internal, private, fileprivate).
  public let accessLevel: AccessLevel

  /// Parameter list with labels, names, types, and default values.
  public let parameters: [ParameterSignature]

  /// Whether initializer can throw.
  public let canThrow: Bool

  /// Initializer body statements.
  public let body: [Statement<A>]

  public init(
    accessLevel: AccessLevel = .internal,
    parameters: [ParameterSignature] = [],
    canThrow: Bool = false,
    body: [Statement<A>] = []
  ) {
    self.accessLevel = accessLevel
    self.parameters = parameters
    self.canThrow = canThrow
    self.body = body
  }
}

// MARK: - Functor

extension Declaration {
  /// Maps a transformation function over all template payloads, preserving structure.
  ///
  /// This operation satisfies functor laws:
  /// - Identity: `declaration.map { $0 } == declaration`
  /// - Composition: `declaration.map(f).map(g) == declaration.map { g(f($0)) }`
  ///
  /// Only nested `Template<A>` payloads are transformed; declaration structure remains unchanged.
  ///
  /// - Parameter transform: Function applied to each template payload
  /// - Returns: New declaration with transformed payloads and identical structure
  public func map<B>(_ transform: @escaping @Sendable (A) -> B) -> Declaration<B>
  where A: Sendable, B: Sendable {
    switch self {
    case .function(let signature):
      return .function(signature.map(transform))
    case .property(let signature):
      return .property(signature.map(transform))
    case .computedProperty(let signature):
      return .computedProperty(signature.map(transform))
    case .extensionDecl(let signature):
      return .extensionDecl(signature.map(transform))
    case .structDecl(let signature):
      return .structDecl(signature.map(transform))
    case .initDecl(let signature):
      return .initDecl(signature.map(transform))
    }
  }
}

extension FunctionSignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> FunctionSignature<B>
  where A: Sendable, B: Sendable {
    FunctionSignature<B>(
      accessLevel: accessLevel,
      name: name,
      parameters: parameters,
      isAsync: isAsync,
      canThrow: canThrow,
      returnType: returnType,
      body: body.map { $0.map(transform) }
    )
  }
}

extension PropertySignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> PropertySignature<B>
  where A: Sendable, B: Sendable {
    PropertySignature<B>(
      accessLevel: accessLevel,
      name: name,
      type: type,
      isStatic: isStatic,
      isLet: isLet,
      initializer: initializer?.map(transform)
    )
  }
}

extension ComputedPropertySignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> ComputedPropertySignature<B>
  where A: Sendable, B: Sendable {
    ComputedPropertySignature<B>(
      name: name,
      type: type,
      isStatic: isStatic,
      getter: getter.map { $0.map(transform) },
      setter: setter?.map(transform)
    )
  }
}

extension SetterSignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> SetterSignature<B>
  where A: Sendable, B: Sendable {
    SetterSignature<B>(
      parameterName: parameterName,
      body: body.map { $0.map(transform) }
    )
  }
}

extension ExtensionSignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> ExtensionSignature<B>
  where A: Sendable, B: Sendable {
    ExtensionSignature<B>(
      typeName: typeName,
      conformances: conformances,
      members: members.map { $0.map(transform) }
    )
  }
}

extension StructSignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> StructSignature<B>
  where A: Sendable, B: Sendable {
    StructSignature<B>(
      accessLevel: accessLevel,
      name: name,
      conformances: conformances,
      members: members.map { $0.map(transform) }
    )
  }
}

extension InitializerSignature {
  func map<B>(_ transform: @escaping @Sendable (A) -> B) -> InitializerSignature<B>
  where A: Sendable, B: Sendable {
    InitializerSignature<B>(
      accessLevel: accessLevel,
      parameters: parameters,
      canThrow: canThrow,
      body: body.map { $0.map(transform) }
    )
  }
}

// MARK: - Protocol Conformances

extension Declaration: Equatable where A: Equatable {}

extension Declaration: Hashable where A: Hashable {}

extension Declaration: Sendable where A: Sendable {}

extension FunctionSignature: Equatable where A: Equatable {}

extension FunctionSignature: Hashable where A: Hashable {}

extension PropertySignature: Equatable where A: Equatable {}

extension PropertySignature: Hashable where A: Hashable {}

extension ComputedPropertySignature: Equatable where A: Equatable {}

extension ComputedPropertySignature: Hashable where A: Hashable {}

extension SetterSignature: Equatable where A: Equatable {}

extension SetterSignature: Hashable where A: Hashable {}

extension ExtensionSignature: Equatable where A: Equatable {}

extension ExtensionSignature: Hashable where A: Hashable {}

extension StructSignature: Equatable where A: Equatable {}

extension StructSignature: Hashable where A: Hashable {}

extension InitializerSignature: Equatable where A: Equatable {}

extension InitializerSignature: Hashable where A: Hashable {}
