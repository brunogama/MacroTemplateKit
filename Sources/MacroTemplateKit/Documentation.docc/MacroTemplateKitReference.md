# MacroTemplateKit Reference

Technical reference for the typed models used to generate Swift macro output.

## ``Template``

An expression-level template. A `Template<A>` renders to `ExprSyntax` and may carry a payload of type `A`.

Use it for:

- Variables and literals
- Function and method calls
- Property access
- Binary operations
- Closures
- `try` and `await` expressions

Create templates with the static factories on ``Template`` or with its fluent factories. Use ``Template/map(_:)`` to transform the payload while preserving the template structure.

## ``TemplateArgument``

Represents one argument in a call. Use labeled arguments when the generated call needs a label and unlabeled arguments otherwise.

```swift
let arguments: [TemplateArgument<Void>] = [
    .labeled("id", .variable("userId")),
    .unlabeled(.variable("options"))
]
```

## ``Statement``

A statement-level template. A `Statement<A>` renders to `CodeBlockItemSyntax` and can contain ``Template`` values for bindings, returns, assignments, control flow, and other code-block constructs.

## ``Declaration``

A declaration-level template. A `Declaration<A>` renders to `DeclSyntax`.

The available declaration cases include:

- `.function`
- `.property`
- `.computedProperty`
- `.extensionDecl`
- `.structDecl`
- `.enumDecl`
- `.typeAlias`
- `.initDecl`

Declaration signatures such as ``FunctionSignature`` and ``PropertySignature`` describe names, parameters, modifiers, generic clauses, attributes, and bodies.

## Payloads and `map`

`Template`, `Statement`, and `Declaration` share the payload type parameter `A`. Payloads are compile-time metadata; they do not affect rendered syntax.

Use `Void` when no metadata is needed. Use a domain-specific payload while constructing or validating a template, then transform it before rendering:

```swift
let template: Template<String> = .variable("name", payload: "source metadata")
let renderable: Template<Void> = template.map { _ in () }
```

## ``Renderer``

Renders a ``Template`` to `ExprSyntax`, a ``Statement`` to `CodeBlockItemSyntax`, or a ``Declaration`` to `DeclSyntax`.

Rendering is throwing. Handle ``RenderError`` at the macro boundary and avoid emitting output after a failed render.

## ``StatementRenderer`` and ``DeclarationRenderer``

These specialized renderers provide statement- and declaration-level rendering when a call site benefits from an explicit renderer type. ``Renderer`` is the general entry point for all three layers.

## ``Extractor``

Converts supported SwiftSyntax declarations into typed ``Declaration`` values. Extraction is useful when a macro needs to inspect or transform an existing declaration.

``Extractor/extractAll(_:)`` returns one result for each binding in a multi-binding variable declaration. Extracted declarations preserve structural information but do not preserve executable bodies; attach replacement statements before rendering.

## Signature Types

Signature types model declaration details independently from the declaration enum:

- ``FunctionSignature`` — function name, parameters, modifiers, generics, requirements, and body
- ``PropertySignature`` — stored property declarations
- ``ComputedPropertySignature`` — computed properties and accessors
- ``InitializerSignature`` — initializer parameters and body
- ``ExtensionSignature`` — extension name, conformances, generics, and requirements
- ``StructSignature`` — struct name, conformances, and members
- ``EnumSignature`` — enum name, conformances, and cases
- ``TypeAliasSignature`` — type-alias name, target type, and generics

Most signatures provide wither methods for creating modified copies without mutating the original value.

## ``TemplateBuilder``

A result builder for assembling collections of template components in a declarative style. Use it when a macro’s generated body is easier to read as a sequence of conditional or grouped pieces.

## Compatibility

MacroTemplateKit is a compile-time dependency for Swift macro implementations. Its rendered output uses SwiftSyntax types, so the MacroTemplateKit release and SwiftSyntax dependency must be compatible with the selected Swift toolchain.
