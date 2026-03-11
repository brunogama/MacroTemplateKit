import SwiftSyntax

extension FunctionSignature where A: Sendable {
    /// Wraps this signature in a `.function` declaration case.
    public var asDeclaration: Declaration<A> { .function(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension InitializerSignature where A: Sendable {
    /// Wraps this signature in an `.initDecl` declaration case.
    public var asDeclaration: Declaration<A> { .initDecl(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension PropertySignature where A: Sendable {
    /// Wraps this signature in a `.property` declaration case.
    public var asDeclaration: Declaration<A> { .property(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension ComputedPropertySignature where A: Sendable {
    /// Wraps this signature in a `.computedProperty` declaration case.
    public var asDeclaration: Declaration<A> { .computedProperty(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension ExtensionSignature where A: Sendable {
    /// Wraps this signature in an `.extensionDecl` declaration case.
    public var asDeclaration: Declaration<A> { .extensionDecl(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension StructSignature where A: Sendable {
    /// Wraps this signature in a `.structDecl` declaration case.
    public var asDeclaration: Declaration<A> { .structDecl(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension EnumSignature where A: Sendable {
    /// Wraps this signature in an `.enumDecl` declaration case.
    public var asDeclaration: Declaration<A> { .enumDecl(self) }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration) }
}

extension TypeAliasSignature {
    /// Wraps this signature in a `.typeAlias` declaration case.
    ///
    /// `TypeAliasSignature` is not generic, so the resulting declaration
    /// can use any payload type.
    public func asDeclaration<A: Sendable>(_ payloadType: A.Type = Never.self) -> Declaration<A> {
        .typeAlias(self)
    }

    /// Renders this signature directly to `DeclSyntax`.
    public var rendered: DeclSyntax { Renderer.render(asDeclaration()) }
}
