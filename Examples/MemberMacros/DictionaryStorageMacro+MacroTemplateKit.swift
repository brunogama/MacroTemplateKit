// DictionaryStorageMacro+MacroTemplateKit.swift
//
// Demonstrates how to rewrite swift-syntax's DictionaryStorageMacro using
// MacroTemplateKit's typed template algebra instead of raw string interpolation.
//
// Original source:
//   swift-syntax/Examples/Sources/MacroExamples/Implementation/ComplexMacros/
//       DictionaryIndirectionMacro.swift
//
// The macro has two roles:
//
//   1. MemberMacro — injects a `var _storage: [String: Any] = [:]` backing store.
//   2. MemberAttributeMacro — attaches `@DictionaryStorageProperty` to every
//      stored property so an accessor macro can redirect get/set through _storage.
//
// Only the MemberMacro role is shown here because the accessor expansion is
// handled by `DictionaryStoragePropertyMacro` (an AccessorMacro, not a
// MemberMacro). This file focuses on the member-injection side.
//
// BEFORE: raw string interpolation
//
//   return ["\n  var _storage: [String: Any] = [:]"]
//
// AFTER: MacroTemplateKit
//
//   Declaration<Void>.property(...) → Renderer.render(_:) → DeclSyntax

import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - DictionaryStorageMacro — MacroTemplateKit edition

/// Injects a `_storage` dictionary backing property into the annotated type.
///
/// Pair with `@DictionaryStorageProperty` on individual stored properties so
/// their getters and setters route through `_storage`.
public struct DictionaryStorageMacroMTK {}

extension DictionaryStorageMacroMTK: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return [buildStorageProperty()]
  }

  // MARK: - Private Helpers

  /// Builds `var _storage: [String: Any] = [:]` using the MacroTemplateKit API.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   return ["\n  var _storage: [String: Any] = [:]"]
  ///
  /// AFTER: MacroTemplateKit
  ///
  ///   Declaration.property(PropertySignature(...)) → Renderer.render
  ///
  /// Key decisions:
  /// - `isLet: false`  — the dictionary must be mutable.
  /// - `initializer`   — `.dictionaryLiteral([])` renders as `[:]`.
  /// - `type`          — expressed as a plain `String` type annotation since
  ///                     `[String: Any]` is a valid Swift type string and the
  ///                     renderer passes it through `TypeSyntax(stringLiteral:)`.
  private static func buildStorageProperty() -> DeclSyntax {
    let storageProperty = Declaration<Void>.property(
      PropertySignature(
        name: "_storage",
        type: "[String: Any]",
        isLet: false,
        initializer: .dictionaryLiteral([])
      )
    )
    return Renderer.render(storageProperty)
  }
}

extension DictionaryStorageMacroMTK: MemberAttributeMacro {
  /// Attaches `@DictionaryStorageProperty` to every stored property.
  ///
  /// The attribute is constructed using SwiftSyntax AST directly (no string
  /// interpolation) because MacroTemplateKit models code generation templates,
  /// not attribute syntax.
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AttributeSyntax] {
    guard
      let property = member.as(VariableDeclSyntax.self),
      property.isStoredProperty
    else {
      return []
    }
    return [buildDictionaryStoragePropertyAttribute()]
  }

  /// Returns the `@DictionaryStorageProperty` attribute node.
  private static func buildDictionaryStoragePropertyAttribute() -> AttributeSyntax {
    AttributeSyntax(
      leadingTrivia: [.newlines(1), .spaces(2)],
      attributeName: IdentifierTypeSyntax(
        name: .identifier("DictionaryStorageProperty")
      )
    )
  }
}

// MARK: - DictionaryStoragePropertyMacro — MacroTemplateKit edition

