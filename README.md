# MacroTemplateKit

[![CI](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml/badge.svg)](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml)
[![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)](https://developer.apple.com)

A typed, composable AST for generating Swift macro output. Build `Template`, `Statement`, and `Declaration` values instead of interpolating strings or assembling SwiftSyntax nodes by hand, then render them directly to SwiftSyntax.

```swift
import MacroTemplateKit
import SwiftSyntax

let declaration: DeclSyntax = try Renderer.render(
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

The result is a `DeclSyntax` value representing:

```swift
public func greet(name: String) -> String {
    return "Hello, " + name
}
```

## Why MacroTemplateKit?

String-based macro generation makes balanced delimiters, escaping, precedence, and diagnostics your responsibility. MacroTemplateKit gives those concerns a structured home:

- **Type-directed composition** — expressions, statements, and declarations can only be combined in valid positions.
- **Syntactically checked output** — the renderer uses a parse gate and throws `RenderError` if generated source is malformed.
- **Precedence-aware rendering** — nested operations are parenthesized without requiring hand-written source strings.
- **Metadata without output pollution** — the generic payload `A` carries compile-time information through templates and is erased with `map` before rendering.
- **Extract, transform, render** — `Extractor` turns existing `DeclSyntax` into typed signatures; immutable `with*` and `adding*` methods make transformations straightforward.
- **Swift 6-friendly** — the core template types conditionally conform to `Sendable` when their payload does.

> [!NOTE]
> MacroTemplateKit covers common macro-generation patterns. For syntax outside its case set, use SwiftSyntax directly and splice expressions with `Template.syntax(_:)` where appropriate.

## The three-layer AST

The model mirrors SwiftSyntax's expression, statement, and declaration hierarchy:

```text
Declaration<A>  ──►  DeclSyntax
    └─ contains
Statement<A>    ──►  CodeBlockItemSyntax
    └─ contains
Template<A>     ──►  ExprSyntax
```

| Type | Represents | Renders to |
| --- | --- | --- |
| `Template<A>` | Expressions: literals, calls, property access, operators, closures, and more | `ExprSyntax` |
| `Statement<A>` | Bindings, control flow, returns, throws, and expressions | `CodeBlockItemSyntax` |
| `Declaration<A>` | Functions, properties, extensions, structs, enums, type aliases, and initializers | `DeclSyntax` |

Use `Template<Void>`, `Statement<Void>`, and `Declaration<Void>` when metadata is unnecessary. The payload is attached to variable references, transformed by `map`, and ignored by `Renderer`.

## Installation

MacroTemplateKit is a compile-time dependency for Swift macro implementation targets.

### Swift Package Manager

Add the package and the SwiftSyntax products used by your macro target:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.1.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1")
],
targets: [
    .macro(
        name: "YourMacros",
        dependencies: [
            .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
        ]
    )
]
```

The `0.1.0` tag is the final source-only release. Use a branch or local checkout when developing MacroTemplateKit itself.

> [!IMPORTANT]
> Starting with the next approved release, tagged releases will provide a universal macOS `MacroTemplateKit.xcframework` pinned to Xcode 16.2, Swift 6.0, and SwiftSyntax 600.0.1. Binary consumers must use that exact toolchain and SwiftSyntax version.

## Requirements

- **Source package:** Swift 5.10 or later; SwiftSyntax 600.0.1 through the 6xx release line.
- **Binary release:** macOS 13 or later on arm64 or x86_64; Xcode 16.2, Swift 6.0, and SwiftSyntax 600.0.1 exactly.
- **Generated code targets:** iOS 16+, macOS 13+, tvOS 16+, and watchOS 9+.

## API at a glance

### Build expressions

```swift
let request = Template<Void>.variable("request")

let expression: ExprSyntax = try Renderer.render(
    request
        .property("url")
        .property("absoluteString")
)

let call: ExprSyntax = try Renderer.render(
    Template<Void>.call(
        "fetchUser",
        arguments: [
            .labeled("id", .variable("userID")),
            .labeled("cache", .literal(true))
        ]
    )
)
```

Common factories include `.literal`, `.variable`, `.call`, `.method`, `.property`, `.subscriptAccess`, `.binaryOperation`, `.closure`, `.array`, `.trying()`, `.awaiting()`, and `.tryAwait()`.

### Build statements and declarations

```swift
let binding: CodeBlockItemSyntax = try Renderer.render(
    Statement<Void>.letBinding(
        name: "data",
        type: nil,
        initializer: Template<Void>.variable("api")
            .method("fetch") {
                TemplateArgument<Void>.unlabeled(.variable("request"))
            }
            .tryAwait()
    )
)

let function: DeclSyntax = try Renderer.render(
    Declaration.function(FunctionSignature(
        accessLevel: .public,
        name: "loadUser",
        parameters: [ParameterSignature(label: "with", name: "id", type: "String")],
        isAsync: true,
        canThrow: true,
        returnType: "User",
        body: [
            .letBinding(
                name: "data",
                type: nil,
                initializer: Template<Void>.variable("api")
                    .method("fetch") {
                        TemplateArgument<Void>.labeled("id", .variable("id"))
                    }
                    .tryAwait()
            ),
            .returnStatement(.call(
                "User",
                arguments: [.labeled("from", .variable("data"))]
            ))
        ]
    ))
)
```

Render several statements with `Renderer.renderStatements(_:)`. Declaration signatures also model generics, parameter packs, attributes, `where` requirements, access levels, stored and computed properties, extensions, structs, enums, type aliases, and initializers.

### Extract and transform declarations

Use `Extractor` when a macro receives an existing declaration and needs to generate a variant:

```swift
let extracted: Declaration<Never> = Extractor.extract(declaration)!

if case .function(let signature) = extracted {
    let generated: DeclSyntax = try signature
        .withName(signature.name + "Async")
        .withIsAsync(true)
        .withCanThrow(true)
        .withBody([])
        .rendered
}
```

Extracted declarations preserve signature structure but have empty bodies. For multi-binding variables, use `Extractor.extractAll(_:)`. Map `Declaration<Never>` to `Declaration<Void>` (or another payload) when needed before further transformation.

### Carry metadata with `map`

```swift
struct VariableInfo {
    let sourceFile: String
    let line: Int
}

let template: Template<VariableInfo> = .binaryOperation(
    left: .variable("lhs", payload: VariableInfo(sourceFile: "Macro.swift", line: 10)),
    operator: "+",
    right: .variable("rhs", payload: VariableInfo(sourceFile: "Macro.swift", line: 10))
)

// Validate or transform the metadata, then erase it for rendering.
let expression: ExprSyntax = try Renderer.render(template.map { _ in () })
```

## Examples

[`Examples/`](Examples/) contains complete macro implementations organized by macro role. Each example demonstrates the difference between string interpolation and the typed template approach.

| Directory | Macro role | Examples |
| --- | --- | --- |
| [`ExpressionMacros`](Examples/ExpressionMacros/) | Freestanding expression macros | `StringifyMacro`, `URLMacro`, `FontLiteralMacro`, `SourceLocationMacro` |
| [`PeerMacros`](Examples/PeerMacros/) | Attached peer macros | `AddAsyncMacro`, `AddCompletionHandlerMacro` |
| [`MemberMacros`](Examples/MemberMacros/) | Attached member macros | `CustomCodableMacro`, `DictionaryStorageMacro`, `NewTypeMacro` |
| [`ExtensionMacros`](Examples/ExtensionMacros/) | Attached extension macros | `SendableExtensionMacro`, `HashableExtensionMacro`, `OptionSetExtensionMacro` |
| [`AccessorAndBodyMacros`](Examples/AccessorAndBodyMacros/) | Accessor and body macros | `ObservablePropertyMacro`, `EnvironmentValueMacro`, `RemoteBodyMacro` |

## Development

Clone the repository and run the package checks:

```bash
git clone https://github.com/brunogama/MacroTemplateKit.git
cd MacroTemplateKit

swift build
swift test
```

To run the checks used by CI:

```bash
./Scripts/bootstrap.sh
./Scripts/ci-local.sh
```

`ci-local.sh` runs formatting, SwiftLint, warning-as-error builds, tests, manifest checks, and the SwiftSyntax compatibility matrix. Use `swift test --filter RendererTests` to run one focused test suite.

The repository keeps common package-manifest content synchronized across `Package.swift`, `Package@swift-6.0.swift`, and `Package@swift-6.2.swift`:

```bash
./Scripts/check-manifests.sh
```

Generated DocC documentation is built in CI and is published at [brunogama.github.io/MacroTemplateKit](https://brunogama.github.io/MacroTemplateKit/documentation/macrotemplatekit/).

## Benchmarks

The standalone [`Benchmarks/`](Benchmarks/) package measures macro-shaped generation and edit workloads across switchable pipelines. It includes token-equivalence gates so performance comparisons do not compare different output.

```bash
swift build -c release --package-path Benchmarks
Benchmarks/.build/release/RenderEngineBench
```

For workload selection, methodology, reproducibility guidance, and interpretation of retained-tree measurements, see [`Benchmarks/README.md`](Benchmarks/README.md). Choose the library for its structured API and correctness guarantees; benchmark figures are workload-specific and should not be treated as a general build-time promise.

## Further reading

- [Getting Started](Sources/MacroTemplateKit/Documentation.docc/GettingStarted.md)
- [The Three-Layer AST](Sources/MacroTemplateKit/Documentation.docc/ThreeLayerAST.md)
- [API documentation](https://brunogama.github.io/MacroTemplateKit/documentation/macrotemplatekit/)
- [Architecture decision records](docs/adr/)
- [Swift Package Index](https://swiftpackageindex.com/brunogama/MacroTemplateKit)
- [LLMS.txt](LLMS.txt), a compact machine-readable project overview
