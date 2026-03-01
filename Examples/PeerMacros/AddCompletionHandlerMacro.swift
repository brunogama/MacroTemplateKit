// Examples/PeerMacros/AddCompletionHandlerMacro.swift
//
// Demonstrates how to implement the AddCompletionHandler peer macro using
// MacroTemplateKit instead of raw ExprSyntax string interpolation.
//
// The macro generates a completion-handler variant alongside an async function:
//
//   @AddCompletionHandler
//   func fetchUser(id: String) async -> User { ... }
//
// Generates:
//
//   func fetchUser(id: String, completionHandler: @escaping (User) -> Void) {
//       Task {
//           completionHandler(await fetchUser(id: id))
//       }
//   }

import SwiftSyntax
import SwiftSyntaxMacros
import MacroTemplateKit

// MARK: - Error Type

/// Typed errors for AddCompletionHandler macro expansion.
enum AddCompletionHandlerError: Error {
    case notAFunction
    case missingAsyncKeyword
}

// MARK: - Macro Implementation

/// Generates a completion-handler overload alongside an async function.
///
/// Attach `@AddCompletionHandler` to any `async` function. The macro emits
/// a synchronous peer whose last parameter is `completionHandler: @escaping (ReturnType) -> Void`.
public struct AddCompletionHandlerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw AddCompletionHandlerError.notAFunction
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            throw AddCompletionHandlerError.missingAsyncKeyword
        }

        let originalParameters = buildOriginalParameters(from: funcDecl)
        let returnTypeName = extractReturnTypeName(from: funcDecl)
        let completionHandlerParameter = buildCompletionHandlerParameter(returnTypeName: returnTypeName)
        let allParameters = originalParameters + [completionHandlerParameter]
        let callArguments = buildCallArguments(from: funcDecl)
        let functionName = funcDecl.name.text
        let accessLevel = extractAccessLevel(from: funcDecl)

        // BEFORE: raw string interpolation
        //
        // let callExpr: ExprSyntax = "\(funcDecl.name)(\(raw: callArguments.joined(separator: ", ")))"
        // let body: ExprSyntax = """
        //   Task {
        //     completionHandler(await \(callExpr))
        //   }
        // """

        // AFTER: MacroTemplateKit
        //
        // Build: await fetchUser(id: id)
        let awaitedCall: Template<Void> = .awaitExpression(
            .functionCall(
                function: functionName,
                arguments: callArguments.map { (label: $0.label, value: .variable($0.argName, payload: ())) }
            )
        )

        // Build: completionHandler(await fetchUser(id: id))
        let completionCall: Template<Void> = .functionCall(
            function: "completionHandler",
            arguments: [(label: nil, value: awaitedCall)]
        )

        // Build Task { completionHandler(await fetchUser(id: id)) }
        let taskBody: Template<Void> = .functionCall(
            function: "Task",
            arguments: [
                (
                    label: nil,
                    value: .closure(
                        ClosureSignature(
                            parameters: [],
                            returnType: nil,
                            body: [.expression(completionCall)]
                        )
                    )
                )
            ]
        )

        let peerFunction = Declaration<Void>.function(
            FunctionSignature(
                accessLevel: accessLevel,
                name: functionName,
                parameters: allParameters,
                isAsync: false,
                canThrow: false,
                returnType: nil,
                body: [.expression(taskBody)]
            )
        )

        return [Renderer.render(peerFunction)]
    }
}

// MARK: - Private Helpers

/// Carries both the label (for the call site) and the argument name (internal).
private struct ParameterCallInfo {
    let label: String?
    let argName: String
}

private func buildOriginalParameters(from funcDecl: FunctionDeclSyntax) -> [ParameterSignature] {
    funcDecl.signature.parameterClause.parameters.map { param in
        let labelText = param.firstName.text
        // secondName is present only when the caller wrote `label name: Type`.
        // When absent, firstName serves as both label and name — pass label: nil
        // so ParameterSignature renders `name: Type` (one token), not `name name: Type`.
        let hasSeparateInternalName = param.secondName != nil
        let argName = (param.secondName ?? param.firstName).text
        let label: String? = (labelText == "_" || !hasSeparateInternalName) ? nil : labelText
        return ParameterSignature(
            label: label,
            name: argName,
            type: param.type.description.trimmingCharacters(in: .whitespaces)
        )
    }
}

private func buildCallArguments(from funcDecl: FunctionDeclSyntax) -> [ParameterCallInfo] {
    funcDecl.signature.parameterClause.parameters.map { param in
        let labelText = param.firstName.text
        let argName = (param.secondName ?? param.firstName).text
        // At the call site, the label is always the firstName (unless it is "_").
        // Use firstName regardless of whether secondName exists.
        let callLabel: String? = labelText == "_" ? nil : labelText
        return ParameterCallInfo(label: callLabel, argName: argName)
    }
}

private func extractReturnTypeName(from funcDecl: FunctionDeclSyntax) -> String {
    guard let returnClause = funcDecl.signature.returnClause else {
        return "Void"
    }
    let typeText = returnClause.type.description.trimmingCharacters(in: .whitespaces)
    return typeText.isEmpty ? "Void" : typeText
}

private func buildCompletionHandlerParameter(returnTypeName: String) -> ParameterSignature {
    let handlerType = returnTypeName == "Void"
        ? "@escaping () -> Void"
        : "@escaping (\(returnTypeName)) -> Void"
    // label: nil means firstName == name, rendering as:  completionHandler: @escaping (T) -> Void
    // label: "completionHandler" with name: "completionHandler" would render firstName secondName:,
    // i.e. `completionHandler completionHandler:` — which is wrong. Use nil label when they match.
    return ParameterSignature(
        label: nil,
        name: "completionHandler",
        type: handlerType
    )
}

private func extractAccessLevel(from funcDecl: FunctionDeclSyntax) -> AccessLevel {
    let modifierNames = funcDecl.modifiers.map { $0.name.text }
    if modifierNames.contains("public") { return .public }
    if modifierNames.contains("fileprivate") { return .fileprivate }
    if modifierNames.contains("private") { return .private }
    return .internal
}
