// Examples/PeerMacros/PeerValueWithSuffixNameMacro.swift
//
// Demonstrates how to implement the PeerValueWithSuffixName peer macro using
// MacroTemplateKit instead of raw DeclSyntax string interpolation.
//
// The macro generates a computed Int property whose name is the original
// declaration's name with "_peer" appended:
//
//   @PeerValueWithSuffixName
//   var score: Double { 3.14 }
//
// Generates:
//
//   var score_peer: Int { 1 }

import SwiftSyntax
import SwiftSyntaxMacros
import MacroTemplateKit

// MARK: - Macro Implementation

/// Creates a peer computed `Int` property with the suffix `_peer` appended to the original name.
///
/// Attach `@PeerValueWithSuffixName` to any named declaration. The macro always emits
/// a `var <name>_peer: Int { 1 }` computed property regardless of the original declaration kind.
///
/// This example shows how `Declaration.computedProperty` replaces the one-liner
/// raw string interpolation pattern `"var \(raw: name)_peer: Int { 1 }"`.
public enum PeerValueWithSuffixNameMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let namedDecl = declaration.asProtocol(NamedDeclSyntax.self) else {
            return []
        }

        let peerName = namedDecl.name.text + "_peer"

        // BEFORE: raw string interpolation
        //
        // return ["var \(raw: namedDecl.name.text)_peer: Int { 1 }"]
        //
        // The approach above:
        // - Uses a raw string literal — easy to mistype the type name or keyword
        // - Not composable: you cannot reuse the return expression independently
        // - No type safety on the generated identifier or the literal value

        // AFTER: MacroTemplateKit
        //
        // Build: var score_peer: Int { get { 1 } }
        let peerProperty = Declaration<Void>.computedProperty(
            ComputedPropertySignature(
                accessLevel: .internal,
                name: peerName,
                type: "Int",
                isStatic: false,
                getter: [
                    .returnStatement(.literal(1))
                ]
            )
        )

        return [Renderer.render(peerProperty)]
    }
}

// MARK: - Extended Variant: Public Peer with Custom Suffix
//
// The pattern generalises naturally. Below is a variant that propagates the
// original access level and accepts a configurable suffix — impossible to do
// cleanly with a raw string literal without manual string construction.

/// Creates a peer computed `Int` property with a caller-supplied suffix.
///
/// Unlike `PeerValueWithSuffixNameMacro`, this variant reads the access level
/// from the original declaration and accepts the suffix as a macro argument.
public enum PeerValueWithCustomSuffixMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let namedDecl = declaration.asProtocol(NamedDeclSyntax.self) else {
            return []
        }

        let suffix = extractSuffix(from: node) ?? "_peer"
        let peerName = namedDecl.name.text + suffix
        let accessLevel = extractAccessLevel(from: declaration)

        // BEFORE: raw string + string interpolation to build the access modifier
        //
        // let accessText = accessLevel == .public ? "public " : ""
        // return ["\(raw: accessText)var \(raw: peerName): Int { 1 }"]

        // AFTER: MacroTemplateKit — access level is a typed enum value, not a string
        let peerProperty = Declaration<Void>.computedProperty(
            ComputedPropertySignature(
                accessLevel: accessLevel,
                name: peerName,
                type: "Int",
                isStatic: false,
                getter: [
                    .returnStatement(.literal(1))
                ]
            )
        )

        return [Renderer.render(peerProperty)]
    }
}

// MARK: - Private Helpers

private func extractSuffix(from node: AttributeSyntax) -> String? {
    guard
        let argumentList = node.arguments?.as(LabeledExprListSyntax.self),
        let firstArgument = argumentList.first,
        let stringLiteral = firstArgument.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
        return nil
    }
    return segment.content.text
}

private func extractAccessLevel(from declaration: some DeclSyntaxProtocol) -> AccessLevel {
    guard let withModifiers = declaration.asProtocol(WithModifiersSyntax.self) else {
        return .internal
    }
    let modifierNames = withModifiers.modifiers.map { $0.name.text }
    if modifierNames.contains("public") { return .public }
    if modifierNames.contains("fileprivate") { return .fileprivate }
    if modifierNames.contains("private") { return .private }
    return .internal
}
