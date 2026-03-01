# Peer Macro Examples

This directory contains MacroTemplateKit implementations of the three canonical peer
macro examples from the swift-syntax repository
(`Examples/Sources/MacroExamples/Implementation/Peer/`).

Each file shows the original raw-string-interpolation approach (commented out, labelled
`BEFORE`) alongside the MacroTemplateKit approach (active code, labelled `AFTER`).

---

## AddCompletionHandlerMacro

**File:** `AddCompletionHandlerMacro.swift`

Generates a completion-handler overload alongside an `async` function.

```swift
@AddCompletionHandler
func fetchUser(id: String) async -> User { ... }

// Generates:
func fetchUser(id: String, completionHandler: @escaping (User) -> Void) {
    Task {
        completionHandler(await fetchUser(id: id))
    }
}
```

**Key MacroTemplateKit patterns used:**

| Concept | API |
|---|---|
| Async call site | `Template.awaitExpression(_:)` |
| Function call | `Template.functionCall(function:arguments:)` |
| Trailing closure | `Template.closure(ClosureSignature(...))` |
| Full function declaration | `Declaration.function(FunctionSignature(...))` |
| Emit DeclSyntax | `Renderer.render(_: Declaration<Void>)` |

---

## AddAsyncMacro

**File:** `AddAsyncMacro.swift`

Generates an `async` wrapper alongside a completion-handler function. Handles both
plain-value completions and `Result<Success, Error>` completions (producing a
`throws` overload in the latter case).

```swift
// Plain value:
@AddAsync
func loadName(id: Int, completion: @escaping (String) -> Void) { ... }

// Generates:
func loadName(id: Int) async -> String {
    await withCheckedContinuation { continuation in
        loadName(id: id) { returnValue in
            continuation.resume(returning: returnValue)
        }
    }
}

// Result type:
@AddAsync
func fetchData(id: Int, completion: @escaping (Result<Data, Error>) -> Void) { ... }

// Generates:
func fetchData(id: Int) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        fetchData(id: id) { returnValue in
            switch returnValue {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**Key MacroTemplateKit patterns used:**

| Concept | API |
|---|---|
| `try await` expression | `Template.tryAwait(_:)` |
| `await` expression | `Template.awaitExpression(_:)` |
| Method call | `Template.methodCall(base:method:arguments:)` |
| Switch statement | `Statement.switchStatement(subject:cases:)` |
| Named switch cases | `SwitchCase(pattern: .expression(...), body: [...])` |
| Closure with params | `ClosureSignature(parameters:returnType:body:)` |
| `canThrow` on function | `FunctionSignature(..., canThrow: true, ...)` |

---

## PeerValueWithSuffixNameMacro

**File:** `PeerValueWithSuffixNameMacro.swift`

Generates a companion computed `Int` property whose name is the original
declaration's name suffixed with `_peer`.

```swift
@PeerValueWithSuffixName
var score: Double { 3.14 }

// Generates:
var score_peer: Int { 1 }
```

Also includes `PeerValueWithCustomSuffixMacro`, a variant that propagates the
original access level and accepts a configurable suffix string.

**Key MacroTemplateKit patterns used:**

| Concept | API |
|---|---|
| Computed property | `Declaration.computedProperty(ComputedPropertySignature(...))` |
| Getter body | `ComputedPropertySignature(getter: [.returnStatement(.literal(1))])` |
| Integer literal | `Template.literal(1)` via `Statement.returnStatement(.literal(1))` |
| Access level | `AccessLevel.public / .internal / .private / .fileprivate` |

---

## Design Contrast: BEFORE vs AFTER

### Raw string interpolation (BEFORE)

```swift
// Simple case — looks fine:
return ["var \(raw: name)_peer: Int { 1 }"]

// Multiline case — fragile indentation, untyped interpolations:
let body: ExprSyntax = """
  \(raw: isResult ? "try await withCheckedThrowingContinuation { continuation in"
                  : "await withCheckedContinuation { continuation in")
    \(raw: funcDecl.name)(\(raw: args.joined(separator: ", "))) { ... }
  }
"""
```

### MacroTemplateKit (AFTER)

```swift
// Simple case — full type safety, named property:
let peerProperty = Declaration<Void>.computedProperty(
    ComputedPropertySignature(name: peerName, type: "Int", getter: [
        .returnStatement(.literal(1))
    ])
)
return [Renderer.render(peerProperty)]

// Complex case — composable, each piece is a named value:
let resumeReturning: Template<Void> = .methodCall(
    base: .variable("continuation", payload: ()),
    method: "resume",
    arguments: [(label: "returning", value: .variable("value", payload: ()))]
)
let continuationCall: Template<Void> = .tryAwait(
    .functionCall(function: "withCheckedThrowingContinuation", arguments: [
        (label: nil, value: .closure(ClosureSignature(...)))
    ])
)
```

**Key benefits of the MacroTemplateKit approach:**

- Type-checked: the compiler validates the structure, not string concatenation
- Composable: sub-expressions are named `let` bindings, reusable and inspectable
- Testable: `Renderer.render(subExpr)` can be called on any intermediate value
- No raw: prefix needed to inject computed values into string literal positions
- Access levels, async/throws, and return types are typed enum/Bool values,
  not embedded keyword strings
