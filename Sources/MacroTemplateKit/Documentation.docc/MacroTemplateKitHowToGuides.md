# How-to Guides

Recipes for common MacroTemplateKit tasks.

## Install the Library in a Macro Target

1. Add the package dependency in `Package.swift`:

   ```swift
   .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.1.0")
   ```

2. Add the product to the macro target dependencies:

   ```swift
   .product(name: "MacroTemplateKit", package: "MacroTemplateKit")
   ```

3. Import `MacroTemplateKit` in the macro implementation.

## Build an Expression

Use a factory on ``Template`` and compose it with fluent methods:

```swift
let expression = Template<Void>.variable("client")
    .property("configuration")
    .method("value")
```

Render it when you need SwiftSyntax:

```swift
let syntax: ExprSyntax = try Renderer.render(expression)
```

Use ``LiteralValue`` for literal values rather than interpolating source text:

```swift
let name = Template<Void>.literal("Taylor")
let count = Template<Void>.literal(3)
```

## Build Calls with Arguments

Create labeled and unlabeled arguments with ``TemplateArgument``:

```swift
let call = Template<Void>.call(
    "makeRequest",
    arguments: [
        .labeled("method", .literal("GET")),
        .unlabeled(.variable("url"))
    ]
)
```

## Build Statements and Declarations

Use ``Statement`` for code-block items:

```swift
let statement = Statement<Void>.letBinding(
    name: "value",
    type: "String",
    initializer: .literal("generated")
)
```

Place statements in a signature and render the resulting ``Declaration``:

```swift
let declaration = Declaration.function(
    FunctionSignature(
        name: "makeValue",
        parameters: [],
        returnType: "String",
        body: [
            statement,
            .returnStatement(.variable("value"))
        ]
    )
)

let syntax: DeclSyntax = try Renderer.render(declaration)
```

## Transform Metadata

Use `map` to transform payloads without changing the generated syntax:

```swift
let typed: Template<Int> = .variable("value", payload: 42)
let labeled: Template<String> = typed.map { "payload: \($0)" }
let syntax: ExprSyntax = try Renderer.render(labeled.map { _ in () })
```

## Extract and Transform a Declaration

Use ``Extractor`` when a macro receives an existing declaration:

```swift
guard let extracted: Declaration<Never> = Extractor.extract(declaration) else {
    return []
}

if case .function(let signature) = extracted {
    let renamed = signature.withName(signature.name + "Async")
    let output: DeclSyntax = try Renderer.render(renamed.asDeclaration)
    return [output]
}
```

Use ``Extractor/extractAll(_:)`` when a variable declaration contains multiple bindings and each binding must be handled separately.

## Handle Rendering Errors

Rendering APIs are throwing APIs. Propagate the error when the macro entry point already supports throws:

```swift
let output = try Renderer.render(template)
```

Otherwise, convert the error to the diagnostic mechanism used by your macro rather than silently emitting malformed source:

```swift
do {
    return [try Renderer.render(declaration)]
} catch {
    context.diagnose(Diagnostic(node: declarationSyntax, message: error.localizedDescription))
    return []
}
```

## Test Generated Syntax

Compare the rendered node’s `description` in a unit test, or parse it with SwiftSyntax when a structural assertion is more useful:

```swift
import Testing

let output: ExprSyntax = try Renderer.render(template)
#expect(output.description == "api.fetch()")
```

Keep tests focused on the template model and the syntax it produces. Test diagnostics separately from successful rendering.

## Support Swift 6 Toolchains

Use the package manifest and SwiftSyntax version required by the toolchain that builds your macro target. Keep MacroTemplateKit and SwiftSyntax on compatible versions, and run the project’s manifest checks when changing either dependency.
