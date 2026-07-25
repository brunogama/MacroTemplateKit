# The memory win is per-live-tree and does not accumulate

**Status:** accepted — measured

The parse-backed pipeline retains ~0.53–0.57× the memory of structural construction per
expansion, and that number was promoted to the README next to the timing ratios. It was
never verified against how a macro plugin actually behaves.

`measureLoop` in `Benchmarks/Sources/RenderEngineBench/Metrics.swift` measures memory by
appending every rendered output to an array and holding all of them alive at once:

```swift
var retained: [Output] = []
for _ in 0..<memoryIterations { retained.append(body()) }
```

So "retained KB/run" answers *how large is one live tree*. A macro plugin does not work that
way: it serialises its result to source text, hands that back to the compiler over the plugin
protocol, and the tree it built becomes garbage before the next expansion begins.

The `accumulate` workload measures both lifetimes directly — process malloc `bytes_used` and
kernel `phys_footprint` across a run, at 16 stored properties:

| pipeline | lifetime | expansions | malloc Δ | footprint Δ | KB/expansion |
|---|---|---|---|---|---|
| structural | dropped | 64 | 0.05 MB | 0.06 MB | 0.7 |
| structural | dropped | 1024 | 0.08 MB | 0.08 MB | 0.1 |
| structural | dropped | 16384 | 0.02 MB | 0.02 MB | 0.0 |
| structural | dropped | 131072 | 0.00 MB | 0.00 MB | 0.0 |
| mtk | dropped | 131072 | 0.00 MB | 0.00 MB | 0.0 |
| structural | retained | 1024 | 392.96 MB | 298.95 MB | 393.0 |
| mtk | retained | 1024 | 220.35 MB | 160.83 MB | 220.4 |

Under `dropped`, a 2048× increase in expansions produces no measurable growth in either
metric. A leak of even one byte per expansion would surface as 131 KB at the largest cell; it
reads 0.00 MB. `RawSyntaxArena` is released with the last node that references it, and
nothing survives an expansion to hold one.

Under `retained`, growth is exactly linear and the ratio is 220.4 / 393.0 = **0.56×**,
reproducing the headline figure. The measurement was never wrong. Its interpretation was.

## Consequence

**A plugin's peak memory is one expansion's worth, regardless of how many expansions a build
performs.** The per-expansion difference is therefore multiplied by a count that is always 1:
~170 KB, once, inside a compiler process that works in hundreds of megabytes. It is not
observable.

The README's `retained memory` column is removed from the headline table. Keeping it beside
the timing ratios implied a build-level benefit that does not exist — a reader would take
"~0.57×" to mean their plugin uses 43% less memory, which is false. The figure survives in
the benchmark output, where it is labelled as what it is.

**The timing claim is unaffected.** Time genuinely accumulates: every expansion pays it, and
a build pays the sum. That is the claim the library rests on, and this result narrows the
pitch to it rather than weakening it.

## What this does not say

It does not say the arena design is irrelevant to memory. It says the *difference between
pipelines* does not compound. A single pathological expansion — one macro over a very large
type — still allocates proportionally, and there `0.56×` is a real reduction in the peak. No
such case has been measured, and none is claimed.

Related: [ADR 0002](0002-relax-render-engine-merge-gate.md) set the merge gate at ≥35% memory
reduction. That criterion measured the retained model, so it was gating on a quantity that
does not reach users. Future gates should use `dropped`, or drop the memory criterion.
