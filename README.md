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
- **Bidirectional.** `Extractor` converts `DeclSyntax` nodes back into the kit's typed model. Receive existing declarations from a macro protocol, extract them, transform with wither methods, then render new output -- without touching SwiftSyntax internals.
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

The extract-transform-render pipeline completes the picture. `Extractor` runs the arrow in reverse -- from `DeclSyntax` back into `Declaration<Never>` -- so you can work with declarations that arrive from a macro's context:

```
DeclSyntax  ──►  Extractor.extract  ──►  Declaration<Never>
                                             │  .map { _ in () }
                                             ▼
                                    Declaration<Void>
                                             │  wither methods
                                             ▼
                                    Declaration<Void>
                                             │  Renderer.render
                                             ▼
                                         DeclSyntax
```

## Quick Start

**Add the tagged binary release to your package:**

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.6"),
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

Build expressions with `.call`, chained `.property(_:)`, chained `.method(_:)`, `.binaryOperation`, and more. Every expression type renders to an `ExprSyntax`.

```swift
// fetchUser(id: userId, cache: true)
let call: ExprSyntax = Renderer.render(
    Template<Void>.call(
        "fetchUser",
        arguments: [
            .labeled("id", .variable("userId")),
            .labeled("cache", .literal(true))
        ]
    )
)

// request.url.absoluteString
let chain: ExprSyntax = Renderer.render(
    Template<Void>.variable("request")
        .property("url")
        .property("absoluteString")
)

// try await api.fetch(request)
let effect: ExprSyntax = Renderer.render(
    Template<Void>.variable("api")
        .method("fetch") {
            TemplateArgument<Void>.unlabeled(.variable("request"))
        }
        .tryAwait()
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
        initializer: Template<Void>.variable("api")
            .method("fetch") {
                TemplateArgument<Void>.labeled("id", .variable("id"))
            }
            .tryAwait()
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
                initializer: Template<Void>.variable("api")
                    .method("fetch") {
                        TemplateArgument<Void>.labeled("id", .variable("id"))
                    }
                    .tryAwait()
            ),
            .returnStatement(
                .call(
                    "User",
                    arguments: [
                        .labeled("from", .variable("data"))
                    ]
                )
            )
        ]
    ))
)
```

### Generics, Parameter Packs, and Attributes

Declaration signatures can model generic clauses, same-type requirements, parameter packs, and common `@...` attributes directly.

```swift
let register: DeclSyntax = Renderer.render(
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
// @MainActor public func register<Service: Sendable, each Dependency>(
//     _ service: Service,
//     dependencies: repeat each Dependency,
//     handler: @escaping () -> Void
// ) where Service.ID == String, each Dependency: Sendable {}

let callback: ExprSyntax = Renderer.render(
    Template<Void>.closure(
        attributes: [.sendable],
        params: [(name: "value", type: "Int")],
        returnType: "Void",
        body: [
            .expression(
                .call(
                    "handle",
                    arguments: [
                        .unlabeled(.variable("value"))
                    ]
                )
            )
        ]
    )
)
// { @Sendable (value: Int) -> Void in handle(value) }
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

### Extracting Existing Declarations

`Extractor` converts a `DeclSyntax` node into the kit's typed model. Use it in macro implementations that receive existing declarations from the compiler and need to inspect or transform them before generating new output.

```swift
import MacroTemplateKit
import SwiftSyntax

// Received from a member macro's `declaration` parameter (DeclSyntax)
guard let extracted: Declaration<Never> = Extractor.extract(declaration) else {
    return []  // unsupported declaration kind
}

