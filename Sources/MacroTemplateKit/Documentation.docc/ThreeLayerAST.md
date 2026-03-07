# The Three-Layer AST

Understand how Template, Statement, and Declaration map to SwiftSyntax and compose together.

## Overview

MacroTemplateKit organizes code generation into three layers that mirror Swift's own syntax hierarchy. Each layer contains only the constructs that belong at that level, and the type system enforces correct composition.

```
Your code                     SwiftSyntax output
─────────────────────────     ──────────────────────────
Declaration<A>          ───>  DeclSyntax
   └─ contains
Statement<A>            ───>  CodeBlockItemSyntax
   └─ contains
Template<A>             ───>  ExprSyntax
```

## Template -- Expressions

``Template`` represents expression-level constructs: literals, variable references, function calls, property access, binary operations, closures, and more. Every ``Template`` renders to an `ExprSyntax`.

```swift
let call: ExprSyntax = Renderer.render(
    Template<Void>.functionCall(
        function: "fetchUser",
        arguments: [
            (label: "id", value: .variable("userId"))
        ]
    )
)
```

## Statement -- Control Flow and Bindings

``Statement`` wraps ``Template`` expressions with control flow, bindings, and guard clauses. Each ``Statement`` renders to a `CodeBlockItemSyntax`.

Statements contain templates:

```swift
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
```

## Declaration -- Top-Level Constructs

``Declaration`` represents functions, properties, extensions, structs, enums, type aliases, and initializers. It provides 8 cases: `.function`, `.property`, `.computedProperty`, `.extensionDecl`, `.structDecl`, `.enumDecl`, `.typeAlias`, and `.initDecl`. A declaration body is an array of ``Statement`` values. Each ``Declaration`` renders to a `DeclSyntax`.

Use ``EnumSignature`` and ``EnumCaseSignature`` to build enum declarations, and ``TypeAliasSignature`` for type alias declarations. Both are covered by ``Declaration``'s `map` implementation, so payload transformations flow through them automatically.

Declarations contain statements, which contain templates:

```swift
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

## The Payload Parameter

All three layers share the same type parameter `A`. `Void` is the default when you do not need metadata. When you do, the payload attaches to each `.variable` case and flows through `map` transformations. The renderer ignores it entirely -- a `Template<Int>` and a `Template<String>` with the same variable name produce identical output.

Use the payload to carry metadata during template construction (type information, source locations, validation state), then discard it with `map { _ in () }` before rendering.

## Functor Laws

All three types satisfy the functor laws: `map(id) == id` and `map(f . g) == map(f) . map(g)`. This guarantees that transforming payloads never changes template structure.
