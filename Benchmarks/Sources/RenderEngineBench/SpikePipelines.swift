import SwiftSyntax
import SwiftSyntaxBuilder

// SPIKE pipelines: three candidate Renderer optimization strategies from the
// 2026-07-13 brainstorm, expressed as generator pipelines so the same workload
// and equivalence gate compare them against the current `mtk` baseline.
// Bar to beat: ≥25% faster p50 than mtk at every size, no memory regression.

// MARK: - Approach A: parse-backed rendering

/// Emit source text from the (already string-shaped) template inputs, then
/// invoke the parser once per fragment. Models a Renderer that serializes the
/// template algebra to text and parses, instead of per-node initializers.
/// Node inputs are serialized with `trimmedDescription`, matching what a
/// renderer would pay to accept extracted syntax.
struct ParseBackedMTKPipeline: ASTGeneratorPipeline {
    static let name = "mtk-parse"
    static let summary = "Spike A: serialize template to source text, one parse per fragment"

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        var accessors: [AccessorDeclSyntax] = []
        accessors.reserveCapacity(properties.count * 2)
        for property in properties {
            let type = property.type.trimmedDescription
            let defaultValue = property.defaultValue.trimmedDescription
            let getter = """
                get {
                  _storage["\(property.name)", default: \(defaultValue)] as! \(type)
                }
                """
            let setter = """
                set {
                  _storage["\(property.name)"] = newValue
                }
                """
            accessors.append(AccessorDeclSyntax("\(raw: getter)"))
            accessors.append(AccessorDeclSyntax("\(raw: setter)"))
        }
        return ExpansionOutput(
            storageMember: DeclSyntax("var _storage: [String: Any] = [:]"),
            accessors: accessors
        )
    }
}

// MARK: - Approach B: interned structural construction

/// Structural per-node construction, but every expansion-invariant node is
/// built once and reused: leaf tokens, the `_storage`/`newValue` references,
/// and the entire storage member.
///
/// Originally written as a candidate *implementation* strategy for the
/// renderer and rejected for being under the adoption bar. That was the wrong
/// question to stop at: the same margin that made it a poor thing to build
/// makes it the right thing to be measured against. A competent macro author
/// hoists loop invariants, so this — not `structural` — is the honest
/// hand-rolled baseline. It beats `structural` by 15–18% on min.
struct InternedStructuralPipeline: ASTGeneratorPipeline {
    static let name = "structural-interned"
    static let summary = "Hand-rolled SwiftSyntax with invariant nodes hoisted out of the loop"

    private enum Interned {
        static let storageMember = DeclSyntax(storageVariableDecl())
        static let storageRef = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("_storage")))
        static let newValueRef = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("newValue")))
        static let assignment = ExprSyntax(AssignmentExprSyntax())
        static let defaultLabel = TokenSyntax.identifier("default")
        static let comma = TokenSyntax.commaToken()
        static let colon = TokenSyntax.colonToken()
        static let exclamation = TokenSyntax.exclamationMarkToken()
        static let getKeyword = TokenSyntax.keyword(.get)
        static let setKeyword = TokenSyntax.keyword(.set)
    }

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        ExpansionOutput(
            storageMember: Interned.storageMember,
            accessors: properties.flatMap { [Self.getter(for: $0), Self.setter(for: $0)] }
        )
    }

    private static func getter(for property: StoredProperty) -> AccessorDeclSyntax {
        let subscriptWithDefault = SubscriptCallExprSyntax(
            calledExpression: Interned.storageRef,
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: ExprSyntax(StringLiteralExprSyntax(content: property.name)),
                    trailingComma: Interned.comma
                ),
                LabeledExprSyntax(
                    label: Interned.defaultLabel,
                    colon: Interned.colon,
                    expression: property.defaultValue
                ),
            ])
        )
        let forceCast = AsExprSyntax(
            expression: ExprSyntax(subscriptWithDefault),
            questionOrExclamationMark: Interned.exclamation,
            type: property.type
        )
        return AccessorDeclSyntax(
            accessorSpecifier: Interned.getKeyword,
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(forceCast)))
                ])
            )
        )
    }

    private static func setter(for property: StoredProperty) -> AccessorDeclSyntax {
        let storageSubscript = SubscriptCallExprSyntax(
            calledExpression: Interned.storageRef,
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: ExprSyntax(StringLiteralExprSyntax(content: property.name))
                )
            ])
        )
        let assignment = SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(storageSubscript),
                Interned.assignment,
                Interned.newValueRef,
            ])
        )
        return AccessorDeclSyntax(
            accessorSpecifier: Interned.setKeyword,
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(assignment)))
                ])
            )
        )
    }
}

// MARK: - Approach C: memoized rendering (warm-cache upper bound)

/// Process-lifetime memoization of rendered fragments, keyed per property.
/// SE-0382's purity assumption makes this sound; the plugin process persists
/// across a module's expansions, so repeats can hit the cache.
///
/// SPIKE CAVEAT: the benchmark re-expands the SAME struct every iteration, so
/// after warmup the hit rate is 100%. This measures the best case, not a
/// typical one — real hit rates depend on how repetitive user code is.
struct MemoizedMTKPipeline: ASTGeneratorPipeline {
    static let name = "mtk-memo"
    static let summary = "Spike C: memoized fragments, warm-cache upper bound (100% hit rate)"

    private static var cache: [String: (getter: AccessorDeclSyntax, setter: AccessorDeclSyntax)] = [:]
    private static let storageMember = DeclSyntax(storageVariableDecl())

    func expand(properties: [StoredProperty]) -> ExpansionOutput {
        var accessors: [AccessorDeclSyntax] = []
        accessors.reserveCapacity(properties.count * 2)
        for property in properties {
            let key = property.name
            let pair: (getter: AccessorDeclSyntax, setter: AccessorDeclSyntax)
            if let cached = Self.cache[key] {
                pair = cached
            } else {
                pair = (
                    StructuralPipeline.getter(for: property),
                    StructuralPipeline.setter(for: property)
                )
                Self.cache[key] = pair
            }
            accessors.append(pair.getter)
            accessors.append(pair.setter)
        }
        return ExpansionOutput(storageMember: Self.storageMember, accessors: accessors)
    }
}
