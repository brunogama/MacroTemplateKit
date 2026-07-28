# Tutorial: Build and Render a Template

Build a typed Swift expression and render it as SwiftSyntax.

## What You Will Build

You will generate this expression without assembling source code as a string:

```swift
try await api.fetch(id: userId)
```

The template will use a variable, a labeled argument, and the fluent expression API.

## Add MacroTemplateKit

Add the package dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.1.0")
]
```

Add the product to the macro target that generates SwiftSyntax:

```swift
.macro(
    name: "YourMacros",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
    ]
)
```

Import the library and SwiftSyntax in the source file that builds output:

```swift
import MacroTemplateKit
import SwiftSyntax
```

## Create the Template

Start with a variable template. `Template<Void>` is the convenient choice when you do not need metadata:

```swift
let api = Template<Void>.variable("api")
```

Compose a method call with a labeled argument, then add `try await`:

```swift
let request = api
    .method("fetch") {
        TemplateArgument<Void>.labeled("id", .variable("userId"))
    }
    .tryAwait()
```

The template is still a typed model. It has not produced SwiftSyntax yet.

## Render the Expression

Pass the template to ``Renderer/render(_:)``:

```swift
let expression: ExprSyntax = try Renderer.render(request)
print(expression.description)
```

The rendered syntax describes:

```swift
try await api.fetch(id: userId)
```

Rendering can throw ``RenderError`` when a model cannot be converted to valid SwiftSyntax.

## Build a Declaration

Templates compose upward into statements and declarations. For example, use the expression as the initializer of a local binding:

```swift
let function = Declaration.function(
    FunctionSignature(
        accessLevel: .public,
        name: "load",
        parameters: [],
        returnType: "User",
        body: [
            .letBinding(name: "result", type: nil, initializer: request),
            .returnStatement(.variable("result"))
        ]
    )
)

let declaration: DeclSyntax = try Renderer.render(function)
```

The result is a `DeclSyntax` value that can be returned from a macro expansion.

## Carry Metadata

The generic payload can carry information while a template is being assembled:

```swift
let annotated: Template<String> = .variable(
    "userId",
    payload: "identifier supplied by the caller"
)
```

The renderer ignores payloads. Convert the template to `Template<Void>` before rendering when the metadata is no longer needed:

```swift
let expression = try Renderer.render(annotated.map { _ in () })
```

## Where to Go Next

- Follow <doc:MacroTemplateKitHowToGuides> for focused recipes.
- Consult <doc:MacroTemplateKitReference> for the available model types and renderers.
- Read <doc:ThreeLayerAST> for the relationship between expressions, statements, and declarations.
