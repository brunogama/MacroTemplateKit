#!/usr/bin/env bash
# Scripts/generate_llms_txt.sh
#
# Regenerates LLMS.txt from the template embedded in this script plus key
# repository metadata extracted from Package.swift and README.md.
#
# Usage:
#   bash Scripts/generate_llms_txt.sh           # writes LLMS.txt to repo root
#   bash Scripts/generate_llms_txt.sh --check   # exits non-zero if LLMS.txt is stale

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$REPO_ROOT/LLMS.txt"
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

# ---------------------------------------------------------------------------
# Read current version from README.md (from: "x.y.z" pattern), then
# CHANGELOG.md, then fall back to a default.
# ---------------------------------------------------------------------------
VERSION=$(grep -m1 -oE 'from: "[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/README.md" 2>/dev/null \
          | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
if [[ -z "$VERSION" ]]; then
    VERSION=$(grep -m1 -oE '\[[0-9]+\.[0-9]+\.[0-9]+\]' "$REPO_ROOT/CHANGELOG.md" 2>/dev/null \
              | tr -d '[]' || echo "0.0.1")
fi

cat > "$TMPFILE" << LLMS_EOF
# MacroTemplateKit

> A type-safe, functional templating engine for Swift macro code generation.

MacroTemplateKit provides a parametric algebraic data type (ADT) that separates template structure from metadata, enabling compile-time safety, composability, and mathematical guarantees through functor laws.

## Repository

- **URL**: https://github.com/brunogama/MacroTemplateKit
- **License**: MIT
- **Swift**: 6.0+
- **Platforms**: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+

## Installation

\`\`\`swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", from: "${VERSION}")
]
\`\`\`

## Core Types

- \`Template<A>\` — Expression-level template (functor). Represents Swift expressions.
- \`Statement<A>\` — Statement-level template (functor). Represents Swift statements.
- \`Declaration<A>\` — Declaration-level template (functor). Represents Swift declarations.
- \`LiteralValue\` — Sum type for primitive literals (integer, float, string, boolean, nil).
- \`Renderer\` — Pure natural-transformation functions from templates to SwiftSyntax nodes.

## Signature Types

- \`FunctionSignature<A>\` — Components of a function declaration.
- \`ParameterSignature\` — A single function parameter (external label, internal name, type).
- \`PropertySignature<A>\` — Stored property components.
- \`ComputedPropertySignature<A>\` — Computed property with get/set accessors.
- \`SetterSignature<A>\` — Property setter definition.
- \`ExtensionSignature<A>\` — Extension declaration components.
- \`StructSignature<A>\` — Struct declaration components.
- \`InitializerSignature<A>\` — Initializer declaration components.
- \`AccessLevel\` — Swift access-control modifiers (public, internal, fileprivate, private).

## Result Builder

- \`TemplateBuilder<A>\` — \`@resultBuilder\` DSL for declarative template construction.

## Key Concepts

### Three-Layer AST

\`\`\`
Declaration<A>  ──► DeclSyntax
Statement<A>    ──► CodeBlockItemSyntax
Template<A>     ──► ExprSyntax
\`\`\`

### Functor Laws

All three types implement \`map\` and satisfy:
- **Identity**: \`t.map { \$0 } == t\`
- **Composition**: \`t.map(f).map(g) == t.map { g(f(\$0)) }\`

### Pure Rendering

\`Renderer\` provides stateless, side-effect-free functions:
\`\`\`swift
let expr: ExprSyntax           = Renderer.render(template)
let stmt: CodeBlockItemSyntax  = Renderer.render(statement)
let decl: DeclSyntax           = Renderer.render(declaration)
\`\`\`

## Quick Example

\`\`\`swift
import MacroTemplateKit

// Build: public func loadUser(with id: String) async throws -> User
let fn: Declaration<Void> = .function(FunctionSignature(
    accessLevel: .public,
    name: "loadUser",
    parameters: [ParameterSignature(label: "with", name: "id", type: "String")],
    isAsync: true,
    canThrow: true,
    returnType: "User",
    body: [
        .letBinding(name: "data", type: nil,
                    initializer: .methodCall(base: .variable("api", payload: ()),
                                             method: "fetch",
                                             arguments: [(label: "id", value: .variable("id", payload: ()))])),
        .returnStatement(.functionCall(
            function: "User",
            arguments: [(label: "from", value: .variable("data", payload: ()))]
        ))
    ]
))

let syntax: DeclSyntax = Renderer.render(fn)
\`\`\`

## Documentation

- DocC docs: https://brunogama.github.io/MacroTemplateKit/documentation/macrotemplatekit/
- Swift Package Index: https://swiftpackageindex.com/brunogama/MacroTemplateKit
LLMS_EOF

if [[ "${1:-}" == "--check" ]]; then
    if diff -q "$OUTPUT" "$TMPFILE" > /dev/null 2>&1; then
        echo "✅ LLMS.txt is up to date."
        exit 0
    else
        echo "❌ LLMS.txt is out of date. Run 'bash Scripts/generate_llms_txt.sh' to regenerate."
        diff "$OUTPUT" "$TMPFILE" || true
        exit 1
    fi
fi

cp "$TMPFILE" "$OUTPUT"
echo "✅ LLMS.txt written to $OUTPUT"
