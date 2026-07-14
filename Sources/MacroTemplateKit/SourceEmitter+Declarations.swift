import SwiftSyntax
import SwiftSyntaxBuilder

/// Declaration-level counterpart to `SourceEmitter`'s `Template` and
/// `Statement` emission (`SourceEmitter.swift` / `SourceEmitter+Statements.swift`,
/// Tasks 3/4): walks `Declaration<A>` values appending Swift source text to a
/// buffer, delegating to `emit(_: Template<A>, into:)` / `emit(_: Statement<A>,
/// into:)` / `emitStatements(_:into:)` for every embedded expression and
/// statement body. `Renderer.renderParsed(_: Declaration<A>)`
/// (`DeclarationRenderer.swift`) parses the resulting buffer once per
/// declaration.
///
/// Every helper here transcribes the token sequence the legacy structural
/// renderer (`DeclarationRenderer.swift`) builds for the corresponding
/// signature type — field order and optionality mirror those `render...`
/// functions exactly, since token parity (not visual similarity) is the bar.
extension SourceEmitter {
    static func emit<A: Sendable>(_ declaration: Declaration<A>, into buffer: inout String) {
        switch declaration {
        case .function(let signature):
            // Legacy (`renderFunction`): FunctionDeclSyntax(attributes,
            // modifiers, name, genericParameterClause, signature(params,
            // effectSpecifiers(async, throws), returnClause),
            // genericWhereClause, body).
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, isStatic: signature.isStatic, isMutating: signature.isMutating, into: &buffer)
            buffer.append("func ")
            buffer.append(signature.name)
            emit(genericParameters: signature.genericParameters, into: &buffer)
            buffer.append("(")
            emit(parameters: signature.parameters, into: &buffer)
            buffer.append(")")
            if signature.isAsync { buffer.append(" async") }
            if signature.canThrow { buffer.append(" throws") }
            if let returnType = signature.returnType {
                buffer.append(" -> ")
                buffer.append(returnType)
            }
            emit(whereRequirements: signature.whereRequirements, into: &buffer)
            buffer.append(" {\n")
            emitStatements(signature.body, into: &buffer)
            buffer.append("}")

        case .property(let signature):
            // Legacy (`renderProperty`): VariableDeclSyntax(attributes,
            // modifiers(access, static), bindingSpecifier(let|var),
            // bindings: [pattern(name), typeAnnotation?, initializer?]).
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, isStatic: signature.isStatic, into: &buffer)
            buffer.append(signature.isLet ? "let " : "var ")
            buffer.append(signature.name)
            if let type = signature.type {
                buffer.append(": ")
                buffer.append(type)
            }
            if let initializer = signature.initializer {
                buffer.append(" = ")
                emit(initializer, into: &buffer)
            }

