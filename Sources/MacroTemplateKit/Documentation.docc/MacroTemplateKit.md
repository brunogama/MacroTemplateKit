# ``MacroTemplateKit``

A structured, type-safe AST for generating Swift macro output without string interpolation.

## Overview

MacroTemplateKit replaces string interpolation in Swift macros with a three-layer algebraic data type that renders directly to SwiftSyntax nodes. Every template is syntactically correct by construction -- no mismatched braces, missing commas, or malformed output.

The library provides three core types that mirror Swift's own syntax hierarchy:

- ``Template`` -- expression-level constructs, renders to `ExprSyntax`
- ``Statement`` -- statement-level constructs, renders to `CodeBlockItemSyntax`
- ``Declaration`` -- declaration-level constructs, renders to `DeclSyntax`

All three types are generic over a payload parameter `A` that carries compile-time metadata through the template without affecting rendered output. Use ``Template/map(_:)`` to transform or discard metadata before rendering.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ThreeLayerAST>

### Templates

- ``Template``
- ``LiteralValue``
- ``StringInterpolationSegment``
- ``ClosureSignature``

### Statements

- ``Statement``
- ``SwitchCase``
- ``SwitchCasePattern``

### Declarations

- ``Declaration``
- ``FunctionSignature``
- ``ParameterSignature``
- ``PropertySignature``
- ``ComputedPropertySignature``
- ``SetterSignature``
- ``ExtensionSignature``
- ``StructSignature``
- ``InitializerSignature``
- ``WhereRequirement``
- ``AccessLevel``

### Rendering

- ``Renderer``

### Result Builders

- ``TemplateBuilder``
