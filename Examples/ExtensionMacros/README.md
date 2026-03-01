# ExtensionMacros Examples

This directory contains production-ready examples of `@attached(extension)` macros
rewritten using **MacroTemplateKit**'s typed template algebra instead of raw string
interpolation.  Each file follows the pattern:

- **BEFORE** block — the original swift-syntax string-interpolation approach (commented out)
- **AFTER** block — the MacroTemplateKit approach (active code)

All examples use `Renderer.renderExtensionDecl(_:)` and `Renderer.render(_:)` as the
sole rendering entry points, and express every code-generation decision through typed
`ExtensionSignature`, `FunctionSignature`, `PropertySignature`, `InitializerSignature`,
`WhereRequirement`, and `Statement<A>` values.

---

## Files

### `EquatableExtensionMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax` — `EquatableExtensionMacro.swift`

Adds `Equatable` conformance to any type via an empty extension.  Demonstrates the
minimal `ExtensionSignature` pattern: one conformance, no where clause, no members.

Generated output:
```swift
extension TypeName: Equatable {}
```

Key API: `ExtensionSignature(typeName:conformances:members:)`

---

### `HashableExtensionMacro+MacroTemplateKit.swift`

Companion to the Equatable example.  Generates two conformance extensions — one for
`Hashable` and one for `Equatable` — using a shared private helper that eliminates
the duplication present in the raw-interpolation version.

Generated output:
```swift
extension TypeName: Hashable {}
extension TypeName: Equatable {}
```

Key API: `makeConformanceExtension(typeName:conformance:)` helper pattern

---

### `DefaultFatalErrorImplementationMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax` — `DefaultFatalErrorImplementationMacro.swift`

Attaches to a protocol and generates a default-`fatalError` body for every method
declared in it.  Demonstrates iterating over AST members, converting
`FunctionDeclSyntax` to `FunctionSignature`, and composing a `.functionCall` body
statement.

Generated output (per method):
```swift
extension MyProtocol {
    func someMethod() {
        fatalError("someMethod is not implemented")
    }
}
```

Key API:
- `FunctionSignature(name:parameters:isAsync:canThrow:returnType:body:)`
- `Statement<Never>.expression(.functionCall(...))`
- `ExtensionSignature(typeName:members:)`

---

### `OptionSetExtensionMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax` — `OptionSetMacro.swift` (ExtensionMacro role)

Adds `OptionSet` conformance to a decorated struct, suppressing the extension if the
conformance is already declared explicitly.  Demonstrates guard-and-return pattern
with a typed `DiagnosticMessage`.

Generated output:
```swift
extension ShippingOptions: OptionSet {}
```

Key API: `ExtensionSignature(typeName:conformances:members:)`

---

### `OptionSetMemberMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax` — `OptionSetMacro.swift` (MemberMacro role)

Generates the full set of stored members required by the `OptionSet` protocol:
`rawValue` property, two initialisers, and a `static let` per case in the nested
`Options` enum.  The static property initialisers use nested `.binaryOperation` /
`.propertyAccess` templates to model `1 << Options.caseName.rawValue`.

Generated output:
```swift
var rawValue: UInt8
init() { self.rawValue = 0 }
init(rawValue: UInt8) { self.rawValue = rawValue }
static let nextDay: Self = Self(rawValue: 1 << Options.nextDay.rawValue)
// ...
```

Key API:
- `PropertySignature(isStatic:isLet:initializer:)`
- `InitializerSignature(parameters:body:)`
- `Template<Never>.binaryOperation(left:operator:right:)`
- `Template<Never>.propertyAccess(base:property:)`

---

### `SendableExtensionMacro+MacroTemplateKit.swift`

Demonstrates **conditional conformance** using `WhereRequirement`.  Attaches to a
generic type and generates a `where Param: Sendable` extension.  Emits a diagnostic
when applied to a non-generic type.

Generated output:
```swift
extension Box: Sendable where Value: Sendable {}
// For Box<A, B>:
extension Box: Sendable where A: Sendable, B: Sendable {}
```

Key API: `WhereRequirement(typeParameter:constraint:)`

---

## Common Patterns

### Minimal conformance extension

```swift
let signature = ExtensionSignature<Never>(
    typeName: typeName,
    conformances: ["Equatable"],
    members: []
)
return [Renderer.renderExtensionDecl(signature)]
```

### Conditional conformance with where clause

```swift
let signature = ExtensionSignature<Never>(
    typeName: typeName,
    conformances: ["Sendable"],
    whereRequirements: [
        WhereRequirement(typeParameter: "Value", constraint: "Sendable")
    ],
    members: []
)
```

### Extension with generated members

```swift
let members: [Declaration<Never>] = [
    .property(PropertySignature(name: "rawValue", type: "RawValue", isLet: false)),
    .initDecl(InitializerSignature(parameters: [], body: [
        .assignmentStatement(lhs: .propertyAccess(base: .variable("self", payload: ...), property: "rawValue"),
                             rhs: .literal(.integer(0)))
    ])),
]
let signature = ExtensionSignature<Never>(typeName: typeName, members: members)
```
