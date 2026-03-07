# MacroTemplateKit

[![CI](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml/badge.svg)](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml)
[![Swift 5.10+](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Stop building Swift macro output with string interpolation. MacroTemplateKit gives you a structured, type-safe AST that renders directly to `DeclSyntax`, `ExprSyntax`, and `CodeBlockItemSyntax` -- the types your macro already returns.

```swift
// Instead of this:
let code = """
public func \(name)(\(params)) async throws -> \(returnType) {
    let result = try await \(call)
    return result
}
"""
// ...and hoping the braces balance.

// Write this:
let decl: DeclSyntax = Renderer.render(
    Declaration.function(FunctionSignature(
        accessLevel: .public,
        name: name,
        parameters: params,
        isAsync: true,
        canThrow: true,
        returnType: returnType,
        body: [
            .letBinding(name: "result", type: nil, initializer: .tryAwait(call)),
            .returnStatement(.variable("result"))
        ]
    ))
)
```

## Why This Matters

String interpolation in macros has a specific failure mode: the code compiles fine, but the macro produces malformed Swift that your users see as cryptic errors pointing at generated code they did not write.

MacroTemplateKit eliminates that failure mode:

- **Syntactically correct by construction.** You build an AST. The renderer handles tokens, commas, braces, and whitespace. There is no way to produce a mismatched brace or a missing comma.
- **Type-checked template composition.** The three-layer type hierarchy (`Template<A>`, `Statement<A>`, `Declaration<A>`) mirrors Swift's own expression/statement/declaration hierarchy. Misusing a layer is a compile error, not a runtime surprise.
- **Parametric metadata for free.** The type parameter `A` lets you attach arbitrary compile-time data -- variable origins, type info, source locations -- to variable references without changing what gets rendered. Strip it with `map` before handing off to the renderer.
- **Pure, deterministic rendering.** `Renderer.render` has no side effects. The same template always produces the same syntax. This makes macro output straightforward to test.
- **Sendable throughout.** All three template types conditionally conform to `Sendable` when their payload does, making them safe to use in Swift 6 concurrent macro implementations.

## Architecture

MacroTemplateKit provides a three-layer AST that maps directly to SwiftSyntax's own hierarchy:

```
Your code                     SwiftSyntax output
─────────────────────────     ──────────────────────────
Declaration<A>          ───►  DeclSyntax
   └─ contains                  (FunctionDeclSyntax,
Statement<A>            ───►    ExtensionDeclSyntax, ...)
   └─ contains              CodeBlockItemSyntax
Template<A>             ───►  ExprSyntax
```

Each layer contains only the constructs that belong at that level. A `Statement` can contain `Template` expressions. A `Declaration` body is a `[Statement]`. The types enforce this structure at compile time.

## Quick Start

**Add the tagged binary release to your package:**

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.5"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
],
targets: [
    .macro(
        name: "YourMacros",
        dependencies: [
            .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        ]
    )
]
```

### Using The Binary Release

Tagged releases resolve to a prebuilt `MacroTemplateKit.xcframework`. That means
`MacroTemplateKit` itself does not pull in this repository's `swift-syntax`
constraint, so your macro package can keep using the `swift-syntax` version it
already needs.

Use the tagged release path when you are consuming MacroTemplateKit from another
macro package and need to stay compatible with a different `swift-syntax`
version. Use a branch, local checkout, or source dependency only when you are
contributing to MacroTemplateKit itself.

### Using The Source Package For Development

If you are working on MacroTemplateKit, depend on the source package instead of
the release tag so you build the library and its tests directly from this repo.

**Generate your first declaration:**

```swift
import MacroTemplateKit
import SwiftSyntax

// Renders: public func greet(name: String) -> String { ... }
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

For most macros, `Template<Void>`, `Statement<Void>`, and `Declaration<Void>` are the default path. Use a non-`Void` payload only when you want to carry compile-time metadata through template construction.

## Usage Examples

### Expressions

Build expressions with `.functionCall`, `.methodCall`, `.propertyAccess`, `.binaryOperation`, and more. Every expression type renders to an `ExprSyntax`.

```swift
// fetchUser(id: userId, cache: true)
let call: ExprSyntax = Renderer.render(
    Template<Void>.functionCall(
        function: "fetchUser",
        arguments: [
            (label: "id",    value: .variable("userId")),
            (label: "cache", value: .literal(.boolean(true)))
        ]
    )
)

// request.url.absoluteString
let chain: ExprSyntax = Renderer.render(
    Template<Void>.propertyAccess(
        base: .propertyAccess(
            base: .variable("request"),
            property: "url"
        ),
        property: "absoluteString"
    )
)

// try await api.fetch(request)
let effect: ExprSyntax = Renderer.render(
    Template<Void>.tryAwait(
        .methodCall(
            base: .variable("api"),
            method: "fetch",
            arguments: [(label: nil, value: .variable("request"))]
        )
    )
)
```

### Statements

Statements render to `CodeBlockItemSyntax` -- ready to drop into any function body.

```swift
// let data = try await api.fetch(id: id)
let binding: CodeBlockItemSyntax = Renderer.render(
    Statement<Void>.letBinding(
        name: "data",
        type: nil,
        initializer: .tryAwait(
            .methodCall(
                base: .variable("api"),
                method: "fetch",
                arguments: [(label: "id", value: .variable("id"))]
            )
        )
    )
)

// guard !items.isEmpty else { return }
let guard_: CodeBlockItemSyntax = Renderer.render(
    Statement<Void>.guardStatement(
        condition: .binaryOperation(
            left: .propertyAccess(base: .variable("items"), property: "isEmpty"),
            operator: "==",
            right: .literal(.boolean(false))
        ),
        elseBody: [.returnStatement(nil)]
    )
)
```

### Complete Function Declaration

```swift
// Generates:
// public func loadUser(with id: String) async throws -> User {
//     let data = try await api.fetch(id: id)
//     return User(from: data)
// }
let fn: DeclSyntax = Renderer.render(
    Declaration.function(FunctionSignature(
        accessLevel: .public,
        name: "loadUser",
        parameters: [
            ParameterSignature(label: "with", name: "id", type: "String")
        ],
        isAsync: true,
        canThrow: true,
        returnType: "User",
        body: [
            .letBinding(
                name: "data",
                type: nil,
                initializer: .tryAwait(
                    .methodCall(
                        base: .variable("api"),
                        method: "fetch",
                        arguments: [(label: "id", value: .variable("id"))]
                    )
                )
            ),
            .returnStatement(
                .functionCall(
                    function: "User",
                    arguments: [(label: "from", value: .variable("data"))]
                )
            )
        ]
    ))
)
```

### Extension with Protocol Conformance

```swift
// extension MyType: Equatable, Hashable where T: Hashable {
//     static let shared = MyType()
// }
let ext: DeclSyntax = Renderer.render(
    Declaration.extensionDecl(ExtensionSignature(
        typeName: "MyType",
        conformances: ["Equatable", "Hashable"],
        whereRequirements: [
            WhereRequirement(typeParameter: "T", constraint: "Hashable")
        ],
        members: [
            .property(PropertySignature(
                accessLevel: .internal,
                name: "shared",
                type: "MyType",
                isStatic: true,
                isLet: true,
                initializer: .functionCall(function: "MyType", arguments: [])
            ))
        ]
    ))
)
```

### Parametric Metadata

The type parameter `A` is the mechanism for carrying compile-time information alongside your template without that information leaking into the rendered output. Use it to track variable provenance, type annotations, or source locations during template construction, then discard it before rendering.

```swift
struct VarInfo {
    let type: String
    let sourceLocation: Int
}

// Build a template that tracks where each variable comes from
let template: Template<VarInfo> = .binaryOperation(
    left: .variable("x", payload: VarInfo(type: "Int", sourceLocation: 42)),
    operator: "+",
    right: .variable("y", payload: VarInfo(type: "Int", sourceLocation: 43))
)

// Validate before rendering: all variables must be the same type
func validate(_ t: Template<VarInfo>) -> Bool {
    // walk t and check VarInfo.type consistency
    true
}

// Strip metadata and render -- payload is never in the output
let expr: ExprSyntax = Renderer.render(template.map { _ in () })
```

### Transforming Templates with map

All three types are functors. `map` transforms every variable payload while preserving the template's structure exactly. This satisfies the functor laws -- identity and composition -- which you can verify in the test suite.

```swift
let original: Template<String> = .functionCall(
    function: "process",
    arguments: [
        (label: "input", value: .variable("x", payload: "raw")),
        (label: "mode",  value: .variable("m", payload: "config"))
    ]
)

// Enrich metadata without rebuilding the template
let enriched: Template<EnrichedInfo> = original.map { string in
    EnrichedInfo(tag: string, validated: true)
}

// Discard metadata before rendering
let expr: ExprSyntax = Renderer.render(enriched.map { _ in () })
```

## API Reference

### Core Types

| Type | Purpose | Renders to |
|------|---------|------------|
| `Template<A>` | Expression-level templates | `ExprSyntax` |
| `Statement<A>` | Statement-level templates | `CodeBlockItemSyntax` |
| `Declaration<A>` | Declaration-level templates | `DeclSyntax` |
| `LiteralValue` | Integer, double, string, bool, nil | (embedded in `Template`) |
| `Renderer` | Pure rendering functions | -- |

### Template Cases (Expressions)

| Case | Output |
|------|--------|
| `.literal(LiteralValue)` | Integer, double, string, bool, or nil literal |
| `.variable(String, payload: A)` | Identifier reference with optional metadata |
| `.functionCall(function:arguments:)` | `name(label: value, ...)` |
| `.methodCall(base:method:arguments:)` | `base.method(...)` |
| `.propertyAccess(base:property:)` | `base.property` |
| `.binaryOperation(left:operator:right:)` | `left op right` |
| `.conditional(condition:thenBranch:elseBranch:)` | `cond ? then : else` |
| `.loop(variable:collection:body:)` | `.forEach` closure over a collection |
| `.tryExpression(_:)` | `try expr` |
| `.awaitExpression(_:)` | `await expr` |
| `.closure(_:)` | `{ params in body }` |
| `.arrayLiteral(_:)` | `[elem1, elem2, ...]` |
| `.tupleLiteral(_:)` | `(elem1, elem2, ...)` |
| `.dictionaryLiteral(_:)` | `[k1: v1, k2: v2, ...]` |
| `.stringInterpolation(_:)` | `"text\(expr)text"` |
| `.genericCall(function:typeArguments:arguments:)` | `Fn<T>(...)` |
| `.subscriptAccess(base:index:)` | `base[index]` |
| `.subscriptCall(base:arguments:)` | `base[a, b]` or `base[key, default: value]` |
| `.forceUnwrap(_:)` | `expr!` |
| `.assignment(lhs:rhs:)` | `lhs = rhs` |
| `.selfAccess(_:)` | `TypeName.self` |
| `.variableDeclaration(name:type:initializer:)` | Initializer expression (in expression position) |

Fluent factory shortcuts are available for common patterns: `Template.tryAwait(_:)`, `Template.array(_:)`, `Template.tuple(_:)`, `Template.ternary(if:then:else:)`, `Template.closure(params:returnType:body:)`, `Template.subscriptCall(_:arguments:)`, `Template<Void>.variable(_:)`, and more. See `Template+FluentFactories.swift`.

### Statement Cases

| Case | Output |
|------|--------|
| `.letBinding(name:type:initializer:)` | `let name: Type = expr` |
| `.varBinding(name:type:initializer:)` | `var name: Type = expr` |
| `.guardStatement(condition:elseBody:)` | `guard cond else { ... }` |
| `.guardLetBinding(name:type:initializer:elseBody:)` | `guard let name = expr else { ... }` |
| `.ifStatement(condition:thenBody:elseBody:)` | `if cond { ... } else { ... }` |
| `.ifLetBinding(name:type:initializer:thenBody:elseBody:)` | `if let name = expr { ... } else { ... }` |
| `.forInStatement(variable:collection:body:)` | `for x in collection { ... }` |
| `.switchStatement(subject:cases:)` | `switch x { case ...: ... }` |
| `.returnStatement(_:)` | `return expr` |
| `.throwStatement(_:)` | `throw expr` |
| `.deferStatement(_:)` | `defer { ... }` |
| `.assignmentStatement(lhs:rhs:)` | `lhs = rhs` (in statement position) |
| `.expression(_:)` | Expression used as statement |
| `.breakStatement` | `break` |

### Declaration Cases

| Case | Output |
|------|--------|
| `.function(FunctionSignature)` | `func name(...) async throws -> T { ... }` |
| `.property(PropertySignature)` | `let/var name: T = expr` |
| `.computedProperty(ComputedPropertySignature)` | `var name: T { get { ... } set { ... } }` |
| `.extensionDecl(ExtensionSignature)` | `extension T: P where ... { ... }` |
| `.structDecl(StructSignature)` | `struct Name: P { ... }` |
| `.enumDecl(EnumSignature)` | `enum Name: P { case ...; members... }` |
| `.typeAlias(TypeAliasSignature)` | `typealias Name = ExistingType` |
| `.initDecl(InitializerSignature)` | `init?(params) throws { ... }` |

### Renderer

```swift
// Expression
Renderer.render(_ template: Template<A>) -> ExprSyntax

// Statement
Renderer.render(_ statement: Statement<A>) -> CodeBlockItemSyntax

// Multiple statements (for function bodies)
Renderer.renderStatements(_ statements: [Statement<A>]) -> CodeBlockItemListSyntax

// Declaration
Renderer.render(_ declaration: Declaration<A>) -> DeclSyntax
```

### Signature Types

| Type | Key Properties |
|------|---------------|
| `FunctionSignature<A>` | `name`, `parameters`, `isAsync`, `canThrow`, `returnType`, `body`, `accessLevel`, `isStatic`, `isMutating` |
| `ParameterSignature` | `label`, `name`, `type`, `isInout`, `defaultValue` |
| `PropertySignature<A>` | `name`, `type`, `isLet`, `isStatic`, `initializer`, `accessLevel` |
| `ComputedPropertySignature<A>` | `name`, `type`, `getter`, `setter`, `isStatic`, `accessLevel` |
| `ExtensionSignature<A>` | `typeName`, `conformances`, `whereRequirements`, `members` |
| `StructSignature<A>` | `name`, `conformances`, `members`, `accessLevel` |
| `EnumSignature<A>` | `name`, `conformances`, `cases`, `members`, `accessLevel` |
| `EnumCaseSignature` | `name`, `rawValue`, `associatedTypes` |
| `TypeAliasSignature` | `name`, `existingType`, `accessLevel` |
| `InitializerSignature<A>` | `parameters`, `canThrow`, `isFailable`, `body`, `accessLevel` |
| `WhereRequirement` | `typeParameter`, `constraint` |
| `AccessLevel` | `.public`, `.internal`, `.private`, `.fileprivate` |

## Examples

The `Examples/` directory contains complete macro implementations that use MacroTemplateKit, organized by macro role:

| Category | Examples |
|----------|----------|
| `ExpressionMacros/` | `StringifyMacro`, `URLMacro`, `FontLiteralMacro`, `SourceLocationMacro`, `WarningMacro`, `AddBlockerMacro` |
| `AccessorAndBodyMacros/` | `ObservablePropertyMacro`, `DictionaryStoragePropertyMacro`, `EnvironmentValueMacro`, `RemoteBodyMacro`, `ComputedPropertyAccessorMacro` |
| `ExtensionMacros/` | `SendableExtensionMacro`, `HashableExtensionMacro`, `EquatableExtensionMacro`, `OptionSetExtensionMacro`, `DefaultFatalErrorImplementationMacro` |
| `MemberMacros/` | `CustomCodableMacro`, `DictionaryStorageMacro`, `CaseDetectionMacro`, `MetaEnumMacro`, `NewTypeMacro` |
| `PeerMacros/` | `AddAsyncMacro`, `AddCompletionHandlerMacro`, `PeerValueWithSuffixNameMacro` |

Each file shows a real macro rewritten to use the template API, which makes them useful as starting points for your own macro implementations.

## Design Notes

**Algebraic data types for template structure.** Each layer (`Template`, `Statement`, `Declaration`) is a Swift enum. Every valid template form is a case. The compiler enforces exhaustive pattern matching, which means adding a new case to the library is a checked, breaking change rather than a silent omission.

**Payloads are invisible at render time.** `Renderer.render` discards the type parameter entirely. A `Template<Int>` and a `Template<String>` carrying the same variable name produce identical `ExprSyntax`. This separation lets you use the metadata system freely without worrying about output correctness.

**No invalid states.** The API has no optional rendering path for well-formed input. Constructing a `Declaration.function` with `isAsync: true` always produces an `async` function declaration. There are no flags that silently produce incorrect output.

**Tradeoffs to know about.** MacroTemplateKit covers the common 90% of macro code generation patterns. If you need to emit syntax that falls outside the current case set -- raw attribute lists, `#if` directives, operator declarations -- you will need to drop down to SwiftSyntax directly. The library's types are designed to compose with handwritten SwiftSyntax: you can use rendered output wherever a `DeclSyntax`, `ExprSyntax`, or `CodeBlockItemSyntax` is accepted.

## Requirements

- Swift 5.10+ (Swift 6.x recommended for contributors)
- SwiftSyntax 510.0 or later (tested up to 700.0)
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+

## Installation

### Swift Package Manager

For downstream macro packages, prefer the tagged binary release:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.5"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
]
```

Add to your macro target:

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

Tagged releases resolve to a prebuilt XCFramework, so MacroTemplateKit does not
force your package onto this repo's `swift-syntax` range. Your macro target
still declares its own `swift-syntax` products as usual.

If you are contributing to MacroTemplateKit itself, use a branch or local
checkout of the repository so SwiftPM builds the source package instead of the
binary release.

### Xcode

**File > Add Package Dependencies**, enter `https://github.com/brunogama/MacroTemplateKit.git`, then:

- select version `0.0.5` or later to consume the binary release
- use a branch or local checkout only when developing MacroTemplateKit itself

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Local Development

To match CI locally (format, lint, build, test):

```bash
./scripts/bootstrap.sh
./scripts/ci-local.sh
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT License. See [LICENSE](LICENSE).

## Author

Bruno Rocha ([@brunogama](https://github.com/brunogama))
