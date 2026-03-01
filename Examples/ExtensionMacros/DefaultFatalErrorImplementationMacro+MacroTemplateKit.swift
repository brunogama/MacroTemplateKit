// MARK: - DefaultFatalErrorImplementationMacro using MacroTemplateKit
//
// Original swift-syntax example from:
//   swiftlang/swift-syntax
//   Examples/Sources/MacroExamples/Implementation/Extension/DefaultFatalErrorImplementationMacro.swift
//
// This @attached(extension) macro attaches to a protocol declaration and generates
// a single extension that provides a default `fatalError(...)` body for every method
// declared in the protocol.  It is useful for mocking / stub generation in tests, or
// for documenting "this method must be overridden" without making the protocol opt-out.

import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - BEFORE: raw string interpolation

// public enum DefaultFatalErrorImplementationMacro: ExtensionMacro {
//
//   private static let messageID = MessageID(domain: "MacroExamples", id: "ProtocolDefaultImplementation")
//
//   public static func expansion(
//     of node: AttributeSyntax,
//     attachedTo declaration: some DeclGroupSyntax,
//     providingExtensionsOf type: some TypeSyntaxProtocol,
//     conformingTo protocols: [TypeSyntax],
//     in context: some MacroExpansionContext
//   ) throws -> [ExtensionDeclSyntax] {
//     guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
//       throw SimpleDiagnosticMessage(
//         message: "Macro `defaultFatalErrorImplementation` can only be applied to a protocol",
//         diagnosticID: messageID,
//         severity: .error
//       )
//     }
//
//     let methods = protocolDecl.memberBlock.members
//       .map(\.decl)
//       .compactMap { declaration -> FunctionDeclSyntax? in
//         guard var function = declaration.as(FunctionDeclSyntax.self) else { return nil }
//         // Raw string literal inside a closure — no structural guarantees.
//         function.body = CodeBlockSyntax {
//           ExprSyntax(#"fatalError("whoops 😅")"#)
//         }
//         return function
//       }
//
//     if methods.isEmpty { return [] }
//
//     let extensionDecl = ExtensionDeclSyntax(extendedType: type) {
//       for method in methods {
//         MemberBlockItemSyntax(decl: method)
//       }
//     }
//     return [extensionDecl]
//   }
// }

// MARK: - AFTER: MacroTemplateKit

/// Provides default stub implementations for every method in a protocol.
///
/// When applied to a protocol, the macro generates an extension that contains a
/// copy of each method with a body built from MacroTemplateKit's typed template
/// algebra.  The generated body calls `fatalError` with a descriptive message
/// constructed from the method name so every stub is individually identifiable.
///
/// MacroTemplateKit approach:
/// - `FunctionSignature` carries the method's structural metadata (name, parameters,
///   async/throws qualifiers, return type) extracted from the original AST.
/// - The body is expressed as `[Statement<Never>]` — a single `.expression` wrapping
///   a `.functionCall` to `fatalError`.
/// - `ExtensionSignature` assembles the full extension with the rendered members.
/// - `Renderer.renderExtensionDecl(_:)` produces the final `ExtensionDeclSyntax`.
///
/// Template structure (per method):
/// ```
/// Declaration<Never>.function(
///   FunctionSignature(
///     name:      "<methodName>",
///     parameters: [...],
///     isAsync:   <bool>,
///     canThrow:  <bool>,
///     returnType: <string?>,
///     body: [
///       .expression(.functionCall("fatalError", [(nil, .literal("<methodName> is not implemented"))]))
///     ]
///   )
/// )
/// ```
public enum DefaultFatalErrorImplementationMacro: ExtensionMacro {

  // MARK: - Diagnostics

  private static let messageID = MessageID(
    domain: "MacroTemplateKit.Examples",
    id: "DefaultFatalErrorImplementation"
  )

  // MARK: - ExpansionMacro

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      throw SimpleDiagnosticMessage(
        message: "Macro `defaultFatalErrorImplementation` can only be applied to a protocol",
        diagnosticID: messageID,
        severity: .error
      )
    }

    let methodDeclarations = extractMethodDeclarations(from: protocolDecl)
    guard !methodDeclarations.isEmpty else {
      return []
    }

    let typeName = type.trimmed.description
    let extensionSignature = ExtensionSignature<Never>(
      typeName: typeName,
      conformances: [],
      whereRequirements: [],
      members: methodDeclarations
    )

    return [Renderer.renderExtensionDecl(extensionSignature)]
  }

  // MARK: - Private Helpers

  /// Extracts all function declarations from a protocol and converts them to
  /// `Declaration<Never>` templates with fatalError stub bodies.
  private static func extractMethodDeclarations(
    from protocolDecl: ProtocolDeclSyntax
  ) -> [Declaration<Never>] {
    protocolDecl.memberBlock.members
      .map(\.decl)
      .compactMap { decl -> Declaration<Never>? in
        guard let functionDecl = decl.as(FunctionDeclSyntax.self) else {
          return nil
        }
        return makeStubDeclaration(from: functionDecl)
      }
  }

  /// Converts a protocol `FunctionDeclSyntax` into a `Declaration<Never>` with a
  /// `fatalError` stub body.
  ///
  /// The stub message includes the method name so the crash site is identifiable
  /// without a stack trace.
  private static func makeStubDeclaration(
    from functionDecl: FunctionDeclSyntax
  ) -> Declaration<Never> {
    let methodName = functionDecl.name.text
    let parameters = extractParameters(from: functionDecl)
    let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
    let canThrow = functionDecl.signature.effectSpecifiers?.throwsClause != nil
    let returnType = functionDecl.signature.returnClause?.type.trimmedDescription

    // Build a fatalError call with a descriptive message string.
    // Using .literal(.string(...)) ensures the string is properly quoted and
    // escaped in the rendered output — no manual escaping needed.
    let stubBody: [Statement<Never>] = [
      .expression(
        .functionCall(
          function: "fatalError",
          arguments: [
            (label: nil, value: .literal(.string("\(methodName) is not implemented")))
          ]
        )
      )
    ]

    let signature = FunctionSignature<Never>(
      accessLevel: .internal,
      isStatic: false,
      isMutating: false,
      name: methodName,
      parameters: parameters,
      isAsync: isAsync,
      canThrow: canThrow,
      returnType: returnType,
      body: stubBody
    )

    return .function(signature)
  }

  /// Converts SwiftSyntax `FunctionParameterListSyntax` to `[ParameterSignature]`.
  ///
  /// In SwiftSyntax, an unlabelled parameter (`_ name: Type`) has
  /// `firstName.tokenKind == .keyword(.wildcard)`.  A label-and-name pair (`label name: Type`)
  /// has `firstName` as the external label and `secondName` as the internal name.
  private static func extractParameters(
    from functionDecl: FunctionDeclSyntax
  ) -> [ParameterSignature] {
    functionDecl.signature.parameterClause.parameters.map { param in
      let externalLabel: String?
      switch param.firstName.tokenKind {
      case .keyword(.wildcard):
        // Explicit `_` means no external label.
        externalLabel = "_"
      default:
        externalLabel = param.firstName.text
      }
      let internalName = (param.secondName ?? param.firstName).text
      return ParameterSignature(
        label: externalLabel,
        name: internalName,
        type: param.type.trimmedDescription,
        isInout: false,
        defaultValue: nil
      )
    }
  }
}
