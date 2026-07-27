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
let decl: DeclSyntax = try Renderer.render(
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
- **Deterministic rendering.** `Renderer.render` is a pure function of its input, but it `throws`: if the renderer ever produces source that does not parse, it fails loudly with a `RenderError` naming MacroTemplateKit as the culprit rather than handing the compiler a broken tree that gets blamed on your macro. The same template always produces the same syntax. This makes macro output straightforward to test.
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
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.1.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1")
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
let decl: DeclSyntax = try Renderer.render(
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

**Generate an initializer with a structural default:**

```swift
let initializer = Declaration<Void>.initDecl(
  InitializerSignature(
    accessLevel: .public,
    parameters: [
      ParameterSignature(
        name: "client",
        type: "any HTTPClient",
        defaultValue: .functionCall(function: "NetworkClient", arguments: [])
      )
    ],
    body: [
      .assignmentStatement(
        lhs: .propertyAccess(base: .variable("self", payload: ()), property: "client"),
        rhs: .variable("client", payload: ())
      )
    ]
  )
)
```

The default expression and initializer body share the declaration's payload, so
mapping the declaration transforms every reference as one structural unit.

For most macros, `Template<Void>`, `Statement<Void>`, and `Declaration<Void>` are the default path. Use a non-`Void` payload only when you want to carry compile-time metadata through template construction.

## Usage Examples

### Expressions

Build expressions with `.call`, chained `.property(_:)`, chained `.method(_:)`, `.binaryOperation`, and more. Every expression type renders to an `ExprSyntax`.

```swift
// fetchUser(id: userId, cache: true)
let call: ExprSyntax = try Renderer.render(
    Template<Void>.call(
        "fetchUser",
        arguments: [
            .labeled("id", .variable("userId")),
            .labeled("cache", .literal(true))
        ]
    )
)

// request.url.absoluteString
let chain: ExprSyntax = try Renderer.render(
    Template<Void>.variable("request")
        .property("url")
        .property("absoluteString")
)

// try await api.fetch(request)
let effect: ExprSyntax = try Renderer.render(
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
let binding: CodeBlockItemSyntax = try Renderer.render(
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
let guard_: CodeBlockItemSyntax = try Renderer.render(
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
let fn: DeclSyntax = try Renderer.render(
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
let register: DeclSyntax = try Renderer.render(
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

let callback: ExprSyntax = try Renderer.render(
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
let ext: DeclSyntax = try Renderer.render(
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
    return [try asyncVariant.rendered]
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

let variant: DeclSyntax = try original
    .withAccessLevel(.public)
    .withIsAsync(true)
    .withCanThrow(true)
    .withReturnType("User?")
    .addingParameter(ParameterSignature(label: "cache", name: "cache", type: "Bool"))
    .addingAttribute(.mainActor)
    .rendered  // shortcut for try Renderer.render(sig.asDeclaration)
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
let a: DeclSyntax = try Renderer.render(Declaration.function(sig))
let b: DeclSyntax = try sig.rendered  // shortcut
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
let expr: ExprSyntax = try Renderer.render(template.map { _ in () })
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
let expr: ExprSyntax = try Renderer.render(enriched.map { _ in () })
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
| `.cast(_:type:kind:)` | `expr as Type` / `as? Type` / `as! Type` |
| `.syntax(_:)` | An existing `ExprSyntax`, spliced in as-is |
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
try Renderer.render(_ template: Template<A>) -> ExprSyntax

// Statement
try Renderer.render(_ statement: Statement<A>) -> CodeBlockItemSyntax

// Multiple statements (for function bodies)
Renderer.renderStatements(_ statements: [Statement<A>]) throws -> CodeBlockItemListSyntax

// Declaration
try Renderer.render(_ declaration: Declaration<A>) -> DeclSyntax
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

**Rendered tokens are stable; concrete child node types are not.** The renderer guarantees the documented `ExprSyntax`, `DeclSyntax`, and `CodeBlockItemSyntax` wrappers and valid, precedence-correct source. SwiftParser leaves binary and ternary expressions as `SequenceExprSyntax` until SwiftOperators folds them, so callers should not assume an `InfixOperatorExprSyntax` or `TernaryExprSyntax` result. Fold explicitly when downstream logic requires those concrete nodes.

**No invalid states.** The API has no optional rendering path for well-formed input. Constructing a `Declaration.function` with `isAsync: true` always produces an `async` function declaration. There are no flags that silently produce incorrect output.

**Correct by construction where a string cannot be.** Because a `Template` is a tree rather than text, the renderer can inspect it and fix things a hand-written source string cannot. Nested operations are parenthesised according to Swift's precedence rules, so `.operation(.operation(a, "+", b), "*", c)` emits `(a + b) * c` rather than silently regrouping. Reserved keywords used as identifiers are backtick-escaped, so a property named `default` generates code that compiles. String literals are escaped with the right number of pound delimiters. A string has no structure to inspect, so its author has to get all of this right by hand, every time.

**Tradeoffs to know about.** MacroTemplateKit covers the common 90% of macro code generation patterns. If you need to emit syntax that falls outside the current case set -- raw attribute lists, `#if` directives, operator declarations -- you will need to drop down to SwiftSyntax directly. The library's types are designed to compose with handwritten SwiftSyntax: use `Template.syntax(_:)` to splice an existing `ExprSyntax` into a template, and use rendered output wherever a `DeclSyntax`, `ExprSyntax`, or `CodeBlockItemSyntax` is accepted.

**Custom operators need their precedence declared.** `Operator` accepts a string literal for the standard operators. For anything else, pass the precedence explicitly -- `Operator("|>", precedence: .multiplication)` -- or the renderer assumes the loosest binding and parenthesises every nesting defensively.

## Performance

Rendering goes through a source-text emitter and a single parse per fragment rather than per-node structural construction. Measured against hand-written SwiftSyntax initializers producing token-identical output, on two macro shapes at input sizes of 16/64/256, reported as `min` over 3 runs of 2000+ iterations:

| workload | shape | vs hand-rolled | vs hand-rolled, invariants hoisted |
|---|---|---|---|
| generate | accessor pairs over stored properties | 0.53--0.54x | **0.74x** |
| case-factory | static factories over enum cases | 0.57--0.58x | **1.00--1.02x** |
| case-path | `@CasePathable`-style `AnyCasePath` property per case | 0.42--0.43x | **0.67--0.69x** |

**Read the right-hand column.** The left one compares against a baseline that rebuilds expansion-invariant nodes -- the `static` modifier, both parens, the return type -- once per generated declaration. A macro author writing that by hand would hoist them, and hoisting alone makes the case-factory baseline 38% faster. Crediting the library for that is crediting it for someone else's mistake.

So the honest summary is narrower than it first looked:

- On **generate**, the library is about 26% faster than a competently hand-rolled equivalent.
- On **case-factory**, it is **at parity or marginally slower** (1.00--1.02x). The apparent 0.6x there was almost entirely baseline error. An earlier version of this table claimed 0.94--0.96x; re-measuring every pipeline in a single process, rather than comparing numbers collected in different sessions, moved it above 1.0. Cross-session drift on this workload is ~10% for identical code, which is larger than the effect, so treat any sub-5% claim about it as unsupported --- including a favourable one.
- On **case-path** -- the shape a TCA-style app pays for every case of every `@CasePathable` action enum -- it is about **32% faster even against the hoisted baseline**. The pattern behind all three rows: the deeper the generated declaration, the better the library does. Structural construction pays per node (~70 of them per case-path property, closures inside labeled arguments inside a generic getter); the emitter appends text and parses once per declaration. Hoisting cannot close that gap, because most of the tree varies per case at the leaves but must still be assembled per case.

What survives, and it is the claim that matters: **using the library is no longer a performance tax.** Before this work MacroTemplateKit ran at 0.98--0.99x versus assembling nodes by hand, so it cost nothing and bought nothing. It now ranges from parity to a comfortable win, depending on shape. It is not a free speedup, and this README is not going to tell you it is.

Caveats, stated plainly:

- These are per-expansion figures in the microsecond range. Across a large project they are worth tens of milliseconds of build time, which nobody will notice. Choose this library for what it lets you express, not to speed up your builds.
- **Trivia is now matched on every baseline, and it moved the numbers in our favour.** The baselines used to attach no trivia at all, emitting `staticfuncmakeCase0(_value:String)` where the library emits spaced source; the equivalence gate compares token streams, so it could not see this. All six baselines now emit comparable whitespace, with `interned-notrivia` kept as a control to measure the difference in the same process. On `case-factory` it is worth 1--4%, which is why it was written off as negligible; on `case-path`, which has far more whitespace, it is worth ~8% and moved that row from 0.75x to 0.68x. Stated plainly because it is a correction that flatters us: it was predicted, deferred as self-serving, then measured. Inspect with `--workloads trivia`.
- **The `case-path` benchmark uses the typed `MatchPattern`, not the raw-source escape hatch**, because a benchmark that reaches for `.variable` measures a library you would not actually write with. Switching to it appeared to cost ~10% at the time, but that comparison spanned two benchmark sessions and does not meet the bar ADR 0005 clause 0 now sets, so no cost is claimed here. `.variable` remains available for raw source.
- The baselines are hand-written implementations maintained in this repository. An earlier version of this section warned that a SwiftSyntax expert might beat them and narrow these ratios. That is exactly what happened, to us, on our own baseline -- see [ADR 0004](docs/adr/0004-baselines-must-hoist-invariants.md). Treat the remaining margin as an upper bound.
- **There is no memory claim here, deliberately.** The benchmark does report a ~0.56x figure for bytes retained per expansion, and earlier versions of this table printed it. It does not reach you. A plugin serialises each expansion to source and drops the tree, so peak memory is one expansion's worth no matter how many expansions a build performs -- measured flat across a 2048x sweep, from 64 to 131072 expansions. The difference between pipelines is real per live tree and is then multiplied by a count that is always 1. See [ADR 0003](docs/adr/0003-memory-win-does-not-accumulate.md). Time is the claim, because time is the thing that adds up.

Reproduce with `swift build -c release --package-path Benchmarks && Benchmarks/.build/release/RenderEngineBench`. Every pipeline is gated on producing token-identical output, so the comparison is like for like.

## Requirements

- Swift 5.10+ (Swift 6.x recommended for contributors)
- SwiftSyntax 600.0.1 through the 6xx release line
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+

## Installation

### Swift Package Manager

For downstream macro packages, prefer the tagged binary release:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.1.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1")
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

- select version `0.1.0` or later to consume the binary release
- use a branch or local checkout only when developing MacroTemplateKit itself

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Local Development

To match CI locally (format, lint, build, test):

```bash
./Scripts/bootstrap.sh
./Scripts/ci-local.sh
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT License. See [LICENSE](LICENSE).

## Author

Bruno da Gama Porciuncula ([@brunogama](https://github.com/brunogama))
