# MacroTemplateKit

[![CI](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml/badge.svg)](https://github.com/brunogama/MacroTemplateKit/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-blue.svg)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A type-safe, functional templating engine for Swift macro code generation.

MacroTemplateKit provides a **parametric algebraic data type** (ADT) that separates template structure from metadata, enabling compile-time safety, composability, and mathematical guarantees through functor laws.

## Why MacroTemplateKit?

Traditional macro implementations rely on **string interpolation** to generate Swift code:

```swift
// Traditional approach - fragile and error-prone
let code = """
func \(name)(\(params)) async throws -> \(returnType) {
    let result = try await \(call)
    return result
}
"""
```

**Problems with string interpolation:**
- No compile-time validation of generated syntax
- Easy to produce malformed code (missing commas, unbalanced braces)
- Difficult to compose and transform templates
- No type safety for variable references
- Hard to test and reason about

MacroTemplateKit solves these problems with a **structured AST approach**:

```swift
// MacroTemplateKit approach - type-safe and composable
let template: Declaration<Void> = .function(FunctionSignature(
    name: name,
    parameters: params,
    isAsync: true,
    canThrow: true,
    returnType: returnType,
    body: [
        .letBinding(name: "result", type: nil, initializer: call),
        .returnStatement(.variable("result", payload: ()))
    ]
))

let syntax: DeclSyntax = Renderer.render(template)
```

## Architecture

MacroTemplateKit provides a **three-layer AST** that mirrors Swift's syntax structure:

```
Declaration<A>  ──────►  DeclSyntax
       │                      │
       │ contains             │ SwiftSyntax
       ▼                      ▼
 Statement<A>   ──────►  CodeBlockItemSyntax
       │                      │
       │ contains             │
       ▼                      ▼
  Template<A>   ──────►  ExprSyntax
```

### Layer 1: Template<A> (Expressions)

Represents expression-level constructs:

| Case | Description | SwiftSyntax Equivalent |
|------|-------------|------------------------|
| `.literal(LiteralValue)` | Primitive values | `IntegerLiteralExprSyntax`, etc. |
| `.variable(String, payload: A)` | Identifier reference | `DeclReferenceExprSyntax` |
| `.conditional(condition:thenBranch:elseBranch:)` | Ternary expression | `TernaryExprSyntax` |
| `.loop(variable:collection:body:)` | Iteration (forEach) | `FunctionCallExprSyntax` |
| `.functionCall(function:arguments:)` | Function invocation | `FunctionCallExprSyntax` |
| `.methodCall(base:method:arguments:)` | Method invocation | `FunctionCallExprSyntax` |
| `.binaryOperation(left:operator:right:)` | Infix operation | `InfixOperatorExprSyntax` |
| `.propertyAccess(base:property:)` | Member access | `MemberAccessExprSyntax` |
| `.arrayLiteral([Template])` | Array literal | `ArrayExprSyntax` |

### Layer 2: Statement<A> (Statements)

Represents statement-level constructs:

| Case | Description | SwiftSyntax Equivalent |
|------|-------------|------------------------|
| `.letBinding(name:type:initializer:)` | Let declaration | `VariableDeclSyntax` |
| `.varBinding(name:type:initializer:)` | Var declaration | `VariableDeclSyntax` |
| `.guardStatement(condition:elseBody:)` | Guard statement | `GuardStmtSyntax` |
| `.ifStatement(condition:thenBody:elseBody:)` | If statement | `IfExprSyntax` |
| `.returnStatement(Template?)` | Return statement | `ReturnStmtSyntax` |
| `.throwStatement(Template)` | Throw statement | `ThrowStmtSyntax` |
| `.deferStatement([Statement])` | Defer block | `DeferStmtSyntax` |
| `.expression(Template)` | Expression statement | `ExprSyntax` |

### Layer 3: Declaration<A> (Declarations)

Represents top-level declaration constructs:

| Case | Description | SwiftSyntax Equivalent |
|------|-------------|------------------------|
| `.function(FunctionSignature)` | Function declaration | `FunctionDeclSyntax` |
| `.property(PropertySignature)` | Stored property | `VariableDeclSyntax` |
| `.computedProperty(ComputedPropertySignature)` | Computed property | `VariableDeclSyntax` |
| `.extensionDecl(ExtensionSignature)` | Extension | `ExtensionDeclSyntax` |
| `.structDecl(StructSignature)` | Struct declaration | `StructDeclSyntax` |
| `.initDecl(InitializerSignature)` | Initializer | `InitializerDeclSyntax` |

## Key Benefits

### 1. Type Safety

Templates are **statically typed**. Invalid constructs fail at compile time:

```swift
// Compile error: Cannot convert Template<String> to Template<Int>
let template: Template<Int> = .variable("x", payload: "wrong type")
```

### 2. Parametric Metadata

The type parameter `A` allows attaching **compile-time metadata** to variable references without affecting rendering:

```swift
// Track variable types for validation
struct VarInfo { let type: String; let scope: Scope }

let template: Template<VarInfo> = .variable("user", payload: VarInfo(type: "User", scope: .local))

// Metadata is preserved through transformations, discarded at render time
let syntax = Renderer.render(template)  // Just renders "user"
```

### 3. Functor Laws

All three types (`Template`, `Statement`, `Declaration`) are **functors** that satisfy mathematical laws:

```swift
// Identity Law: template.map { $0 } == template
let t1 = template.map { $0 }
assert(t1 == template)

// Composition Law: template.map(f).map(g) == template.map { g(f($0)) }
let t2 = template.map(f).map(g)
let t3 = template.map { g(f($0)) }
assert(t2 == t3)
```

This enables **safe, predictable transformations**:

```swift
// Transform payloads without changing structure
let enriched: Template<EnrichedInfo> = template.map { info in
    EnrichedInfo(original: info, lineNumber: currentLine)
}
```

### 4. Pure Rendering

The `Renderer` provides **pure functions** (natural transformations) from templates to SwiftSyntax:

```swift
// Expression rendering
let expr: ExprSyntax = Renderer.render(template)

// Statement rendering
let stmt: CodeBlockItemSyntax = Renderer.render(statement)

// Declaration rendering
let decl: DeclSyntax = Renderer.render(declaration)
```

No side effects, no hidden state - rendering is deterministic and testable.

### 5. Composability

Templates compose naturally:

```swift
// Build complex expressions from simple ones
let base: Template<Void> = .variable("request", payload: ())
let property: Template<Void> = .propertyAccess(base: base, property: "url")
let call: Template<Void> = .methodCall(
    base: property,
    method: "absoluteString",
    arguments: []
)

// Result: request.url.absoluteString
```

### 6. Result Builder DSL

Declarative syntax with `@TemplateBuilder`:

```swift
@TemplateBuilder<Void> var body: Template<Void> {
    Template.function("configure") {
        Template.property("timeout", on: "settings")
        Template.literal(30)
    }
}
```

## Usage Examples

### Basic Expression Generation

```swift
import MacroTemplateKit
import SwiftSyntax

// Create a function call: fetchUser(id: userId, cache: true)
let template: Template<Void> = .functionCall(
    function: "fetchUser",
    arguments: [
        (label: "id", value: .variable("userId", payload: ())),
        (label: "cache", value: .literal(.boolean(true)))
    ]
)

let syntax: ExprSyntax = Renderer.render(template)
print(syntax.description)  // fetchUser(id: userId, cache: true)
```

### Statement Generation

```swift
// Generate: let result = try await api.fetch(request)
let statement: Statement<Void> = .letBinding(
    name: "result",
    type: nil,
    initializer: .methodCall(
        base: .variable("api", payload: ()),
        method: "fetch",
        arguments: [(label: nil, value: .variable("request", payload: ()))]
    )
)

let syntax: CodeBlockItemSyntax = Renderer.render(statement)
```

### Complete Function Declaration

```swift
// Generate a complete async function
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
        .letBinding(
            name: "data",
            type: nil,
            initializer: .methodCall(
                base: .variable("api", payload: ()),
                method: "fetch",
                arguments: [(label: "id", value: .variable("id", payload: ()))]
            )
        ),
        .returnStatement(.functionCall(
            function: "User",
            arguments: [(label: "from", value: .variable("data", payload: ()))]
        ))
    ]
))

let syntax: DeclSyntax = Renderer.render(function)
// public func loadUser(with id: String) async throws -> User {
//     let data = api.fetch(id: id)
//     return User(from: data)
// }
```

### Using Fluent Factories

```swift
// Fluent API for common patterns
let expr = Template<Void>.function("print", .literal("Hello"), .variable("name", payload: ()))
let prop = Template<Void>.property("count", on: .variable("array", payload: ()))
let ternary = Template<Void>.ternary(
    if: .variable("isEnabled", payload: ()),
    then: .literal("Yes"),
    else: .literal("No")
)
```

### Metadata Tracking

```swift
// Track variable origins for error reporting
struct Origin {
    let file: String
    let line: Int
}

let template: Template<Origin> = .binaryOperation(
    left: .variable("x", payload: Origin(file: "main.swift", line: 42)),
    operator: "+",
    right: .variable("y", payload: Origin(file: "main.swift", line: 42))
)

// Extract all variables with their origins
func extractVariables<A>(_ template: Template<A>) -> [(String, A)] {
    // Recursive extraction...
}
```

## Installation

### Swift Package Manager

Add MacroTemplateKit to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "0.0.1")
]
```

Then add it as a dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit")
    ]
)
```

