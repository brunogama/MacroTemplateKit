// Examples/PeerMacros/AddAsyncMacro.swift
//
// Demonstrates how to implement the AddAsync peer macro using MacroTemplateKit
// instead of raw ExprSyntax string interpolation.
//
// The macro generates an async wrapper alongside a completion-handler function:
//
//   @AddAsync
//   func fetchData(id: Int, completion: @escaping (Result<Data, Error>) -> Void) { ... }
//
// Generates (Result return case):
//
//   func fetchData(id: Int) async throws -> Data {
//       try await withCheckedThrowingContinuation { continuation in
//           fetchData(id: id) { returnValue in
//               switch returnValue {
//               case .success(let value):
//                   continuation.resume(returning: value)
//               case .failure(let error):
//                   continuation.resume(throwing: error)
//               }
//           }
//       }
//   }
//
// Generates (plain optional/value return case):
//
//   func fetchData(id: Int) async -> String {
//       await withCheckedContinuation { continuation in
//           fetchData(id: id) { returnValue in
//               continuation.resume(returning: returnValue)
//           }
//       }
//   }

import SwiftSyntax
import SwiftSyntaxMacros
import MacroTemplateKit

// MARK: - Error Type

/// Typed errors for AddAsync macro expansion.
enum AddAsyncError: Error {
    case notAFunction
    case alreadyAsync
    case nonVoidReturnType
    case missingCompletionHandler
    case completionHandlerMustReturnVoid
}

// MARK: - Completion Handler Shape

/// Describes the shape of the completion-handler parameter.
private enum CompletionHandlerShape {
    /// Completion takes a `Result<Success, Error>` value.
    case resultType(successType: String)
    /// Completion takes a plain value (or nothing if `payloadType` is nil).
    case plainType(payloadType: String?)
}

// MARK: - Macro Implementation

/// Generates an async wrapper peer alongside a completion-handler function.
///
/// Attach `@AddAsync` to a `void`-returning function whose last parameter is a
/// completion handler block. The macro emits an `async` (and `throws` for Result)
/// overload that bridges to `withCheckedContinuation` / `withCheckedThrowingContinuation`.
public struct AddAsyncMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw AddAsyncError.notAFunction
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil else {
            throw AddAsyncError.alreadyAsync
        }

        let returnClauseType = funcDecl.signature.returnClause?
            .type.as(IdentifierTypeSyntax.self)?.name.text
        guard returnClauseType == nil || returnClauseType == "Void" else {
            throw AddAsyncError.nonVoidReturnType
        }

        guard let completionHandlerType = extractCompletionHandlerType(from: funcDecl) else {
            throw AddAsyncError.missingCompletionHandler
        }

        let handlerReturnName = completionHandlerType.returnClause.type
            .as(IdentifierTypeSyntax.self)?.name.text
        guard handlerReturnName == nil || handlerReturnName == "Void" else {
            throw AddAsyncError.completionHandlerMustReturnVoid
        }

        let handlerShape = resolveHandlerShape(from: completionHandlerType)
        let syncParameters = dropLastParameter(from: funcDecl)
        let accessLevel = extractAccessLevel(from: funcDecl)
        let functionName = funcDecl.name.text
        let callArguments = buildCallArguments(from: syncParameters)
        let asyncSignature = buildAsyncSignature(
            name: functionName,
            accessLevel: accessLevel,
            parameters: syncParameters,
            handlerShape: handlerShape
        )
        let body = buildAsyncBody(
            functionName: functionName,
            callArguments: callArguments,
            handlerShape: handlerShape
        )

        let peerFunction = Declaration<Void>.function(
            FunctionSignature(
                accessLevel: asyncSignature.accessLevel,
                name: asyncSignature.name,
                parameters: asyncSignature.parameters,
                isAsync: true,
                canThrow: asyncSignature.canThrow,
                returnType: asyncSignature.returnType,
                body: body
            )
        )

        return [Renderer.render(peerFunction)]
    }
}

// MARK: - Body Generation

/// Intermediate async signature description.
private struct AsyncSignatureDescription {
    let accessLevel: AccessLevel
    let name: String
    let parameters: [ParameterSignature]
    let canThrow: Bool
    let returnType: String?
}

