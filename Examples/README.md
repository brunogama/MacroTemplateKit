# MacroTemplateKit — Examples

This directory contains side-by-side comparisons of Swift macro implementations:
- **BEFORE**: Raw string interpolation (as used in swift-syntax's own examples).
- **AFTER**: MacroTemplateKit's typed template algebra.

Each subdirectory focuses on one macro protocol family.

---

## Subdirectories

### [`ExpressionMacros/`](ExpressionMacros/)

Freestanding expression macros (`#expand(...)`).

| File | Macro | Description |
|------|-------|-------------|
| `StringifyMacro+MacroTemplateKit.swift` | `#stringify` | Expands an expression to a `(value, "source")` tuple |
| `URLMacro+MacroTemplateKit.swift` | `#URL` | Validates a URL literal at compile time |

---

### [`PeerMacros/`](PeerMacros/)

Attached peer macros (`@attached(peer)`).

See the directory README for the full list of examples.

---

### [`MemberMacros/`](MemberMacros/)

Attached member macros (`@attached(member)`).

See the directory README for the full list of examples.

---

### [`ExtensionMacros/`](ExtensionMacros/)

Attached extension macros (`@attached(extension)`).

See the directory README for the full list of examples.

---

### [`AccessorAndBodyMacros/`](AccessorAndBodyMacros/)

Attached accessor macros (`@attached(accessor)`) and body macros (`@attached(body)`).

| File | Macro type | Description |
|------|-----------|-------------|
| `EnvironmentValueMacro+MacroTemplateKit.swift` | `AccessorMacro` | `get`/`set` via `EnvironmentKey` subscript |
| `DictionaryStoragePropertyMacro+MacroTemplateKit.swift` | `AccessorMacro` | Dictionary-backed computed property |
| `ObservablePropertyMacro+MacroTemplateKit.swift` | `AccessorMacro` | Observation-instrumented property accessors |
| `RemoteBodyMacro+MacroTemplateKit.swift` | `BodyMacro` | Replaces function body with async remote dispatch |
| `ComputedPropertyAccessorMacro+MacroTemplateKit.swift` | `AccessorMacro` + `Declaration.computedProperty()` | Clamped accessor + full computed property via `Declaration` |

---

## Core MacroTemplateKit API Quick Reference

```swift
// Expression templates (Template<A>)
Template<Void>.variable("name")
Template.literal(.string("text"))
Template.literal(.integer(42))
Template.functionCall(function: "fn", arguments: [(label: "x", value: expr)])
Template.methodCall(base: base, method: "method", arguments: [...])
Template.propertyAccess(base: base, property: "name")
Template.subscriptAccess(base: base, index: index)
Template.dictionaryLiteral([(key: k, value: v)])
Template.tryAwait(expression)

// Statement templates (Statement<A>)
Statement.returnStatement(template)
Statement.assignmentStatement(lhs: lhs, rhs: rhs)
Statement.deferStatement([Statement<A>])
Statement.letBinding(name: "x", type: "String", initializer: template)
Statement.guardLetBinding(name:type:initializer:elseBody:)
Statement.expression(template)

// Declaration templates (Declaration<A>)
Declaration.computedProperty(ComputedPropertySignature(name:type:getter:setter:))
Declaration.function(FunctionSignature(name:parameters:isAsync:canThrow:returnType:body:))
Declaration.property(PropertySignature(name:type:isLet:initializer:))

// Rendering
Renderer.render(_: Template<A>) -> ExprSyntax
Renderer.render(_: Statement<A>) -> CodeBlockItemSyntax
Renderer.renderStatements(_: [Statement<A>]) -> CodeBlockItemListSyntax
Renderer.render(_: Declaration<A>) -> DeclSyntax
```
