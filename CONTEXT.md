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
`Renderer` — the single forward-only transformation from Template/Statement/Declaration
values to SwiftSyntax nodes. One concept, whatever files it spans. Does not include
extraction.
_Avoid_: generator, emitter, "the renderers" (there is one)

**Parse Gate**:
The check that source text produced for a fragment parses cleanly before the render engine
hands it back. Syntactic only — it catches malformed output, not output that parses but
means the wrong thing.
_Avoid_: validation (too broad — nothing here checks meaning)

**Extractor**:
The reverse direction: reads parsed SwiftSyntax declarations into typed signatures. Not part
of the render engine.
_Avoid_: parser (that's SwiftParser's job)

**Expansion Pipeline**:
Everything a macro pays per expansion: extract from the input tree, construct the output,
emit SwiftSyntax. The unit the generation workload measures — construction technique varies
by pipeline; only the MacroTemplateKit variant builds templates.
_Avoid_: round trip (collides with the description-reparse anti-pattern), render engine (that's the forward half only)

## Benchmarking

**AST Generator Pipeline**:
One switchable construction strategy in the generation workload (structural initializers,
MacroTemplateKit templates, string-interpolation parse, description-reparse). All variants
must produce token-identical output for the same fixture.
_Avoid_: backend, mode

**Tree Edit Pipeline**:
One switchable edit strategy in the edit workload (targeted structural edit, rewriter).
Same token-identical-output rule as AST generator pipelines. Distinct from generation:
an edit changes an existing tree rather than producing new syntax.
_Avoid_: conflating with AST generator pipeline

**Fixture**:
A generated, realistic annotated struct (parameterized by stored-property count) parsed once
before timing. Parsing is excluded from measurement because the compiler hands macros an
already-parsed tree.

**Workload**:
The macro-shaped task every pipeline performs on a fixture. Two exist: the **generation
workload** (DictionaryStorage-style expansion — all output is new syntax) and the **edit
workload** (one small change to an existing, arbitrarily large tree). Techniques rank
differently on each, so results from one workload must not be quoted for the other.

**Hoisted Baseline**:
A hand-rolled benchmark baseline that builds expansion-invariant nodes once instead of once
per generated item. The unhoisted version is not a fair adversary: hoisting alone made the
case-factory baseline 1.60x faster and erased most of the library's published advantage on
that workload (ADR 0004). A baseline is not finished until someone has tried to make it
faster.
_Avoid_: "the baseline" without saying which

**Output Lifetime**:
What happens to a rendered tree once the expansion that produced it ends. **Retained** holds
every output alive at once — the model `measureLoop` uses, and the only one that makes
"retained KB/run" meaningful. **Dropped** serializes to source and releases the tree, which
is what a macro plugin does. Memory figures must always name which one they measured: the
0.56x per-expansion ratio is real under retained and invisible under dropped, because peak
memory there is one expansion's worth however many expansions a build performs (ADR 0003).
_Avoid_: "memory usage" unqualified

**Round Trip**:
Serializing an existing syntax tree to a source string and re-parsing the whole string to
make a small change. Measured by the edit workload's (since removed) negative control and
indicted at scale — distinct from the expansion pipeline, which is sometimes loosely called
a "round trip" but never serializes.
_Avoid_: using "round trip" for the expansion pipeline
