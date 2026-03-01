# Getting Started with MacroTemplateKit

Learn how to build type-safe Swift code generation templates using MacroTemplateKit.

## Overview

MacroTemplateKit is designed for use inside **Swift macro implementations**. Rather than producing source code through unsafe string interpolation, you construct a typed AST and let `Renderer` emit the corresponding `SwiftSyntax` nodes.

This article walks you through installation, then progressively shows how to build expressions, statements, and full declarations.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.3")
]
```

Then add it to your macro target:

```swift
.macro(
    name: "MyMacros",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    ]
)
```

## Building Expressions with Template\<A\>

`Template<A>` represents expression-level Swift code. The type parameter `A` is metadata you can attach to variable references—it is erased during rendering.

```swift
import MacroTemplateKit

// A simple integer literal
let one: Template<Void> = .literal(.integer(1))

// A variable reference
let x: Template<Void> = .variable("x", payload: ())

// x + 1
let sum: Template<Void> = .binaryOperation(left: x, operator: "+", right: one)

let expr: ExprSyntax = Renderer.render(sum)
print(expr.description) // x + 1
```

### Calling Functions and Methods

```swift
// fetchUser(id: userId, cache: true)
let call: Template<Void> = .functionCall(
    function: "fetchUser",
    arguments: [
        (label: "id",    value: .variable("userId", payload: ())),
        (label: "cache", value: .literal(.boolean(true)))
    ]
)

// api.fetch(request)
let method: Template<Void> = .methodCall(
    base: .variable("api", payload: ()),
    method: "fetch",
    arguments: [(label: nil, value: .variable("request", payload: ()))]
)
```

## Building Statements with Statement\<A\>

`Statement<A>` wraps expression templates into statement positions.

```swift
// let result = try await api.fetch(request)
let stmt: Statement<Void> = .letBinding(
    name: "result",
    type: nil,
    initializer: .methodCall(
        base: .variable("api", payload: ()),
        method: "fetch",
        arguments: [(label: nil, value: .variable("request", payload: ()))]
    )
)

let codeItem: CodeBlockItemSyntax = Renderer.render(stmt)
```

## Building Declarations with Declaration\<A\>

`Declaration<A>` represents top-level Swift declarations such as functions, properties, and extensions.

```swift
// public func loadUser(with id: String) async throws -> User { … }
let function: Declaration<Void> = .function(FunctionSignature(
    accessLevel: .public,
    name: "loadUser",
    parameters: [
        ParameterSignature(label: "with", name: "id", type: "String")
    ],
    isAsync: true,
    canThrow: true,
    returnType: "User",
    body: [
        .letBinding(name: "data", type: nil,
                    initializer: .methodCall(
                        base: .variable("api", payload: ()),
                        method: "fetch",
                        arguments: [(label: "id", value: .variable("id", payload: ()))]
                    )),
        .returnStatement(.functionCall(
            function: "User",
            arguments: [(label: "from", value: .variable("data", payload: ()))]
        ))
    ]
))

let decl: DeclSyntax = Renderer.render(function)
```

## Attaching Metadata with Functors

Every template type is a functor. Use `map` to transform metadata while preserving structure:

```swift
struct Origin { let file: String; let line: Int }

let withOrigin: Template<Origin> = .variable(
    "x", payload: Origin(file: "MyMacro.swift", line: 10)
)

// Erase metadata for rendering
let erased: Template<Void> = withOrigin.map { _ in () }
let expr: ExprSyntax = Renderer.render(erased)
```

The functor laws guarantee safe, predictable transformations:

```
// Identity law (pseudocode)
template.map { $0 } == template

// Composition law (pseudocode)
template.map(f).map(g) == template.map { g(f($0)) }
```

## Next Steps

- Explore the full list of ``Template``, ``Statement``, and ``Declaration`` cases to find the construct you need.
- Use ``TemplateBuilder`` for a declarative DSL syntax.
- Check the ``Renderer`` documentation for all available render overloads.
