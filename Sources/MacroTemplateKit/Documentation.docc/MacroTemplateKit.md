# ``MacroTemplateKit``

A type-safe, functional templating engine for Swift macro code generation.

## Overview

MacroTemplateKit provides a **parametric algebraic data type** (ADT) that separates template structure from metadata, enabling compile-time safety, composability, and mathematical guarantees through functor laws.

Instead of building Swift code via string interpolation—which is fragile and hard to validate—MacroTemplateKit gives you a three-layer structured AST:

```
Declaration<A>  ──────►  DeclSyntax
       │
Statement<A>   ──────►  CodeBlockItemSyntax
       │
 Template<A>   ──────►  ExprSyntax
```

Each layer is a **functor**: it supports a `map` operation that satisfies the identity and composition laws, enabling safe and predictable transformations of metadata without changing template structure.

### Quick Example

```swift
import MacroTemplateKit

let template: Declaration<Void> = .function(FunctionSignature(
    accessLevel: .public,
    name: "loadUser",
    parameters: [ParameterSignature(label: "with", name: "id", type: "String")],
    isAsync: true,
    canThrow: true,
    returnType: "User",
    body: [
        .letBinding(name: "data", type: nil,
                    initializer: .methodCall(base: .variable("api", payload: ()),
                                             method: "fetch",
                                             arguments: [(label: "id", value: .variable("id", payload: ()))])),
        .returnStatement(.functionCall(function: "User",
                                       arguments: [(label: "from", value: .variable("data", payload: ()))]))
    ]
))

let syntax: DeclSyntax = Renderer.render(template)
// public func loadUser(with id: String) async throws -> User { … }
```

## Topics

### Getting Started

- <doc:GettingStarted>

### Core Template Types

- ``Template``
- ``Statement``
- ``Declaration``
- ``LiteralValue``

### Rendering

- ``Renderer``

### Signature Types

- ``FunctionSignature``
- ``ParameterSignature``
- ``PropertySignature``
- ``ComputedPropertySignature``
- ``SetterSignature``
- ``ExtensionSignature``
- ``StructSignature``
- ``InitializerSignature``
- ``AccessLevel``

### Result Builder DSL

- ``TemplateBuilder``
