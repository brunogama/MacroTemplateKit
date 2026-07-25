# The parse gate throws instead of asserting

**Status:** accepted

The render engine no longer builds SwiftSyntax nodes structurally; `SourceEmitter` appends
Swift source text to a buffer that `Renderer` parses once per fragment. That makes an
unparsable buffer a real failure mode, and it was guarded only by
`assert(!expr.hasError, ...)` — which the compiler strips from release builds. Macro plugins
ship release, so the one correctness guard on the new pipeline was disabled precisely where
it mattered: a malformed emit would hand an error-laden tree to the compiler, which would
then report a confusing diagnostic against the *user's* code rather than against the bug in
this library.

We therefore make the parse gate live in release by having `Renderer`'s public render entry
points `throw` a `RenderError` carrying the offending buffer and the parse diagnostic.
`RenderError` is defined in MacroTemplateKit rather than reusing
`SwiftSyntaxMacros.MacroExpansionErrorMessage`, so the core library keeps its existing
dependencies (`SwiftSyntax`, `SwiftSyntaxBuilder`) and does not take on `SwiftSyntaxMacros`.
Since `expansion(...)` in the macro protocols is already `throws`, a thrown error propagates
into a proper compiler diagnostic without the author writing any handling code.

## Considered options

- **Keep `assert`.** Rejected: compiled out in release, which is the only configuration a
  macro plugin ships in.
- **Promote to `precondition`.** Live in release, but traps. A trap surfaces as "external
  macro implementation crashed", which loses the buffer and the parse diagnostic that make
  the failure actionable.
- **Emit a `#error(...)` node instead of failing.** Attractive because it breaks no call
  sites, but unsound: `#error` is a declaration-level construct, while `Renderer.render`
  returns `ExprSyntax` across the entire `Template` surface. It cannot cover the main path.

## Consequences

- **This is a breaking API change.** Every `Renderer.render` call site needs `try` —
  including roughly fifteen README examples — and `rendered` becomes
  `var rendered: DeclSyntax { get throws }`. The README's "Pure, deterministic rendering.
  `Renderer.render` has no side effects" claim needs rewording.
- **Callers cannot meaningfully recover.** An unparsable buffer is always a defect in this
  library, never a recoverable condition in the author's macro. The throw exists to produce
  a good diagnostic and name the culprit, not to offer a retry path. Documentation should
  say so, or authors will reach for `try!`.
- **The gate is syntactic only.** It catches malformed emitter output (`foo(`, unbalanced
  braces). It does not catch well-formed-but-wrong output: `Template.operation(left:
  .literal(1), op: "&&", right: .literal("hello"))` emits `1 && "hello"`, which parses
  cleanly, passes the gate, and is rejected downstream against the user's code. Closing that
  gap would require type-indexing `Template` by the Swift type of the expression, which is
  not possible for the types that matter — a macro reads `UserModel` out of a
  `StructDeclSyntax` as a *string*, so it can never appear as a type argument in the plugin's
  own compilation unit.
