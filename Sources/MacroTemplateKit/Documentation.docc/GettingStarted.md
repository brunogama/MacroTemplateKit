# Getting Started with MacroTemplateKit

Add MacroTemplateKit to your macro target and render your first type-safe declaration.

## Overview

MacroTemplateKit is a compile-time dependency for Swift macro implementations. It replaces fragile string interpolation with a structured AST that guarantees syntactically correct output.

## Add the Dependency

Add MacroTemplateKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.6"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
]
```

Then add it to your macro target:

```swift
.macro(
    name: "YourMacros",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    ]
)
```

Tagged releases resolve to a prebuilt XCFramework. Use that path when you want
MacroTemplateKit without inheriting this repository's `swift-syntax` version
range. Use a branch or local checkout only when you are contributing to
MacroTemplateKit itself.

## Render a Function

Build a ``Declaration`` and pass it to ``Renderer``. In the common case, use `Template<Void>` and the `Void` convenience factories like `.variable("name")`.

```swift
import MacroTemplateKit
import SwiftSyntax

let decl: DeclSyntax = Renderer.render(
    Declaration.function(FunctionSignature(
        accessLevel: .public,
        name: "greet",
        parameters: [ParameterSignature(name: "name", type: "String")],
        returnType: "String",
        body: [
            .returnStatement(
                .binaryOperation(
                    left: .literal("Hello, "),
                    operator: "+",
                    right: .variable("name")
                )
            )
        ]
    ))
)
```

This produces:

```swift
public func greet(name: String) -> String {
    return "Hello, " + name
}
```

## Use Fluent Expressions

The chainable API is the recommended style for common expression assembly:

```swift
let expr: ExprSyntax = Renderer.render(
    Template<Void>.variable("api")
        .method("fetch") {
            TemplateArgument<Void>.labeled("id", .variable("userId"))
        }
        .tryAwait()
)
```

## Model Generics and Attributes

Generic clauses, parameter packs, `where` requirements, and common `@...`
attributes are first-class parts of declaration signatures:

```swift
let decl: DeclSyntax = Renderer.render(
    Declaration.function(FunctionSignature(
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
)
```

## Use Metadata

The type parameter `A` on ``Template``, ``Statement``, and ``Declaration`` lets you attach arbitrary data to variable references. Treat `Void` as the default mode; switch to a custom payload only when you need compile-time metadata, then strip it with `map` before rendering:

```swift
let template: Template<String> = .variable("x", payload: "from user input")
let expr: ExprSyntax = Renderer.render(template.map { _ in () })
```

## Extract, Transform, Render

Many macro roles receive existing declarations from the compiler and need to produce modified versions of them. ``Extractor`` converts any `DeclSyntax` node back into the kit's typed model so you can read its signature, modify it with wither methods, and render new output -- without touching SwiftSyntax internals directly.

```swift
import MacroTemplateKit
import SwiftSyntax

// Received from a member macro's `declaration` parameter
guard let extracted: Declaration<Never> = Extractor.extract(declaration) else {
    return []  // unsupported declaration kind
}

if case .function(let sig) = extracted {
    // sig is FunctionSignature<Never>
    // Use wither methods to produce a modified copy
    let asyncVariant: DeclSyntax = sig
        .withName(sig.name + "Async")
        .withIsAsync(true)
        .withCanThrow(true)
        .withBody([])
        .rendered  // shortcut for Renderer.render(sig.asDeclaration)
    return [asyncVariant]
}
```

For variables with multiple bindings (`var x = 1, y = 2`), use ``Extractor/extractAll(_:)`` to get one ``Declaration`` per binding. Typed overloads are also available when you already have a concrete syntax node type:

```swift
// Extract directly to a signature type
let sig: FunctionSignature<Never> = Extractor.extract(funcDeclSyntax)

// map converts Declaration<Never> to Declaration<Void> for wither methods
let base: Declaration<Void> = extracted.map { _ in () }
```

Extracted declarations always have empty bodies -- the extractor captures structure (name, parameters, access level, generics, attributes) but drops executable code. Attach body statements after extraction using wither methods.

## Next Steps

Read <doc:ThreeLayerAST> to understand how the three template layers compose.

The repository's `Examples/` directory contains over 20 complete macro implementations rewritten using MacroTemplateKit, covering all five macro roles: expression macros, accessor and body macros, extension macros, member macros, and peer macros. Each file is a self-contained reference for a specific pattern.