private func buildAsyncSignature(
    name: String,
    accessLevel: AccessLevel,
    parameters: [ParameterSignature],
    handlerShape: CompletionHandlerShape
) -> AsyncSignatureDescription {
    switch handlerShape {
    case .resultType(let successType):
        return AsyncSignatureDescription(
            accessLevel: accessLevel,
            name: name,
            parameters: parameters,
            canThrow: true,
            returnType: successType
        )
    case .plainType(let payloadType):
        return AsyncSignatureDescription(
            accessLevel: accessLevel,
            name: name,
            parameters: parameters,
            canThrow: false,
            returnType: payloadType
        )
    }
}

private func buildAsyncBody(
    functionName: String,
    callArguments: [(label: String?, argName: String)],
    handlerShape: CompletionHandlerShape
) -> [Statement<Void>] {
    switch handlerShape {
    case .resultType(let successType):
        return buildResultBody(functionName: functionName, callArguments: callArguments, successType: successType)
    case .plainType(let payloadType):
        return buildPlainBody(functionName: functionName, callArguments: callArguments, hasPayload: payloadType != nil)
    }
}

// MARK: - Result<Success, Error> body

private func buildResultBody(
    functionName: String,
    callArguments: [(label: String?, argName: String)],
    successType: String
) -> [Statement<Void>] {
    // Build: continuation.resume(returning: value)
    let resumeReturning: Template<Void> = .methodCall(
        base: .variable("continuation"),
        method: "resume",
        arguments: [(label: "returning", value: .variable("value"))]
    )

    // Build: continuation.resume(throwing: error)
    let resumeThrowing: Template<Void> = .methodCall(
        base: .variable("continuation"),
        method: "resume",
        arguments: [(label: "throwing", value: .variable("error"))]
    )

    // Build: switch returnValue { case .success(let value): ...; case .failure(let error): ... }
    let switchStatement: Statement<Void> = .switchStatement(
        subject: .variable("returnValue"),
        cases: [
            SwitchCase(
                pattern: .expression(.variable(".success(let value)")),
                body: [.expression(resumeReturning)]
            ),
            SwitchCase(
                pattern: .expression(.variable(".failure(let error)")),
                body: [.expression(resumeThrowing)]
            ),
        ]
    )

    // Build: fetchData(id: id) { returnValue in switch returnValue { ... } }
    let syncCall: Template<Void> = buildSyncCall(
        functionName: functionName,
        callArguments: callArguments,
        closureParam: "returnValue",
        closureBody: [switchStatement]
    )

    // Build: try await withCheckedThrowingContinuation { continuation in ... }
    let continuationCall: Template<Void> = .tryAwait(
        .functionCall(
            function: "withCheckedThrowingContinuation",
            arguments: [
                (
                    label: nil,
                    value: .closure(
                        ClosureSignature(
                            parameters: [(name: "continuation", type: nil)],
                            returnType: nil,
                            body: [.expression(syncCall)]
                        )
                    )
                )
            ]
        )
    )

    return [.expression(continuationCall)]
}

// MARK: - Plain value body

private func buildPlainBody(
    functionName: String,
    callArguments: [(label: String?, argName: String)],
    hasPayload: Bool
) -> [Statement<Void>] {
    // Build: continuation.resume(returning: returnValue)  OR  continuation.resume(returning: ())
    let resumeArg: Template<Void> = hasPayload
        ? .variable("returnValue")
        : .functionCall(function: "()", arguments: [])

    let resumeReturning: Template<Void> = .methodCall(
        base: .variable("continuation"),
        method: "resume",
        arguments: [(label: "returning", value: resumeArg)]
    )

    let closureParams: [(name: String, type: String?)] = hasPayload
        ? [(name: "returnValue", type: nil)]
        : []

    // Build: fetchData(id: id) { returnValue in continuation.resume(returning: returnValue) }
    let syncCall: Template<Void> = buildSyncCall(
        functionName: functionName,
        callArguments: callArguments,
        closureParam: hasPayload ? "returnValue" : "",
        closureBody: [.expression(resumeReturning)],
        overrideParams: closureParams
    )

    // Build: await withCheckedContinuation { continuation in ... }
    let continuationCall: Template<Void> = .awaitExpression(
        .functionCall(
            function: "withCheckedContinuation",
            arguments: [
                (
                    label: nil,
                    value: .closure(
                        ClosureSignature(
                            parameters: [(name: "continuation", type: nil)],
                            returnType: nil,
                            body: [.expression(syncCall)]
                        )
                    )
                )
            ]
        )
    )

    return [.expression(continuationCall)]
}

