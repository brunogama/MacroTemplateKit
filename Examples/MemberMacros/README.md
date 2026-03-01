# Member Macro Examples

This directory contains side-by-side examples showing how to implement four
member macros from the swift-syntax example suite using MacroTemplateKit's typed
template algebra instead of raw string interpolation.

Each file contains:

- A "BEFORE" block (commented out) showing the original raw-string approach.
- An "AFTER" block (active code) showing the MacroTemplateKit approach.
- Inline design notes explaining every API boundary decision.

---

## Macros

### CaseDetectionMacro

File: `CaseDetectionMacro+MacroTemplateKit.swift`

Attaches to any enum and generates a `var isXxx: Bool` computed property for
every case. Example:

```swift
@CaseDetection
enum Direction { case north, south, east, west }
// expands to:
var isNorth: Bool { ... }
var isSouth: Bool { ... }
```

**MacroTemplateKit coverage:** `Declaration.computedProperty`,
`Statement.returnStatement`, `Statement.ifStatement`.

**Hybrid zone:** `if case .x = self` requires `MatchingPatternConditionSyntax`,
which is not yet modelled by the Template algebra. The surrounding property
scaffold is built with MacroTemplateKit; only the pattern condition node is
assembled with raw SwiftSyntax.

---

### CustomCodableMacro

File: `CustomCodableMacro+MacroTemplateKit.swift`

Generates a `CodingKeys: String, CodingKey` enum for `Codable` conformance,
honoring `@CodableKey("custom_name")` annotations. Example:

```swift
@CustomCodable
struct User {
  var firstName: String
  @CodableKey("last_name") var lastName: String
}
// expands to:
enum CodingKeys: String, CodingKey {
  case firstName
  case lastName = "last_name"
}
```

**MacroTemplateKit coverage:** Pure SwiftSyntax AST inspection of attributes
with no string interpolation; `EnumDeclSyntax` / `EnumCaseDeclSyntax` AST
construction for the enum body.

**Hybrid zone:** `enum CodingKeys` and `case` declarations are not in the
MacroTemplateKit algebra. They are constructed as raw AST nodes. However,
all attribute inspection (extracting `@CodableKey` values) uses pure AST
traversal with no string interpolation.

---

### DictionaryStorageMacro

File: `DictionaryStorageMacro+MacroTemplateKit.swift`

Injects a `_storage: [String: Any]` backing dictionary into the annotated type
(MemberMacro role), then provides get/set accessors that route through it
(AccessorMacro role). Example:

```swift
@DictionaryStorage
struct Config {
  var timeout: Int = 30
}
// MemberMacro injects:
var _storage: [String: Any] = [:]
// AccessorMacro (on each property) generates:
get { _storage["timeout", default: 30] as! Int }
set { _storage["timeout"] = newValue }
```

**MacroTemplateKit coverage:** `Declaration.property` with
`Template.dictionaryLiteral([])` for the `[:]` initializer; `Statement.assignmentStatement`
with `Template.subscriptAccess` for the setter body.

**Hybrid zone:** Subscript-with-default (`_storage["key", default: value]`) and
`as! Type` force-cast are not first-class Template cases. Only those two nodes
use raw SwiftSyntax assembly; everything else is typed.

---

### MetaEnumMacro

File: `MetaEnumMacro+MacroTemplateKit.swift`

Generates a nested `Meta` enum mirroring all parent cases, with an initializer
that maps from parent to meta. Example:

```swift
@MetaEnum
enum Planet { case mercury, venus, earth, mars }
// expands to:
enum Meta {
  case mercury; case venus; case earth; case mars
  init(_ parent: Planet) {
    switch parent {
    case .mercury: self = .mercury
    // ...
    }
  }
}
```

**MacroTemplateKit coverage:** `Declaration.initDecl`, `Statement.switchStatement`,
`SwitchCase` with `.expression` patterns, `Statement.assignmentStatement` for
`self = .caseName`.

**Hybrid zone:** `enum Meta` and `case` declarations use `EnumDeclSyntax` /
`EnumCaseDeclSyntax`. The switch body (the most complex part of the original
macro) is entirely MacroTemplateKit.

---

### NewTypeMacro

File: `NewTypeMacro+MacroTemplateKit.swift`

Implements the "newtype" pattern — generates `typealias RawValue`, a stored
`rawValue` property, and a forwarding `init`. Example:

```swift
@NewType(Int.self)
public struct UserID {}
// expands to:
public typealias RawValue = Int
public var rawValue: RawValue
public init(_ rawValue: RawValue) { self.rawValue = rawValue }
```

**MacroTemplateKit coverage:** `Declaration.property` for `var rawValue`;
`Declaration.initDecl` with `Statement.assignmentStatement` and
`Template.propertyAccess` for `self.rawValue = rawValue`.

**Hybrid zone:** `typealias` declarations are not yet in the MacroTemplateKit
algebra. The type alias uses `TypeAliasDeclSyntax` with the raw type name
inserted as an `IdentifierTypeSyntax` token — no string interpolation.

---

## Key Patterns

### When to use MacroTemplateKit

Use the typed API for everything that maps to `Declaration`, `Statement`, or
`Template` cases:

- Functions, stored properties, computed properties, extensions, structs, inits.
- `let`/`var` bindings, guard, if, switch, return, throw, assignment.
- Literals, variable references, member access, function calls, binary ops.

### When to fall back to raw SwiftSyntax

Fall back to raw SwiftSyntax AST construction (never to string interpolation)
for syntax nodes not yet in the MacroTemplateKit algebra:

- `enum` declarations and `case` members.
- `typealias` declarations.
- `if case` / `guard case` pattern matching conditions.
- Subscript-with-default arguments.
- `as!` / `as?` type casts.

### The hybrid rule

When a hybrid approach is needed, let MacroTemplateKit own the scaffold and use
raw SwiftSyntax only for the specific unsupported node. Never use string
interpolation (`"""...\(raw: ...)..."""`) in new code — always build AST nodes
directly.