/// Generates `get` and `set` accessors that delegate to `_storage`.
///
/// The AccessorMacro side uses MacroTemplateKit's `Statement` and `Template`
/// types to build both accessors in a type-safe manner.
///
/// Accessor macro expansion must return `[AccessorDeclSyntax]`, not `[DeclSyntax]`,
/// so we use `Renderer.render(_: Statement<A>)` → `CodeBlockItemSyntax` and
/// assemble the `AccessorDeclSyntax` nodes around rendered statement bodies.
public struct DictionaryStoragePropertyMacroMTK: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard
      let variableDecl = declaration.as(VariableDeclSyntax.self),
      let binding = variableDecl.bindings.first,
      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      binding.accessorBlock == nil,
      let type = binding.typeAnnotation?.type
    else {
      return []
    }

    guard identifier.text != "_storage" else {
      return []
    }

    guard let defaultValue = binding.initializer?.value else {
      throw DictionaryStorageError.missingInitializer
    }

    let getter = buildGetter(
      propertyName: identifier.text,
      type: type,
      defaultValue: defaultValue
    )
    let setter = buildSetter(propertyName: identifier.text)
    return [getter, setter]
  }

  // MARK: - Accessor Builders

  /// Builds the `get` accessor using MacroTemplateKit statements.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   """
  ///   get {
  ///     _storage[\(literal: identifier.text), default: \(defaultValue)] as! \(type)
  ///   }
  ///   """
  ///
  /// AFTER: MacroTemplateKit
  ///
  /// The subscript with default is modelled as a `methodCall` whose
  /// base is the subscript expression, and the force-cast to `type` is
  /// embedded as a type-cast expression node.
  ///
  /// LIMITATION: `as! Type` force-cast is not a first-class Template case.
  /// The getter body expression is therefore assembled with raw SwiftSyntax
  /// AST nodes for the as! cast, while MacroTemplateKit handles the subscript
  /// and return scaffold.
  private static func buildGetter(
    propertyName: String,
    type: TypeSyntax,
    defaultValue: ExprSyntax
  ) -> AccessorDeclSyntax {
    // Build the subscript-with-default expression using raw SwiftSyntax
    // because Template.subscriptAccess only models single-index subscripts.
    // `_storage["propertyName"]` would be expressible via Template, but the
    // extra `default:` labeled argument is not, so we use raw AST throughout.
    let defaultLabeledArg = LabeledExprSyntax(
      label: .identifier("default"),
      colon: .colonToken(trailingTrivia: .space),
      expression: defaultValue
    )
    let subscriptWithDefault = SubscriptCallExprSyntax(
      calledExpression: Renderer.render(
        Template<Void>.variable("_storage")
      ),
      arguments: LabeledExprListSyntax([
        LabeledExprSyntax(expression: ExprSyntax(StringLiteralExprSyntax(content: propertyName))),
        defaultLabeledArg,
      ])
    )

    // Force-cast `as! Type` — not in the Template algebra; assembled directly.
    let forceCastExpr = AsExprSyntax(
      expression: ExprSyntax(subscriptWithDefault),
      questionOrExclamationMark: .exclamationMarkToken(),
      type: type
    )

    let returnStatement = ReturnStmtSyntax(expression: ExprSyntax(forceCastExpr))
    let getterBody = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStatement)))
      ])
    )

    return AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: getterBody
    )
  }

  /// Builds the `set` accessor using MacroTemplateKit statements.
  ///
  /// BEFORE: raw string interpolation
  ///
  ///   """
  ///   set {
  ///     _storage[\(literal: identifier.text)] = newValue
  ///   }
  ///   """
  ///
  /// AFTER: MacroTemplateKit
  ///
  ///   Statement.assignmentStatement(lhs: subscriptExpr, rhs: newValue)
  private static func buildSetter(propertyName: String) -> AccessorDeclSyntax {
    // `_storage["propertyName"] = newValue`
    let lhs = Template<Void>.subscriptAccess(
      base: .variable("_storage"),
      index: .literal(.string(propertyName))
    )
    let rhs = Template<Void>.variable("newValue")

    let assignmentStatement = Statement<Void>.assignmentStatement(lhs: lhs, rhs: rhs)
    let setterBody = CodeBlockSyntax(
      statements: CodeBlockItemListSyntax([Renderer.render(assignmentStatement)])
    )

    return AccessorDeclSyntax(
      accessorSpecifier: .keyword(.set),
      body: setterBody
    )
  }
}

// MARK: - Error

/// Errors emitted during DictionaryStorageProperty macro expansion.
enum DictionaryStorageError: Error, Sendable {
  /// A stored property annotated with @DictionaryStorageProperty has no initializer.
  case missingInitializer
}

// MARK: - VariableDeclSyntax Helper

extension VariableDeclSyntax {
  /// Returns true when the variable is a stored property (no accessor block).
  fileprivate var isStoredProperty: Bool {
    guard let binding = bindings.first else {
      return false
    }
    return binding.accessorBlock == nil
  }
}