// MARK: - Shared builder helpers

private func buildSyncCall(
    functionName: String,
    callArguments: [(label: String?, argName: String)],
    closureParam: String,
    closureBody: [Statement<Void>],
    overrideParams: [(name: String, type: String?)]? = nil
) -> Template<Void> {
    let resolvedParams: [(name: String, type: String?)] = overrideParams
        ?? (closureParam.isEmpty ? [] : [(name: closureParam, type: nil)])

    let handlerClosure: Template<Void> = .closure(
        ClosureSignature(
            parameters: resolvedParams,
            returnType: nil,
            body: closureBody
        )
    )

    var args = callArguments.map { info -> (label: String?, value: Template<Void>) in
        (label: info.label, value: .variable(info.argName))
    }
    args.append((label: nil, value: handlerClosure))

    return .functionCall(function: functionName, arguments: args)
}

// MARK: - Parameter Extraction Helpers

private func extractCompletionHandlerType(from funcDecl: FunctionDeclSyntax) -> FunctionTypeSyntax? {
    funcDecl.signature.parameterClause.parameters.last?
        .type.as(AttributedTypeSyntax.self)?
        .baseType.as(FunctionTypeSyntax.self)
}

private func resolveHandlerShape(from handlerType: FunctionTypeSyntax) -> CompletionHandlerShape {
    guard let firstParam = handlerType.parameters.first else {
        return .plainType(payloadType: nil)
    }
    let typeText = firstParam.type.description.trimmingCharacters(in: .whitespaces)
    guard typeText.hasPrefix("Result<") else {
        return .plainType(payloadType: typeText)
    }
    guard let identType = firstParam.type.as(IdentifierTypeSyntax.self),
          let firstArg = identType.genericArgumentClause?.arguments.first,
          case .type(let successType) = firstArg.argument
    else {
        return .plainType(payloadType: typeText)
    }
    return .resultType(successType: successType.description.trimmingCharacters(in: .whitespaces))
}

private func dropLastParameter(from funcDecl: FunctionDeclSyntax) -> [ParameterSignature] {
    let params = funcDecl.signature.parameterClause.parameters
    guard params.count > 1 else {
        return []
    }
    return params.dropLast().map { param in
        let labelText = param.firstName.text
        // secondName is present only when the caller wrote `label name: Type`.
        // When absent, firstName serves as both label and name — pass label: nil
        // so ParameterSignature renders `name: Type`, not `name name: Type`.
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

private func buildCallArguments(
    from parameters: [ParameterSignature]
) -> [(label: String?, argName: String)] {
    parameters.map { param in
        (label: param.label, argName: param.name)
    }
}

private func extractAccessLevel(from funcDecl: FunctionDeclSyntax) -> AccessLevel {
    let modifierNames = funcDecl.modifiers.map { $0.name.text }
    if modifierNames.contains("public") { return .public }
    if modifierNames.contains("fileprivate") { return .fileprivate }
    if modifierNames.contains("private") { return .private }
    return .internal
}

// MARK: - Before/After Comparison Notes
//
// BEFORE: raw string interpolation (from swift-syntax/Examples)
//
//   let switchBody: ExprSyntax = """
//     switch returnValue {
//     case .success(let value):
//       continuation.resume(returning: value)
//     case .failure(let error):
//       continuation.resume(throwing: error)
//     }
//   """
//
//   let newBody: ExprSyntax = """
//     \(raw: isResultReturn
//         ? "try await withCheckedThrowingContinuation { continuation in"
//         : "await withCheckedContinuation { continuation in")
//       \(raw: funcDecl.name)(\(raw: callArguments.joined(separator: ", "))) {
//         \(raw: returnType != nil ? "returnValue in" : "")
//         \(raw: isResultReturn ? switchBody : "continuation.resume(...)")
//       }
//     }
//   """
//
// AFTER: MacroTemplateKit (see buildResultBody / buildPlainBody above)
//
// Key advantages:
// - Type-checked: no runtime string parsing or interpolation errors
// - Composable: each piece is a named Template<Void> value, not an embedded raw string
// - Testable: individual sub-expressions can be rendered and inspected independently
// - No raw: prefix needed to inject computed strings into string literals