        case .computedProperty(let signature):
            // Legacy (`renderComputedProperty`): VariableDeclSyntax(attributes,
            // modifiers(access, static), bindingSpecifier(var), bindings:
            // [pattern(name), typeAnnotation(type), accessorBlock: { get { ... }
            // [set(parameterName) { ... }] }]). Note the setter's
            // `AccessorParametersSyntax(name:)` is always constructed when a
            // setter exists, so `set(parameterName)` always carries an
            // explicit parenthesized parameter name — even when
            // `parameterName` is the default `"newValue"` — never the bare
            // `set { ... }` shorthand. Replicated verbatim for parity.
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, isStatic: signature.isStatic, into: &buffer)
            buffer.append("var ")
            buffer.append(signature.name)
            buffer.append(": ")
            buffer.append(signature.type)
            buffer.append(" {\n")
            buffer.append("get {\n")
            emitStatements(signature.getter, into: &buffer)
            buffer.append("}\n")
            if let setter = signature.setter {
                buffer.append("set(")
                buffer.append(setter.parameterName)
                buffer.append(") {\n")
                emitStatements(setter.body, into: &buffer)
                buffer.append("}\n")
            }
            buffer.append("}")

        case .extensionDecl(let signature):
            // Legacy (`renderExtension`): ExtensionDeclSyntax(modifiers,
            // extendedType, inheritanceClause, genericWhereClause,
            // memberBlock) — no `attributes:` parameter is threaded through
            // (and `ExtensionSignature` carries no `attributes` field),
            // unlike every other declaration case here.
            emit(modifiers: signature.accessLevel, into: &buffer)
            buffer.append("extension ")
            buffer.append(signature.typeName)
            emit(conformances: signature.conformances, into: &buffer)
            emit(whereRequirements: signature.whereRequirements, into: &buffer)
            buffer.append(" {\n")
            emit(members: signature.members, into: &buffer)
            buffer.append("}")

        case .structDecl(let signature):
            // Legacy (`renderStruct`): StructDeclSyntax(attributes, modifiers,
            // name, genericParameterClause, inheritanceClause,
            // genericWhereClause, memberBlock).
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, into: &buffer)
            buffer.append("struct ")
            buffer.append(signature.name)
            emit(genericParameters: signature.genericParameters, into: &buffer)
            emit(conformances: signature.conformances, into: &buffer)
            emit(whereRequirements: signature.whereRequirements, into: &buffer)
            buffer.append(" {\n")
            emit(members: signature.members, into: &buffer)
            buffer.append("}")

        case .enumDecl(let signature):
            // Legacy (`renderEnum`): EnumDeclSyntax(attributes, modifiers,
            // name, genericParameterClause, inheritanceClause,
            // genericWhereClause, memberBlock: cases then members). Cases are
            // built by the legacy renderer as raw source text
            // (`renderEnumCaseDeclaration`) fed through
            // `DeclSyntax(stringLiteral:)` — `emit(_: EnumCaseSignature,
            // into:)` below transcribes that same text-building logic
            // directly rather than calling the (private, structural-only)
            // legacy helper.
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, into: &buffer)
            buffer.append("enum ")
            buffer.append(signature.name)
            emit(genericParameters: signature.genericParameters, into: &buffer)
            emit(conformances: signature.conformances, into: &buffer)
            emit(whereRequirements: signature.whereRequirements, into: &buffer)
            buffer.append(" {\n")
            for enumCase in signature.cases {
                emit(enumCase, into: &buffer)
                buffer.append("\n")
            }
            emit(members: signature.members, into: &buffer)
            buffer.append("}")

        case .typeAlias(let signature):
            // Legacy (`renderTypeAlias`): TypeAliasDeclSyntax(attributes,
            // modifiers, typealiasKeyword, name, genericParameterClause,
            // initializer(= existingType), genericWhereClause). The
            // structural renderer gives `typealiasKeyword` bespoke leading
            // trivia depending on whether an access-level keyword precedes
            // it, but that's whitespace-only and doesn't affect the token
            // stream `assertTokenParity` compares.
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, into: &buffer)
            buffer.append("typealias ")
            buffer.append(signature.name)
            emit(genericParameters: signature.genericParameters, into: &buffer)
            buffer.append(" = ")
            buffer.append(signature.existingType)
            emit(whereRequirements: signature.whereRequirements, into: &buffer)

        case .initDecl(let signature):
            // Legacy (`renderInitializer`): InitializerDeclSyntax(attributes,
            // modifiers, optionalMark, genericParameterClause, signature
            // (params, effectSpecifiers(throws)), genericWhereClause, body).
            // No `isAsync` field exists on `InitializerSignature` (unlike
            // `FunctionSignature`), so there is no `async` token to emit here.
            emit(attributes: signature.attributes, into: &buffer)
            emit(modifiers: signature.accessLevel, into: &buffer)
            buffer.append("init")
            if signature.isFailable { buffer.append("?") }
            emit(genericParameters: signature.genericParameters, into: &buffer)
            buffer.append("(")
            emit(parameters: signature.parameters, into: &buffer)
            buffer.append(")")
            if signature.canThrow { buffer.append(" throws") }
            emit(whereRequirements: signature.whereRequirements, into: &buffer)
            buffer.append(" {\n")
            emitStatements(signature.body, into: &buffer)
            buffer.append("}")
        }
    }

    /// Emits each member declaration in `members` followed by a newline, so
    /// consecutive member declarations inside a struct/enum/extension member
    /// block always have a lexical boundary between them — the
    /// declaration-level analogue of `emitStatements`'s per-statement
    /// newline (`SourceEmitter+Statements.swift`).
    private static func emit<A: Sendable>(members: [Declaration<A>], into buffer: inout String) {
        for member in members {
            emit(member, into: &buffer)
            buffer.append("\n")
        }
    }

    /// Text-emission counterpart to `Renderer.renderAttributes`
    /// (`Renderer+AttributeRendering.swift`): appends `@Name(args) ` for each
    /// attribute, reusing `Renderer.renderAttributeSource` for the exact
    /// `@Name(args)` token text an attribute lowers to (already reused this
    /// way by `SourceEmitter`'s closure-signature emission in
    /// `SourceEmitter.swift`, Task 3) — no need to duplicate its
    /// argument-source formatting here.
    private static func emit(attributes: [AttributeSignature], into buffer: inout String) {
        for attribute in attributes {
            buffer.append(Renderer.renderAttributeSource(attribute))
            buffer.append(" ")
        }
    }

    /// Text-emission counterpart to `Renderer.renderModifiers` plus the
    /// per-declaration `isStatic`/`isMutating` modifier list building found
    /// inline in `renderFunction`/`renderProperty`/`renderComputedProperty`
    /// (`DeclarationRenderer.swift`): emits `public `/`private `/`fileprivate `
    /// (nothing for `.internal`, matching `AccessLevel.keyword` returning
    /// `nil`), then `static `, then `mutating `, in that fixed order — the
    /// same order every legacy modifier-list builder appends them in.
    private static func emit(
        modifiers accessLevel: AccessLevel,
        isStatic: Bool = false,
        isMutating: Bool = false,
        into buffer: inout String
    ) {
        switch accessLevel {
        case .internal: break
        case .public: buffer.append("public ")
        case .private: buffer.append("private ")
        case .fileprivate: buffer.append("fileprivate ")
        }
        if isStatic { buffer.append("static ") }
        if isMutating { buffer.append("mutating ") }
    }

    /// Text-emission counterpart to `Renderer.renderGenericParameterClause`:
    /// emits `<P1, each P2: Constraint, ...>`, or nothing when
    /// `genericParameters` is empty (matching the legacy helper returning
    /// `nil` for an empty array, which SwiftSyntax renders as no clause at
    /// all).
    private static func emit(
        genericParameters: [GenericParameterSignature],
        into buffer: inout String
    ) {
        guard !genericParameters.isEmpty else { return }
        buffer.append("<")
        for (index, parameter) in genericParameters.enumerated() {
            if parameter.isParameterPack {
                buffer.append("each ")
            }
            buffer.append(parameter.name)
            if let constraint = parameter.constraint {
                buffer.append(": ")
                buffer.append(constraint)
            }
            if index != genericParameters.count - 1 { buffer.append(", ") }
        }
        buffer.append(">")
    }

    /// Text-emission counterpart to `Renderer.renderGenericWhereClause`:
    /// emits ` where L1: R1, L2 == R2, ...`, or nothing when
    /// `whereRequirements` is empty. `.conformance` lowers to `:` and
    /// `.sameType` to `==`, matching `ConformanceRequirementSyntax` /
    /// `SameTypeRequirementSyntax` respectively.
    private static func emit(
        whereRequirements: [WhereRequirement],
        into buffer: inout String
    ) {
        guard !whereRequirements.isEmpty else { return }
        buffer.append(" where ")
        for (index, requirement) in whereRequirements.enumerated() {
            buffer.append(requirement.leftType)
            switch requirement.relation {
            case .conformance: buffer.append(": ")
            case .sameType: buffer.append(" == ")
            }
            buffer.append(requirement.rightType)
            if index != whereRequirements.count - 1 { buffer.append(", ") }
        }
    }

    /// Text-emission counterpart to `Renderer.renderInheritanceClause`:
    /// emits `: P1, P2, ...`, or nothing when `conformances` is empty.
    private static func emit(conformances: [String], into buffer: inout String) {
        guard !conformances.isEmpty else { return }
        buffer.append(": ")
        buffer.append(conformances.joined(separator: ", "))
    }

    /// Text-emission counterpart to `Renderer.renderParameterList`: emits
    /// `[label ]name: [attrs ][inout ]Type[ = default][, ...]` per parameter,
    /// unparenthesized — callers wrap the result in `(...)`. Mirrors the
    /// legacy helper's `firstName`/`secondName` logic exactly: when `label`
    /// is present it becomes the first (external) name and `name` becomes
    /// the second (internal) name; when absent, `name` alone is both.
    private static func emit(parameters: [ParameterSignature], into buffer: inout String) {
        for (index, parameter) in parameters.enumerated() {
            if let label = parameter.label {
                buffer.append(label)
                buffer.append(" ")
                buffer.append(parameter.name)
            } else {
                buffer.append(parameter.name)
            }
            buffer.append(": ")
            if !parameter.attributes.isEmpty {
                buffer.append(parameter.attributes.map(Renderer.renderAttributeSource).joined(separator: " "))
                buffer.append(" ")
            }
            if parameter.isInout {
                buffer.append("inout ")
            }
            buffer.append(parameter.type)
            if let defaultValue = parameter.defaultValue {
                buffer.append(" = ")
                buffer.append(defaultValue)
            }
            if index != parameters.count - 1 { buffer.append(", ") }
        }
    }

    /// Text-emission counterpart to `Renderer.renderEnumCaseDeclaration`:
    /// emits `case name[(Type1, Type2)][ = "rawValue"]`. The legacy helper
    /// builds this same text and feeds it through `DeclSyntax(stringLiteral:)`
    /// — it does not escape `rawValue` before splicing it between quotes, so
    /// this transcription doesn't either; replicated verbatim for parity,
    /// not "fixed".
    private static func emit(_ enumCase: EnumCaseSignature, into buffer: inout String) {
        buffer.append("case ")
        buffer.append(enumCase.name)
        if !enumCase.associatedTypes.isEmpty {
            buffer.append("(")
            buffer.append(enumCase.associatedTypes.joined(separator: ", "))
            buffer.append(")")
        }
        if let rawValue = enumCase.rawValue {
            buffer.append(" = \"")
            buffer.append(rawValue)
            buffer.append("\"")
        }
    }
}
