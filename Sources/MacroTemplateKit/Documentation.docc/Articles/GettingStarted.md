# Getting Started with MacroTemplateKit

Learn how to build type-safe Swift code generation templates using MacroTemplateKit.

## Overview

MacroTemplateKit is designed for use inside **Swift macro implementations**. Rather than producing source code through unsafe string interpolation, you construct a typed AST and let `Renderer` emit the corresponding `SwiftSyntax` nodes.

This article walks you through installation, then progressively shows how to build expressions, statements, and full declarations.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.6"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
]
```

Then add it to your macro target:

```swift
.macro(
    name: "MyMacros",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    ]
)
```

Tagged releases resolve to a prebuilt XCFramework, which keeps MacroTemplateKit
from imposing this repository's `swift-syntax` version range on your macro
package. Use a branch or local checkout only when you are developing
MacroTemplateKit itself.

## Building Expressions with Template\<A\>

`Template<A>` represents expression-level Swift code. In the common case, use `Template<Void>`. The type parameter `A` becomes useful when you want to attach metadata to variable references; it is erased during rendering.

```swift
import MacroTemplateKit

// A simple integer literal
let one: Template<Void> = .literal(.integer(1))

// A variable reference
let x: Template<Void> = .variable("x")

// x + 1
let sum: Template<Void> = .binaryOperation(left: x, operator: "+", right: one)

let expr: ExprSyntax = Renderer.render(sum)
print(expr.description) // x + 1
```

### Calling Functions and Methods

```swift
// fetchUser(id: userId, cache: true)
let call: Template<Void> = .call(
    "fetchUser",
    arguments: [
        .labeled("id", .variable("userId")),
        .labeled("cache", .literal(true))
    ]
)

// api.fetch(request)
let method: Template<Void> = .variable("api")
    .method("fetch") {
        TemplateArgument<Void>.unlabeled(.variable("request"))
    }

// request.url.absoluteString
let chain: Template<Void> = .variable("request")
    .property("url")
    .property("absoluteString")
```

## Building Statements with Statement\<A\>

`Statement<A>` wraps expression templates into statement positions.

```swift
// let result = try await api.fetch(request)
let stmt: Statement<Void> = .letBinding(
    name: "result",
    type: nil,
    initializer: Template<Void>.variable("api")
        .method("fetch") {
            TemplateArgument<Void>.unlabeled(.variable("request"))
        }
        .tryAwait()
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
                    initializer: Template<Void>.variable("api")
                        .method("fetch") {
                            TemplateArgument<Void>.labeled("id", .variable("id"))
                        }
                        .tryAwait()),
        .returnStatement(.call(
            "User",
            arguments: [
                .labeled("from", .variable("data"))
            ]
        ))
    ]
))

let decl: DeclSyntax = Renderer.render(function)
```

## Generics, Parameter Packs, and Attributes

Use first-class signature models when your macro needs generics, parameter packs,
same-type requirements, or attributes:

```swift
let register: Declaration<Void> = .function(FunctionSignature(
    accessLevel: .public,
    attributes: [.mainActor],
    name: "register",
    genericParameters: [
        GenericParameterSignature(name: "Service", constraint: "Sendable"),
        GenericParameterSignature(name: "Dependency", isParameterPack: true)
    ],
    parameters: [
        ParameterSignature(label: "_", name: "service", type: "Service"),
        ParameterSignature(name: "dependencies", type: "repeat each Dependency"),
        ParameterSignature(
            name: "handler",
            type: "() -> Void",
            attributes: [.escaping]
        )
    ],
    whereRequirements: [
        .sameType("Service.ID", "String"),
        .conformance("each Dependency", "Sendable")
    ],
    body: []
))

let callback: Template<Void> = .closure(
    attributes: [.sendable],
    params: [(name: "value", type: "Int")],
    returnType: "Void",
    body: [
        .expression(.call("handle", arguments: [.unlabeled(.variable("value"))]))
    ]
)
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

## Extracting Existing Declarations

``Extractor`` converts a `DeclSyntax` node into the kit's typed model. Use it in macros that receive existing declarations from the compiler and need to inspect or transform them before generating new output.

```swift
import MacroTemplateKit
import SwiftSyntax

// Received from a member macro's `declaration` parameter
guard let extracted: Declaration<Never> = Extractor.extract(declaration) else {
    return []  // unsupported declaration kind (class, protocol, #if, etc.)
}

if case .function(let sig) = extracted {
    // sig.name, sig.parameters, sig.accessLevel, sig.isAsync, etc. are all available
    let newSig: DeclSyntax = sig
        .withName(sig.name + "Cached")
        .withBody([
            .returnStatement(.call("cache", arguments: [.unlabeled(.variable("id"))]))
        ])
        .rendered
    return [newSig]
}
```

For variables with multiple bindings (`var x = 1, y = 2`), use ``Extractor/extractAll(_:)`` to receive one ``Declaration`` per binding. Typed overloads skip the pattern match when you already hold a concrete syntax node:

```swift
let funcSig: FunctionSignature<Never> = Extractor.extract(funcDeclSyntax)
let varDecls: [Declaration<Never>] = Extractor.extract(varDeclSyntax)
```

`Extractor` always produces `Declaration<Never>`. Use `map` to convert to `Declaration<Void>` (or any other payload) before calling wither methods or attaching body statements:

```swift
let base: Declaration<Void> = extracted.map { _ in () }
```

**Limitations.** Extracted declarations have empty bodies -- the extractor captures signature structure (name, parameters, access level, generics, attributes) but drops executable code. `open` access maps to `.public`. `class func` members are extracted as static.

## Wither Methods

Every signature type has `with*` and `adding*` methods that return a modified copy. They are the standard way to transform extracted declarations before re-rendering.

```swift
// Build a public async throwing variant from an extracted signature
let variant: DeclSyntax = sig
    .withAccessLevel(.public)
    .withIsAsync(true)
    .withCanThrow(true)
    .withReturnType("User?")
    .addingParameter(ParameterSignature(label: "cache", name: "useCache", type: "Bool"))
    .addingAttribute(.mainActor)
    .rendered  // shortcut for Renderer.render(sig.asDeclaration)
```

The `.rendered` property and `.asDeclaration` are available on every signature type, so you rarely need to wrap a signature in `Declaration.function(...)` manually.

## Next Steps

- Explore the full list of ``Template``, ``Statement``, and ``Declaration`` cases to find the construct you need.
- Use ``TemplateBuilder`` for a declarative DSL syntax.
- Check the ``Renderer`` and ``Extractor`` documentation for all available overloads.
