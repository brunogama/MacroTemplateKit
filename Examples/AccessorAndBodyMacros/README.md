# AccessorAndBodyMacros Examples

This directory contains examples of accessor macros and body macros implemented using
MacroTemplateKit's template algebra instead of raw string interpolation.

Each file shows:
1. The **BEFORE** approach: raw string interpolation as used in swift-syntax's own examples.
2. The **AFTER** approach: MacroTemplateKit's typed template AST.

---

## Files

### `EnvironmentValueMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax Examples/.../Accessor/EnvironmentValueMacro.swift`

An `AccessorMacro` that attaches to a stored property in an `EnvironmentValues` extension
and generates a get/set accessor pair routing reads and writes through an `EnvironmentKey` subscript.

Key MacroTemplateKit patterns:
- `.subscriptAccess(base:index:)` for `self[KeyType.self]`
- `.returnStatement(_:)` for the getter
- `.assignmentStatement(lhs:rhs:)` for the setter
- `Renderer.renderStatements(_:)` to convert `[Statement<Void>]` to `CodeBlockItemListSyntax`

---

### `DictionaryStoragePropertyMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax Examples/.../ComplexMacros/DictionaryIndirectionMacro.swift`

An `AccessorMacro` that replaces a stored property with a computed property backed by a
`[String: Any]` dictionary (`_storage`). The getter uses a default-value subscript and
a force-cast; the setter writes through a simple string-key subscript.

Key MacroTemplateKit patterns:
- `.subscriptAccess(base:index:)` for `_storage["key"]`
- `.returnStatement(_:)` with a verbatim expression for the force-cast getter
- `.assignmentStatement(lhs:rhs:)` for the setter
- Limitation note: two-argument subscripts (`_storage["key", default: val]`) require
  verbatim text because `Template.subscriptAccess` models a single index expression.

---

### `ObservablePropertyMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax Examples/.../ComplexMacros/ObservableMacro.swift`

An `AccessorMacro` that instruments a stored property with `ObservationRegistrar` callbacks.
The generated `get`/`set` wrap every access with `beginAccess`/`endAccess` calls and
`register(observable:willSet:to:)` / `register(observable:didSet:)` notifications.

Key MacroTemplateKit patterns:
- `.methodCall(base:method:arguments:)` for `_registrar.beginAccess(...)` etc.
- `.deferStatement(_:)` for the `defer { _registrar.endAccess() }` block
- `.propertyAccess(base:property:)` for `_storage.propertyName`
- Key-path literals (`\.name`) modelled as verbatim `.variable("\\.\(name)")`

---

### `RemoteBodyMacro+MacroTemplateKit.swift`

Source: `swiftlang/swift-syntax Tests/.../BodyMacroTests.swift`

A `BodyMacro` (experimental API) that replaces a function body with an async remote-call
dispatch. It collects parameter names and forwards them as a dictionary to `remoteCall`.

Key MacroTemplateKit patterns:
- `.dictionaryLiteral([(key:value:)])` for `["param": param, ...]`
- `.functionCall(function:arguments:)` for `remoteCall(function:arguments:)`
- `.tryAwait(_:)` fluent factory for the `try await` wrapper
- `.returnStatement(_:)` for the single return statement

---

### `ComputedPropertyAccessorMacro+MacroTemplateKit.swift`

Custom example demonstrating:

1. **AccessorMacro** — `ClampedAccessorMacro` uses nested `.functionCall` templates to model
   `min(max(newValue, lower), upper)` as a type-safe tree rather than a raw string.
2. **Full computed property via `Declaration.computedProperty()`** — `ComputedPropertyFromDeclarationExample`
   shows how to render a complete `VariableDeclSyntax` with both getter and setter using
   `ComputedPropertySignature<A>` and `SetterSignature<A>`, then converting to `DeclSyntax`
   via `Renderer.render(_:)`. This pattern is useful for `MemberMacro` and `DeclarationMacro`.

Key MacroTemplateKit patterns:
- `Declaration.computedProperty(ComputedPropertySignature(...))` for full property declarations
- `SetterSignature(parameterName:body:)` for the setter with a named parameter
- `Renderer.render(_: Declaration<A>)` to obtain `DeclSyntax`
- Nested `.functionCall` for composable mathematical expressions

---

## Key Pattern: AccessorMacro vs DeclarationMacro

`AccessorMacro` returns `[AccessorDeclSyntax]` — individual accessor blocks.
Use `Renderer.renderStatements(_:)` to build the `CodeBlockItemListSyntax` body for each:

```swift
let getterStatements: [Statement<Void>] = [.returnStatement(.variable("backing"))]
let getter = AccessorDeclSyntax(
    accessorSpecifier: .keyword(.get),
    body: CodeBlockSyntax(statements: Renderer.renderStatements(getterStatements))
)
```

`Declaration.computedProperty()` + `Renderer.render(_:)` produces a full `DeclSyntax`
(a `VariableDeclSyntax` with an `AccessorBlockSyntax`) — use this in `MemberMacro`:

```swift
let declaration: Declaration<Void> = .computedProperty(
    ComputedPropertySignature(
        name: "myProp",
        type: "String",
        getter: [.returnStatement(.variable("_myProp"))],
        setter: SetterSignature(body: [.assignmentStatement(lhs: ..., rhs: ...)])
    )
)
let declSyntax: DeclSyntax = Renderer.render(declaration)
```