For macro implementations, add it to your macro target:

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

### Xcode

1. Open your project in Xcode
2. Go to **File > Add Package Dependencies...**
3. Enter the repository URL: `https://github.com/brunogama/MacroTemplateKit.git`
4. Select version **0.0.1** or later
5. Click **Add Package**

## Design Philosophy

### Algebraic Data Types

MacroTemplateKit uses **sum types** (enums) to represent all possible template forms. This ensures:
- **Exhaustive pattern matching** - the compiler verifies all cases are handled
- **No invalid states** - only representable templates are valid
- **Self-documenting** - the type signature describes capabilities

### Natural Transformations

The `Renderer` implements **natural transformations** from the Template functor to SwiftSyntax:

```
η : Template<A> ──► ExprSyntax
```

Natural transformations preserve structure: rendering a composed template equals composing rendered parts.

### Separation of Concerns

- **Template<A>**: Pure data structure representing code shape
- **Renderer**: Pure transformation to SwiftSyntax
- **Payload A**: Compile-time metadata, invisible at runtime

## API Reference

### Core Types

| Type | Purpose |
|------|---------|
| `Template<A>` | Expression-level template (functor) |
| `Statement<A>` | Statement-level template (functor) |
| `Declaration<A>` | Declaration-level template (functor) |
| `LiteralValue` | Sum type for primitive literals |
| `Renderer` | Natural transformation to SwiftSyntax |

### Signature Types

| Type | Purpose |
|------|---------|
| `FunctionSignature<A>` | Function declaration components |
| `ParameterSignature` | Function parameter definition |
| `PropertySignature<A>` | Stored property components |
| `ComputedPropertySignature<A>` | Computed property with accessors |
| `SetterSignature<A>` | Property setter definition |
| `ExtensionSignature<A>` | Extension declaration components |
| `StructSignature<A>` | Struct declaration components |
| `InitializerSignature<A>` | Initializer declaration components |
| `AccessLevel` | Swift access control modifiers |

### Result Builders

| Type | Purpose |
|------|---------|
| `TemplateBuilder<A>` | DSL for declarative template construction |

## Requirements

- Swift 6.0+
- SwiftSyntax 600.0+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

MIT License. See [LICENSE](LICENSE) file for details.

## Author

Bruno Rocha ([@brunogama](https://github.com/brunogama))
