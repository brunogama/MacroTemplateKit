# Parse-Backed Renderer — Design

**Date:** 2026-07-14
**Branch:** `perf/render-engine`
**Status:** Approved (spike-validated)

## Goal

Make `Renderer` ~40% faster and ~40% lighter per expansion, transparently:
same public API, token-identical output. Users get the win on upgrade with no
code changes.

## Decisions (from brainstorm)

1. **Target:** Renderer internals, same API. Not an opt-in mode, not a
   user-facing toolkit.
2. **Compatibility bar:** token-identical output. Whitespace/trivia may
   differ; MTK tests asserting exact text are updated once.
3. **Merge criterion:** `mtk` benchmark pipeline p50 improves **≥25% at every
   fixture size** (4/16/64/256 properties) on the generate workload, retained
   memory does not grow, and the token-equivalence gate passes.

## Evidence

Spike (2026-07-13, swift-syntax 603.0.2, release, `Benchmarks/` harness,
all variants token-identical):

| Approach | p50 vs mtk (4→256 props) | Retained memory | Verdict |
|---|---|---|---|
| A: parse-backed (`mtk-parse`) | 0.58× / 0.59× / 0.61× / 0.58× | ~0.6× | **Selected** — clears bar at every size |
| B: interned structural (`mtk-micro`) | 0.77× → 0.88× | ~0.85× | Rejected — under bar, fades with size |
| C: memoization (`mtk-memo`, 100% hit) | 0.01× | ~0 | Deferred — upper bound only; real hit rate unknown |

Corroborating research (deep-research run, 2026-07-13): string-literal parsing
is one of swift-syntax's three documented construction paths and the parser
auto-invokes on macro string literals (SwiftSyntaxMacros docs, 3-0 verified);
the parser packs one arena per fragment, which explains the memory win.

## Architecture

`Renderer.render(_:)` keeps its signatures (`Template<A> → ExprSyntax`,
`Statement<A> → CodeBlockItemSyntax`, `Declaration<A> → DeclSyntax`). Internally,
per-node structural construction is replaced by a two-stage pipeline:

1. **SourceEmitter** — walks the template value appending Swift source text to
   a single `String` buffer. One emitter visit per algebra case, mirroring the
   current renderer's case coverage. The algebra is already string-shaped
   (e.g., `PropertySignature.type: String`), so most emission is direct
   append; no syntax nodes are created during emission.
2. **Single parse** — the buffer is parsed once per rendered fragment into the
   target node type (the same mechanism as `DeclSyntax(stringLiteral:)`),
   replacing both per-node initializers and the ~14 existing per-field
   `stringLiteral` mini-parses.

Components:

- `SourceEmitter` (new, internal): `emit(Template<A>, into: inout String)`,
  plus overloads for `Statement`/`Declaration` and the signature types.
  Escaping rules for string literals live here.
- `Renderer` (unchanged surface): façade that calls the emitter then parses.
- Existing structural code paths are deleted once parity is proven, not kept
  as a parallel mode (a second backend would double maintenance; git history
  preserves it).

## Error handling

- Structural rendering today assembles whatever nodes it's given, valid or
  not. Parse-backed rendering yields parser recovery (`missing`/`unexpected`
  nodes) for degenerate input (e.g., an invalid identifier in a signature).
  This is a behavior change to document in the changelog; recovery nodes
  surface errors closer to the cause than silently invalid trees.
- Debug builds assert that the parsed fragment contains no `missing` nodes
  (`hasError` on the raw layer) to catch emitter bugs early.

## Testing

1. **Token-equivalence gate:** the `Benchmarks/` harness compares the new
   renderer's output against the structural reference token-for-token; this is
   the primary parity guarantee (already built and passing for the spike).
2. **Existing MTK test suite:** must pass; tests asserting exact trivia are
   updated once with the new canonical output.
3. **Merge gate:** benchmark generate workload, `mtk` pipeline: ≥25% p50
   improvement at every size, no retained-memory regression.

## Out of scope

- Approach B (token interning): rejected on spike data.
- Approach C (memoization): deferred; revisit only with evidence of
  repetitive real-world workloads. The purity argument (SE-0382) is recorded
  here for that future discussion.
- Extractor changes, `lexicalContext` helper APIs, and documentation
  deliverables from the research: separate efforts.
