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
  /// Dispatches each declaration case to a focused emitter while keeping this
  /// switch exhaustive over `Declaration`.
  static func emit<A: Sendable>(_ declaration: Declaration<A>, into buffer: inout String) {
    switch declaration {
    case .function(let signature):
      emitFunctionDeclaration(signature, into: &buffer)
    case .property(let signature):
      emitPropertyDeclaration(signature, into: &buffer)
    case .computedProperty(let signature):
      emitComputedPropertyDeclaration(signature, into: &buffer)
    case .extensionDecl(let signature):
      emitExtensionDeclaration(signature, into: &buffer)
    case .structDecl(let signature):
      emitStructDeclaration(signature, into: &buffer)
    case .enumDecl(let signature):
      emitEnumDeclaration(signature, into: &buffer)
    case .typeAlias(let signature):
      emitTypeAliasDeclaration(signature, into: &buffer)
    case .initDecl(let signature):
      emitInitializerDeclaration(signature, into: &buffer)
    }
  }

  // MARK: - Per-case emission

  /// Text counterpart to the legacy renderer's `renderFunction`.
  private static func emitFunctionDeclaration<A: Sendable>(
    _ signature: FunctionSignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(
      modifiers: signature.accessLevel,
      isStatic: signature.isStatic,
      isMutating: signature.isMutating,
      into: &buffer
    )
    buffer.append("func ")
    buffer.append(escapeIdentifier(signature.name))
    emit(genericParameters: signature.genericParameters, into: &buffer)
    buffer.append("(")
    emit(parameters: signature.parameters, into: &buffer)
    buffer.append(")")
    if signature.isAsync {
      buffer.append(" async")
    }
    emit(throwingEffect: signature.throwingEffect, into: &buffer)
    if let returnType = signature.returnType {
      buffer.append(" -> ")
      buffer.append(returnType)
    }
    emit(whereRequirements: signature.whereRequirements, into: &buffer)
    buffer.append(" {\n")
    emitStatements(signature.body, into: &buffer)
    buffer.append("}")
  }

  /// Text counterpart to the legacy renderer's `renderProperty`.
  private static func emitPropertyDeclaration<A: Sendable>(
    _ signature: PropertySignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, isStatic: signature.isStatic, into: &buffer)
    buffer.append(signature.isLet ? "let " : "var ")
    buffer.append(escapeIdentifier(signature.name))
    if let type = signature.type {
      buffer.append(": ")
      buffer.append(type)
    }
    if let initializer = signature.initializer {
      buffer.append(" = ")
      emit(initializer, into: &buffer)
    }
  }

  /// Text counterpart to the legacy renderer's `renderComputedProperty`.
  private static func emitComputedPropertyDeclaration<A: Sendable>(
    _ signature: ComputedPropertySignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, isStatic: signature.isStatic, into: &buffer)
    buffer.append("var ")
    buffer.append(escapeIdentifier(signature.name))
    buffer.append(": ")
    buffer.append(signature.type)
    buffer.append(" {\n")
    buffer.append("get {\n")
    emitStatements(signature.getter, into: &buffer)
    buffer.append("}\n")
    if let setter = signature.setter {
      if let parameterName = setter.parameterName {
        buffer.append("set(")
        buffer.append(escapeIdentifier(parameterName))
        buffer.append(")")
      } else {
        buffer.append("set")
      }
      buffer.append(" {\n")
      emitStatements(setter.body, into: &buffer)
      buffer.append("}\n")
    }
    buffer.append("}")
  }

  /// Extensions intentionally carry no attributes, matching the legacy model.
  private static func emitExtensionDeclaration<A: Sendable>(
    _ signature: ExtensionSignature<A>,
    into buffer: inout String
  ) {
    emit(modifiers: signature.accessLevel, into: &buffer)
    buffer.append("extension ")
    buffer.append(signature.typeName)
    emit(conformances: signature.conformances, into: &buffer)
    emit(whereRequirements: signature.whereRequirements, into: &buffer)
    buffer.append(" {\n")
    emit(members: signature.members, into: &buffer)
    buffer.append("}")
  }

  /// Text counterpart to the legacy renderer's `renderStruct`.
  private static func emitStructDeclaration<A: Sendable>(
    _ signature: StructSignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, into: &buffer)
    buffer.append("struct ")
    buffer.append(escapeIdentifier(signature.name))
    emit(genericParameters: signature.genericParameters, into: &buffer)
    emit(conformances: signature.conformances, into: &buffer)
    emit(whereRequirements: signature.whereRequirements, into: &buffer)
    buffer.append(" {\n")
    emit(members: signature.members, into: &buffer)
    buffer.append("}")
  }

  /// Enum cases are still emitted as raw source, matching the legacy path.
  private static func emitEnumDeclaration<A: Sendable>(
    _ signature: EnumSignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, into: &buffer)
    buffer.append("enum ")
    buffer.append(escapeIdentifier(signature.name))
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
  }

  /// Text counterpart to the legacy renderer's `renderTypeAlias`.
  private static func emitTypeAliasDeclaration(
    _ signature: TypeAliasSignature,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, into: &buffer)
    buffer.append("typealias ")
    buffer.append(escapeIdentifier(signature.name))
    emit(genericParameters: signature.genericParameters, into: &buffer)
    buffer.append(" = ")
    buffer.append(signature.existingType)
    emit(whereRequirements: signature.whereRequirements, into: &buffer)
  }

  /// Initializers have no async field, matching `InitializerSignature`.
  private static func emitInitializerDeclaration<A: Sendable>(
    _ signature: InitializerSignature<A>,
    into buffer: inout String
  ) {
    emit(attributes: signature.attributes, into: &buffer)
    emit(modifiers: signature.accessLevel, into: &buffer)
    buffer.append("init")
    if signature.isFailable {
      buffer.append("?")
    }
    emit(genericParameters: signature.genericParameters, into: &buffer)
    buffer.append("(")
    emit(parameters: signature.parameters, into: &buffer)
    buffer.append(")")
    if signature.canThrow {
      buffer.append(" throws")
    }
    emit(whereRequirements: signature.whereRequirements, into: &buffer)
    buffer.append(" {\n")
    emitStatements(signature.body, into: &buffer)
    buffer.append("}")
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
    if isStatic {
      buffer.append("static ")
    }
    if isMutating {
      buffer.append("mutating ")
    }
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
      buffer.append(escapeIdentifier(parameter.name))
      if let constraint = parameter.constraint {
        buffer.append(": ")
        buffer.append(constraint)
      }
      if index != genericParameters.count - 1 {
        buffer.append(", ")
      }
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
      if index != whereRequirements.count - 1 {
        buffer.append(", ")
      }
    }
  }

  /// Text-emission counterpart to `Renderer.renderInheritanceClause`:
  /// emits `: P1, P2, ...`, or nothing when `conformances` is empty.
  private static func emit(conformances: [String], into buffer: inout String) {
    guard !conformances.isEmpty else { return }
    buffer.append(": ")
    buffer.append(conformances.joined(separator: ", "))
  }

  /// Emits an unparenthesized function parameter list while preserving the
  /// source ordering of ownership specifiers, attributes, and type syntax.
  private static func emit<A: Sendable>(
    parameters: [ParameterSignature<A>],
    into buffer: inout String
  ) {
    for (index, parameter) in parameters.enumerated() {
      if let label = parameter.label {
        buffer.append(label)
        buffer.append(" ")
        buffer.append(escapeIdentifier(parameter.name))
      } else {
        buffer.append(escapeIdentifier(parameter.name))
      }
      buffer.append(": ")

      let hasTypeQualifiers =
        parameter.isInout || !parameter.specifiers.isEmpty || !parameter.attributes.isEmpty
        || !parameter.lateSpecifiers.isEmpty
      if hasTypeQualifiers {
        if parameter.isInout {
          buffer.append("inout ")
        }
        for specifier in parameter.specifiers {
          buffer.append(specifier)
          buffer.append(" ")
        }
        for attribute in parameter.attributes {
          buffer.append(Renderer.renderAttributeSource(attribute))
          buffer.append(" ")
        }
        for specifier in parameter.lateSpecifiers {
          buffer.append(specifier)
          buffer.append(" ")
        }
      }
      buffer.append(parameter.type)

      if let defaultValue = parameter.defaultValue {
        buffer.append(" = ")
        emit(defaultValue, into: &buffer)
      }
      if index != parameters.count - 1 {
        buffer.append(", ")
      }
    }
  }

  private static func emit(
    throwingEffect: ThrowingEffect,
    into buffer: inout String
  ) {
    switch throwingEffect {
    case .none:
      break
    case .throws(let errorType):
      buffer.append(" throws")
      if let errorType {
        buffer.append("(")
        buffer.append(errorType)
        buffer.append(")")
      }
    case .rethrows:
      buffer.append(" rethrows")
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
    buffer.append(escapeIdentifier(enumCase.name))
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
