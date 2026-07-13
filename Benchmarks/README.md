# RenderEngineBench

Measures two macro-shaped workloads with **switchable pipelines**, so the
construction- and edit-side claims from the SwiftSyntax optimization research
can be tested against each other on identical work:

- **generate** — the expansion pipeline (extract → build → render): all output
  is new syntax.
- **edit** — one small change to an existing, arbitrarily large tree: the
  round-trip-reparse scenario the research's bottleneck #6 describes.

## Run

```sh
cd Benchmarks
swift run -c release RenderEngineBench
swift run -c release RenderEngineBench --workloads edit
swift run -c release RenderEngineBench --pipelines structural,reparse --sizes 16,256 --iterations 500
swift run -c release RenderEngineBench --list
```

Results are only meaningful in release builds; a debug build prints a warning.

## Workload

DictionaryStorage-style expansion (mirrors
`Examples/MemberMacros/DictionaryStorageMacro+MacroTemplateKit.swift`): for a
struct with N stored properties, emit `var _storage: [String: Any] = [:]` plus
a getter/setter pair per property. Extraction from the parsed fixture runs
inside the timed region (a macro pays it on every expansion); parsing the
fixture itself does not (the compiler hands macros a parsed tree).

Before timing, all selected pipelines must produce **token-identical** output
for the same fixture; a failed equivalence check is printed prominently because
it means the timings compare different work.

## Pipelines ↔ research claims

Generate workload (`--pipelines`):

| Pipeline | Construction technique | Research claim exercised |
|---|---|---|
| `structural` | Raw SwiftSyntax node initializers, zero parser invocations | Baseline for “structural edits over reparse” (technique #5/#6) |
| `mtk` | `Template`/`Statement`/`Declaration` → `Renderer` | MacroTemplateKit’s abstraction cost over `structural` |
| `interpolation` | SwiftSyntaxBuilder string interpolation, one parse per fragment, nodes spliced via `\(node)` | Technique #5: parse-to-build for new fragments |
| `reparse` | Spliced nodes serialized with `trimmedDescription`, whole fragment re-parsed from a plain string | Bottleneck #6’s mechanism (serialize + re-lex), as a negative control |

Edit workload (`--edit-pipelines`) — inject one `_storage` member into an
existing N-property struct:

| Pipeline | Edit technique | Research claim exercised |
|---|---|---|
| `with-edit` | Targeted `with(\.memberBlock.members, …)` structural edit | Technique #5: small edits structurally; only the changed path reallocates |
| `rewriter` | `SyntaxRewriter` full walk, one members list changed | Technique #4: unchanged nodes returned by identity → structural sharing |

A `roundtrip-reparse` variant (`description` of the whole struct → textual
splice → full re-parse; bottleneck #6’s worst case) ran as a negative control
and was removed after delivering its verdict — see the snapshot below and git
history to resurrect it against a future swift-syntax release.

## Reading the numbers

- **retained KB/expansion** approximates the syntax-arena footprint one
  expansion leaves alive (malloc `bytes_used` delta while outputs are retained),
  not total allocation churn.
- The generate workload’s `reparse` variant serializes only the *small spliced
  nodes* (a type and a default-value expression); the research’s worst case —
  reparsing a large existing declaration to make a small edit — is measured by
  the edit workload’s `roundtrip-reparse` variant instead.

## Result snapshot (2026-07-13, M-series, swift-syntax 603.0.2, release)

| pipeline | props | p50 µs | vs structural | retained KB/expansion |
|---|---|---|---|---|
| structural | 16 | 365.8 | 1.00× | 390.8 |
| mtk | 16 | 363.5 | 0.99× | 387.4 |
| interpolation | 16 | 398.6 | 1.09× | 233.5 |
| reparse | 16 | 215.5 | 0.59× | 233.5 |
| structural | 256 | 5586 | 1.00× | 6170.6 |
| mtk | 256 | 5569 | 1.00× | 6084.2 |
| interpolation | 256 | 6487 | 1.16× | 3769.3 |
| reparse | 256 | 3540 | 0.63× | 3769.3 |

Edit workload (same date/machine/toolchain; `roundtrip-reparse` rows recorded
before the variant was removed):

| pipeline | props | p50 µs | vs with-edit | retained KB/run |
|---|---|---|---|---|
| with-edit | 4 | 12.2 | 1.00× | 15.5 |
| rewriter | 4 | 11.0 | 0.90× | 13.8 |
| roundtrip-reparse | 4 | 10.2 | 0.83× | 16.2 |
| with-edit | 16 | 11.2 | 1.00× | 15.7 |
| roundtrip-reparse | 16 | 35.6 | 3.17× | 40.4 |
| with-edit | 64 | 11.2 | 1.00× | 14.6 |
| roundtrip-reparse | 64 | 137.2 | 12.28× | 140.7 |
| with-edit | 256 | 12.8 | 1.00× | 16.2 |
| rewriter | 256 | 13.1 | 1.03× | 15.4 |
| roundtrip-reparse | 256 | 540.5 | 42.25× | 544.5 |

Headline findings (stable across reruns):

1. **`mtk` ≈ `structural`** — the template algebra adds no measurable overhead
   over hand-built SwiftSyntax nodes for the generation workload.
2. **Parsing small fragments beats structural construction** (~0.6× time,
   ~0.6× retained memory): the parser packs one arena per fragment, while
   per-node initializers allocate many small arenas.
3. **`\(node)` interpolation splicing costs more than raw-string reparse**
   (1.09–1.16× vs 0.59–0.63×): the interpolation path formats spliced nodes
   before serializing, which dominates its “single parse” advantage here.
4. **Bottleneck #6 confirmed on the edit workload**: `with-edit` and
   `rewriter` are flat ~11–13 µs and ~15 KB regardless of struct size
   (structural sharing pays only for the changed path), while
   `roundtrip-reparse` scales linearly with tree size — 3.2× at 16
   properties, 12.3× at 64, **42× at 256**, with retained memory scaling the
   same way. The crossover sits around ~5 properties: below it, reparsing a
   tiny tree is actually cheapest, consistent with finding #2.
