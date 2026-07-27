# The render-engine merge gate trades speed for memory

**Status:** superseded by [ADR 0005](0005-render-engine-merge-gate-v2.md)

The gate defined here is no longer in force. Its statistic (`p50`), its baseline
(`structural`), its single workload (`generate`), and its memory criterion have each been
shown to measure the wrong thing — see ADRs 0003, 0004 and 0005. The document is kept because
the reasoning about goalpost-moving in it still applies, and because ADR 0005 is only legible
next to what it replaced.

The parse-backed renderer plan set the merge gate at "`mtk` pipeline p50 improves ≥25% at
sizes 4/16/64/256 on the generate workload, retained KB does not grow." That number came from
a *spike* — a hand-written emitter specialised to the DictionaryStorage fixture, which
measured ~0.58–0.61× against structural construction. The spike was never a forecast of the
general implementation, which pays for covering every `Template`, `Statement`, and
`Declaration` case.

Measured against the pre-cutover commit (`b3571f9`), both binaries built with the same
toolchain and run back to back:

| props | p50 before | p50 after | gain | retained KB before | after | change |
|---|---|---|---|---|---|---|
| 4 | 95.5 | 67.2 | 29.6% | 102.5 | 54.1 | −47.2% |
| 16 | 357.8 | 273.9 | 23.4% | 387.0 | 218.6 | −43.5% |
| 64 | 1417 | 1108 | 21.8% | 1526.4 | 879.0 | −42.4% |
| 256 | 5699 | 4510 | 20.9% | 6083.9 | 3517.4 | −42.2% |

The speed target is missed at three of four sizes. The memory result is far better than the
gate asked for: retained memory did not merely fail to grow, it fell by more than 40%
everywhere. We therefore restate the gate as **p50 improves ≥20% at every size, and retained
KB shrinks by ≥35% at every size** — weakening the speed requirement to what the general
implementation actually achieves, and strengthening the memory requirement from "does not
grow" to a floor the implementation clears with room to spare.

This is goalpost-moving, and worth naming as such: the number was chosen after seeing the
result. What makes it defensible is that the original 25% was itself an extrapolation from a
specialised spike rather than a product requirement, and that the revised gate is strictly
harder to pass on the axis where the implementation is strong.

## What made the memory result possible

The regression that existed before this change was not caused by the parse-backed design. It
was caused by parse *count*. The benchmark's `mtk` pipeline rendered leaf expressions one at
a time and assembled accessors with handwritten SwiftSyntax — 769 renders per expansion at
256 properties, each allocating its own `RawSyntaxArena`, all retained by the returned nodes.
Measured that way the shipped renderer retained 6910 KB, *worse* than the 6084 KB baseline.

That pipeline was written that way out of necessity: MacroTemplateKit could not express
`_storage["name", default: x] as! Type`, because it had no cast case, nor a bare `set { }`,
because `SetterSignature.parameterName` was mandatory. Adding both let the whole computed
property render in one call — 257 parses instead of 769 — which is where the >40% reduction
comes from.

The general lesson, which belongs in user-facing docs: **the parse-backed renderer's cost is
dominated by the number of `render` calls, not by total output size.** The previous structural
renderer was flat across granularities. This one is not, and a user who renders leaf
expressions in a loop will see a regression on upgrade.

## Consequences

- The gate is now measured against a pipeline that uses the library idiomatically. The
  previous workaround pipeline has been deleted rather than kept alongside, so there is one
  `mtk` number and it reflects supported usage.
- Any future change that raises per-expansion render counts will show up as a memory
  regression against the ≥35% floor.
- **Superseded in part by [ADR 0003](0003-memory-win-does-not-accumulate.md).** The ≥35%
  memory criterion was measured under a model that holds every rendered tree alive at once.
  A plugin does not, and the difference is now measured to be invisible to users. The
  criterion is still useful as a *regression detector* — it is a sensitive proxy for
  per-expansion render count, which is the thing the granularity cliff punishes — but it must
  not be read as a user-facing benefit, and it should not appear in the README.
- Speed remains the weaker axis. If a future optimisation reaches 25% at all sizes, tighten
  this back rather than leaving the relaxed number in place.
- ~~Not addressed here: the renderer still has no verbatim/raw-expression case, so splicing an
  existing `ExprSyntax` into a template requires passing its `trimmedDescription` through
  `.variable`.~~ Resolved afterwards by `Template.syntax(ExprSyntax)`. Worth recording what
  the fix actually bought: splicing a node turned out to be performance-neutral on the parse
  path, exactly as predicted. The measured win came from no longer calling
  `trimmedDescription`, which builds a detached trivia-stripped tree before serialising — not
  from avoiding the round trip.
