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

## Workloads

| Name | Shape | Question |
|---|---|---|
| `generate` | accessor pair per stored property | abstraction cost on accessor-shaped macros |
| `case-factory` | static factory per enum case | flat declarations, few nested nodes |
| `case-path` | `@CasePathable`-style `AnyCasePath` property per case | the shape TCA-style apps actually pay for |
| `edit` | inject one member into an existing struct | structural sharing vs round-trip reparse |
| `accumulate` | expansions under `dropped` vs `retained` lifetimes | does per-expansion memory compound across a build? |
| `trivia` | verbatim output of every pipeline | what the token-equivalence gate cannot see |

The first three are ordered by depth of the generated declaration, which is the
variable that turns out to decide the outcome — see the snapshot.

`generate` is a DictionaryStorage-style expansion (mirrors
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
| `structural-interned` | The same, with expansion-invariant nodes hoisted out of the loop | **The baseline ratios are quoted against.** `structural` rebuilds invariants per item, which a macro author would not — see [ADR 0004](../docs/adr/0004-baselines-must-hoist-invariants.md) |
| `mtk` | `Template`/`Statement`/`Declaration` → `Renderer` | MacroTemplateKit’s abstraction cost over a competent hand-rolled equivalent |
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

- **Take `min` over at least 3 runs, not `p50`.** On a machine that is not
  quiet, `p50` for the same binary has swung by more than the entire effect
  being measured (`structural` at 256 properties: 7948 µs → 12946 µs between
  two runs) while `min` held to within 2%. The merge gate in
  [ADR 0005](../docs/adr/0005-render-engine-merge-gate-v2.md) is specified on
  `min` for this reason. `p50`/`p90` stay in the output for distribution shape.
- **Quote ratios against `structural-interned`, not `structural`.** See ADR
  0004. The `structural` column is kept for context — the gap between the two
  columns is itself the finding.
- **retained KB/expansion** approximates the syntax-arena footprint one
  expansion leaves alive (malloc `bytes_used` delta while outputs are retained),
  not total allocation churn. **It is a regression detector, not a user
  benefit.** It is a sensitive proxy for per-expansion render count, so a change
  that raises render counts shows up here before it shows up in timings. But a
  plugin drops each tree after serialising it, and under that lifetime memory is
  flat across a 2048× expansion sweep — so this number must never be published
  as a memory saving. See
  [ADR 0003](../docs/adr/0003-memory-win-does-not-accumulate.md), and
  `--workloads accumulate` to reproduce.
- **The equivalence gate compares token streams, which strips trivia.** The
  structural baselines attach none, emitting `staticfuncmakeCase0(_value:String)`
  where `mtk` emits spaced source, so they are measured doing slightly less work.
  The bias runs *against* `mtk`, which is why it went unnoticed; the ratios below
  are conservative by an unmeasured margin. `--workloads trivia` shows it.
- The generate workload’s `reparse` variant serializes only the *small spliced
  nodes* (a type and a default-value expression); the research’s worst case —
  reparsing a large existing declaration to make a small edit — is measured by
  the edit workload’s `roundtrip-reparse` variant instead.

## Result snapshot (2026-07-25, M-series, swift-syntax 603.0.2, release)

`min` µs over 3 runs at `--iterations 1200 --warmup 300`. These are the figures
[ADR 0005](../docs/adr/0005-render-engine-merge-gate-v2.md) gates against.

| workload | props | structural | structural-interned | mtk | vs interned |
|---|---|---|---|---|---|
| generate | 16 | 345.9 | 282.1 | 219.0 | **0.78×** |
| generate | 64 | 1348 | 1165 | 876.6 | **0.75×** |
| generate | 256 | 5690 | 4811 | 3680 | **0.76×** |
| case-factory | 16 | 212.2 | 132.9 | 125.9 | **0.95×** |
| case-factory | 64 | 870.9 | 527.0 | 496.2 | **0.94×** |
| case-factory | 256 | 3718 | 2319 | 2218 | **0.96×** |
| case-path | 16 | 648.8 | 408.2 | 312.8 | **0.77×** |
| case-path | 64 | 2628 | 1658 | 1224 | **0.74×** |
| case-path | 256 | 10772 | 6721 | 4958 | **0.74×** |

**Depth decides.** The three workloads are ordered by how deep the generated
declaration is, and the ratio tracks it: flat static factories land at parity,
accessor pairs at ~0.76×, and a `AnyCasePath` property — closures inside labeled
arguments inside a generic getter, ~70 nodes — at ~0.74×. Structural construction
pays per node; the emitter appends text and parses once per declaration. Hoisting
cannot close that gap, because the tree varies per case at its leaves and must
still be assembled per case.

Note how much of the apparent advantage was baseline error: on `case-factory`,
`structural`→`structural-interned` is a 1.60× speedup from hoisting alone, which
is nearly the whole 0.57× that column would otherwise report.

The prior snapshot (2026-07-13) recorded `mtk` at 0.99–1.00× vs `structural` —
the pre-cutover renderer, where the library cost nothing and bought nothing.

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

1. **`mtk` beats a competent hand-rolled baseline on nested declarations, and
   ties on flat ones** — 0.74–0.78× on `case-path` and `generate`, 0.94–0.96×
   on `case-factory`. Depth is the variable. (This supersedes the earlier
   "`mtk` ≈ `structural`" finding, which measured the pre-cutover renderer.)
2. **Parsing small fragments beats structural construction** (~0.6× time): the
   parser packs one arena per fragment, while per-node initializers allocate
   many small arenas. The matching ~0.6× *memory* figure originally recorded
   here has been withdrawn — it holds only while every rendered tree is kept
   alive, which no plugin does (ADR 0003).
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
5. **A baseline nobody has attacked is not a baseline.** `structural` was
   written here, published against for weeks, and turned out to be beatable by
   up to 1.60× with no cleverness — just hoisting loop invariants. Any new
   workload ships with a hoisted baseline from the start (ADR 0004).