// Pattern-match the result to read signature properties
if case .function(let sig) = extracted {
    // sig is FunctionSignature<Never>
    // Access name, parameters, accessLevel, isAsync, canThrow, etc.
    let newName = sig.name + "Async"
    // Use wither methods to produce a modified copy (see next section)
    let asyncVariant = sig
        .withName(newName)
        .withIsAsync(true)
        .withReturnType("Void")
        .withBody([])
    return [asyncVariant.rendered]
}
```

For variables with multiple bindings (`var x = 1, y = 2`), use `extractAll` to get one `Declaration` per binding:

```swift
let all: [Declaration<Never>] = Extractor.extractAll(declaration)
```

Typed overloads let you extract directly to a specific signature type when you already know the declaration kind:

```swift
// When you have a FunctionDeclSyntax directly:
let sig: FunctionSignature<Never> = Extractor.extract(funcDeclSyntax)
```

**Limitations to know about.** Extracted declarations always have empty bodies -- the extractor captures the signature structure (name, parameters, access level, generics, attributes) but drops executable code. Attach body statements after extraction using wither methods. `open` maps to `.public` since `AccessLevel` has no `open` case. `class func` members are extracted as static.

### Wither Methods -- Immutable Updates

Every signature type has `with*` and `adding*` methods that return a modified copy of the signature. They are the standard way to transform extracted declarations or adjust ones you constructed manually.

```swift
// Build a public async throwing variant from an existing signature
let original = FunctionSignature<Void>(
    name: "loadUser",
    parameters: [ParameterSignature(name: "id", type: "String")],
    returnType: "User"
)

let variant: DeclSyntax = original
    .withAccessLevel(.public)
    .withIsAsync(true)
    .withCanThrow(true)
    .withReturnType("User?")
    .addingParameter(ParameterSignature(label: "cache", name: "cache", type: "Bool"))
    .addingAttribute(.mainActor)
    .rendered  // shortcut for Renderer.render(sig.asDeclaration)
// @MainActor public func loadUser(id: String, cache cache: Bool) async throws -> User?
```

Wither methods are available on `FunctionSignature`, `InitializerSignature`, `PropertySignature`, `ComputedPropertySignature`, `ExtensionSignature`, `StructSignature`, `EnumSignature`, and `TypeAliasSignature`. Each type exposes the methods that apply to its fields. The `adding*` and `removing*` variants append to or filter collections.

### Convenience Rendering on Signatures

Every signature type has `asDeclaration` and `rendered` computed properties so you do not need to wrap the signature in a `Declaration` case before passing it to `Renderer`.

```swift
let sig = FunctionSignature<Void>(
    accessLevel: .public,
    name: "greet",
    parameters: [ParameterSignature(name: "name", type: "String")],
    returnType: "String",
    body: [.returnStatement(.binaryOperation(left: .literal("Hello, "), operator: "+", right: .variable("name")))]
)

// These two lines produce the same DeclSyntax:
let a: DeclSyntax = Renderer.render(Declaration.function(sig))
let b: DeclSyntax = sig.rendered  // shortcut
```

`TypeAliasSignature.asDeclaration` is generic over payload type since `TypeAliasSignature` itself is not parameterized:

```swift
let alias = TypeAliasSignature(name: "UserID", existingType: "String")
let decl: Declaration<Void> = alias.asDeclaration()
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

`Template`, `Statement`, `Declaration`, and all signature types are functors. `map` transforms every variable payload while preserving structure. This satisfies the functor laws -- identity and composition -- which you can verify in the test suite.

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

The same `map` is available on signature types and `Declaration` itself. The common use case is the extract-then-map pattern: `Extractor` always produces `Declaration<Never>`, and `map` converts it to `Declaration<Void>` (or any other payload) before you attach body statements or call wither methods:

```swift
let extracted: Declaration<Never> = Extractor.extract(decl)!
// Never -> Void so we can work with it
let base: Declaration<Void> = extracted.map { _ in () }

// map is also available per signature type
let sig: FunctionSignature<Never> = Extractor.extract(funcDecl)
let withVoid: FunctionSignature<Void> = sig.map { _ in () }
```

## API Reference

### Core Types

| Type | Purpose | Renders to |
|------|---------|------------|
| `Template<A>` | Expression-level templates | `ExprSyntax` |
| `TemplateArgument<A>` | Typed call/subscript arguments for fluent APIs | (embedded in `Template`) |
| `Statement<A>` | Statement-level templates | `CodeBlockItemSyntax` |
| `Declaration<A>` | Declaration-level templates | `DeclSyntax` |
| `GenericParameterSignature` | Generic parameters and parameter packs | (embedded in declaration signatures) |
| `AttributeSignature` | Common `@...` attributes on declarations, parameters, and closures | (embedded in signatures) |
| `LiteralValue` | Integer, double, string, bool, nil | (embedded in `Template`) |
| `Renderer` | Pure rendering functions | -- |
| `Extractor` | Converts `DeclSyntax` back into the kit's typed model | -- |

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

