# Changelog

All notable changes to MacroTemplateKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2026-02-15

### Added

- **Template<A>**: Parametric algebraic data type for expression-level code generation
  - `.literal(LiteralValue)` - Integer, double, string, boolean, and nil literals
  - `.variable(String, payload: A)` - Identifier references with metadata
  - `.conditional(condition:thenBranch:elseBranch:)` - Ternary expressions
  - `.loop(variable:collection:body:)` - ForEach iteration patterns
  - `.functionCall(function:arguments:)` - Function invocations
  - `.methodCall(base:method:arguments:)` - Method invocations
  - `.binaryOperation(left:operator:right:)` - Infix operations
  - `.propertyAccess(base:property:)` - Member access chains
  - `.variableDeclaration(name:type:initializer:)` - Variable declarations
  - `.arrayLiteral([Template])` - Array literal expressions

- **Statement<A>**: Statement-level code generation templates
  - `.letBinding(name:type:initializer:)` - Let declarations
  - `.varBinding(name:type:initializer:)` - Var declarations
  - `.guardStatement(condition:elseBody:)` - Guard statements
  - `.ifStatement(condition:thenBody:elseBody:)` - If statements
  - `.returnStatement(Template?)` - Return statements
  - `.throwStatement(Template)` - Throw statements
  - `.deferStatement([Statement])` - Defer blocks
  - `.expression(Template)` - Expression statements

- **Declaration<A>**: Top-level declaration templates
  - `.function(FunctionSignature)` - Function declarations
  - `.property(PropertySignature)` - Stored properties
  - `.computedProperty(ComputedPropertySignature)` - Computed properties
  - `.extensionDecl(ExtensionSignature)` - Extension declarations
  - `.structDecl(StructSignature)` - Struct declarations
  - `.initDecl(InitializerSignature)` - Initializer declarations

- **Renderer**: Pure transformation from templates to SwiftSyntax
  - `render(_: Template<A>) -> ExprSyntax`
  - `render(_: Statement<A>) -> CodeBlockItemSyntax`
  - `render(_: Declaration<A>) -> DeclSyntax`
  - `renderStatements(_: [Statement<A>]) -> CodeBlockItemListSyntax`

- **Functor support**: All template types implement `map` satisfying functor laws
- **Equatable/Hashable**: Full conformance for all template types
- **Sendable**: Thread-safe templates when payload is Sendable

- **TemplateBuilder**: Result builder for declarative template construction
- **Fluent factories**: Convenient static methods for common patterns

- **LiteralValue**: Sum type for primitive literal values
- **AccessLevel**: Swift access control modifier representation
- **Signature types**: FunctionSignature, ParameterSignature, PropertySignature, etc.

### Documentation

- Comprehensive README with architecture overview
- API documentation with DocC comments
- Usage examples for all major features

[Unreleased]: https://github.com/brunogama/MacroTemplateKit/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/brunogama/MacroTemplateKit/releases/tag/v0.0.1
