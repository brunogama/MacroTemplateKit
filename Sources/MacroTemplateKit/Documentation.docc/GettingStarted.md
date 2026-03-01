# Getting Started with MacroTemplateKit

Add MacroTemplateKit to your macro target and render your first type-safe declaration.

## Overview

MacroTemplateKit is a compile-time dependency for Swift macro implementations. It replaces fragile string interpolation with a structured AST that guarantees syntactically correct output.

## Add the Dependency

Add MacroTemplateKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.3")
]
```

Then add it to your macro target:

```swift
.macro(
    name: "YourMacros",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
    ]
)
```

## Render a Function

Build a ``Declaration`` and pass it to ``Renderer``:

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
                    right: .variable("name", payload: ())
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

## Use Metadata

The type parameter `A` on ``Template``, ``Statement``, and ``Declaration`` lets you attach arbitrary data to variable references. Strip metadata with `map` before rendering:

```swift
let template: Template<String> = .variable("x", payload: "from user input")
let expr: ExprSyntax = Renderer.render(template.map { _ in () })
```

## Next Steps

Read <doc:ThreeLayerAST> to understand how the three template layers compose.