Fluent factory shortcuts are available for common patterns: `Template.call(_:arguments:)`, `Template.property(_:)`, `Template.method(_:, arguments:)`, `Template.trying()`, `Template.awaiting()`, `Template.tryAwait()`, `Template.unwrapped()`, `Template.array(_:)`, `Template.closure(params:returnType:body:)`, `Template<Void>.variable(_:)`, and more. See `Template+FluentFactories.swift`.

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

### Extractor

```swift
// Returns the first declaration, or nil for unsupported kinds
Extractor.extract(_ decl: DeclSyntax) -> Declaration<Never>?

// Returns all declarations (multi-binding variables produce multiple results)
Extractor.extractAll(_ decl: DeclSyntax) -> [Declaration<Never>]

// Typed overloads for each declaration kind
Extractor.extract(_ decl: FunctionDeclSyntax)    -> FunctionSignature<Never>
Extractor.extract(_ decl: InitializerDeclSyntax) -> InitializerSignature<Never>
Extractor.extract(_ decl: ExtensionDeclSyntax)   -> ExtensionSignature<Never>
Extractor.extract(_ decl: StructDeclSyntax)      -> StructSignature<Never>
Extractor.extract(_ decl: EnumDeclSyntax)        -> EnumSignature<Never>
Extractor.extract(_ decl: TypeAliasDeclSyntax)   -> TypeAliasSignature
Extractor.extract(_ decl: VariableDeclSyntax)    -> [Declaration<Never>]
```

Extracted declarations have empty bodies. Use `declaration.map { _ in () }` to convert `Declaration<Never>` to `Declaration<Void>`, then use wither methods to attach bodies and modify the signature.

### Signature Types

| Type | Key Properties |
|------|---------------|
| `FunctionSignature<A>` | `attributes`, `name`, `genericParameters`, `parameters`, `isAsync`, `canThrow`, `returnType`, `whereRequirements`, `body`, `accessLevel`, `isStatic`, `isMutating` |
| `ParameterSignature` | `label`, `name`, `type`, `attributes`, `isInout`, `defaultValue` |
| `PropertySignature<A>` | `attributes`, `name`, `type`, `isLet`, `isStatic`, `initializer`, `accessLevel` |
| `ComputedPropertySignature<A>` | `attributes`, `name`, `type`, `getter`, `setter`, `isStatic`, `accessLevel` |
| `ClosureSignature<A>` | `attributes`, `parameters`, `returnType`, `body` |
| `ExtensionSignature<A>` | `accessLevel`, `typeName`, `conformances`, `whereRequirements`, `members` |
| `StructSignature<A>` | `attributes`, `name`, `genericParameters`, `conformances`, `whereRequirements`, `members`, `accessLevel` |
| `EnumSignature<A>` | `attributes`, `name`, `genericParameters`, `conformances`, `whereRequirements`, `cases`, `members`, `accessLevel` |
| `EnumCaseSignature` | `name`, `rawValue`, `associatedTypes` |
| `TypeAliasSignature` | `attributes`, `name`, `genericParameters`, `existingType`, `whereRequirements`, `accessLevel` |
| `InitializerSignature<A>` | `attributes`, `genericParameters`, `parameters`, `canThrow`, `isFailable`, `whereRequirements`, `body`, `accessLevel` |
| `GenericParameterSignature` | `name`, `isParameterPack`, `constraint` |
| `WhereRequirement` | `leftType`, `relation`, `rightType` plus compatibility accessors |
| `AttributeSignature` | `name`, `arguments` plus helpers like `.escaping`, `.sendable`, `.mainActor`, `.available(...)` |
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
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.6"),
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

- select version `0.0.6` or later to consume the binary release
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

Bruno da Gama Porciuncula ([@brunogama](https://github.com/brunogama))
