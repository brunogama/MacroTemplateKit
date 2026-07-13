# MacroTemplateKit

A typed template algebra for Swift macro authors: instead of assembling SwiftSyntax
nodes or interpolating strings by hand, macros build `Template`/`Statement`/`Declaration`
values and render them to SwiftSyntax.

## Language

**Template**:
The typed AST value a macro author builds to describe an expression to generate. Carries
a phantom payload type that exists only at compile time.

**Statement**:
The typed AST value describing a statement to generate (assignments, control flow).

**Declaration**:
The typed AST value describing a whole declaration to generate (properties, functions, structs).

**Render Engine**:
The `Renderer` family — the forward-only transformation from Template/Statement/Declaration
values to SwiftSyntax nodes. Does not include extraction.
_Avoid_: generator, emitter

**Extractor**:
The reverse direction: reads parsed SwiftSyntax declarations into typed signatures. Not part
of the render engine.
_Avoid_: parser (that's SwiftParser's job)

**Expansion Pipeline**:
The full round trip a macro pays per expansion: extract from the input tree, build templates,
render to SwiftSyntax. The unit the render-engine benchmark measures.
_Avoid_: round trip (collides with the description-reparse anti-pattern), render engine (that's the forward half only)

## Benchmarking

**AST Generator Pipeline**:
One switchable construction strategy in the benchmark harness (structural initializers,
MacroTemplateKit templates, string-interpolation parse, description-reparse). All variants
must produce token-identical output for the same fixture.
_Avoid_: backend, mode

**Fixture**:
A generated, realistic annotated struct (parameterized by stored-property count) parsed once
before timing. Parsing is excluded from measurement because the compiler hands macros an
already-parsed tree.

**Workload**:
The macro-shaped task every pipeline performs on a fixture. Two exist: the **generation
workload** (DictionaryStorage-style expansion — all output is new syntax) and the **edit
workload** (one small change to an existing, arbitrarily large tree). Techniques rank
differently on each, so results from one workload must not be quoted for the other.

**Round Trip**:
Serializing an existing syntax tree to a source string and re-parsing the whole string to
make a small change. Measured by the edit workload's (since removed) negative control and
indicted at scale — distinct from the expansion pipeline, which is sometimes loosely called
a "round trip" but never serializes.
_Avoid_: using "round trip" for the expansion pipeline
