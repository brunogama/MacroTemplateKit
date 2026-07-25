# The render-engine merge gate, restated

**Status:** accepted — supersedes the gate in [ADR 0002](0002-relax-render-engine-merge-gate.md)

ADR 0002 set the gate at "`mtk` p50 improves ≥20% at every size on the generate workload, and
retained KB shrinks by ≥35%". Every clause of that has since been undermined by measurement:

- **`p50` is the wrong statistic on this hardware.** Between two runs of the same binary,
  `structural` at 256 properties read 7948 µs and then 12946 µs — a swing larger than the
  entire effect the gate measures. `min` over the same runs held to within 2%. A gate that
  noise can flip is not a gate.
- **The memory criterion measures something users never see.** [ADR 0003](0003-memory-win-does-not-accumulate.md)
  showed retained memory is flat across a 2048× expansion sweep once outputs are dropped, as a
  plugin drops them. The ≥35% floor gates a quantity that does not reach anyone.
- **The baseline was beatable.** [ADR 0004](0004-baselines-must-hoist-invariants.md) found the
  `structural` pipeline rebuilding loop invariants; hoisting alone made it up to 1.60× faster.
  A gate measured against it credits us for the baseline's mistake.
- **One workload is not enough.** `generate` was the only gated shape. `case-factory` sits at
  parity and `case-path` at 0.74×; a gate on `generate` alone would have reported none of that.

## The gate

A change to the render engine merges when all of the following hold, measured with
`--iterations 1200 --warmup 300` at sizes 16/64/256, taking **`min` over at least 3 runs**:

0. **Every figure in a comparison comes from one invocation of the benchmark.** Cross-session
   absolutes drift ~10% on this hardware for identical code, which is larger than most effects
   being gated. Ratios computed across sessions are not evidence. See ADR 0004.
1. **`mtk` beats `structural-interned` on `generate` and `case-path`,** and is within 10% of
   it on `case-factory`, where it currently sits at 1.00–1.06× — i.e. slightly slower. The
   hoisted baseline is the comparison; `structural` is reported for context only.
2. **No workload regresses more than 5%** against the figures recorded below.
3. **The equivalence gate passes** on every workload — token-identical output across all
   pipelines in the registry.
4. **`--workloads accumulate` stays flat**: malloc Δ and footprint Δ under the `dropped`
   lifetime must not grow with expansion count across the 64 → 131072 sweep. This is the
   check that the arena-per-parse design has not started leaking.

Recorded figures, `min` over 3 runs, `mtk` vs `structural-interned`:

| workload | 16 | 64 | 256 |
|---|---|---|---|
| generate | 0.77× | 0.79× | 0.75× |
| case-factory | 1.00× | 1.03× | 1.00× |
| case-path | 0.78× | 0.73× | 0.76× |

## On memory

Retained KB/run is **kept as a regression detector and removed as a success criterion.** It is
a sensitive proxy for per-expansion render count — the quantity the granularity cliff punishes
— so a change that quietly raises render counts shows up there first, long before it shows up
in a timing p50. That makes it worth watching. It is not worth advertising, and it must not
appear in the README or CHANGELOG as a user benefit.

Concretely: if retained KB/run rises by more than 10% on any workload, investigate the render
count before merging. There is no floor it must clear.

## On goalpost-moving

ADR 0002 named its own goalpost-moving, and this ADR moves them again, so the same scrutiny
applies. The distinction worth holding: 0002 changed the *thresholds* after seeing the result.
This changes the *statistic*, the *baseline*, and the *workload set* — each because the old
choice was shown to be measuring the wrong thing, and two of the three changes make the gate
**harder** to pass. The thresholds here are recorded rather than chosen; clause 2 gates on not
regressing from them, not on clearing a number picked to be clearable.

The one clause that is a genuine relaxation is `case-factory`'s "within 5%" instead of a win.
That is honest: the library is at parity on flat declaration shapes and demanding a win there
would either block correct changes or invite baseline sabotage.

## Consequences

- `min` over repeated runs is the reported statistic everywhere. p50/p90 remain in the
  benchmark output for shape, not for gating.
- Any new workload ships with a hoisted baseline from the start (ADR 0004), and joins clause 1
  once its figures are recorded here.
- The trivia bias flagged in ADR 0004 has been measured and corrected on `case-factory`: it is
  worth 1–4%, below this harness's stability. `generate` and `case-path` baselines still carry
  it, and that is now a bounded ~1–4% conservatism rather than an unknown.
- The `case-factory` figures above are *worse* than what was previously published (0.94–0.96×).
  That was session-favourable noise. Anyone re-recording this table should expect the numbers
  to be uncomfortable and publish them anyway; the gate is worth nothing if the figures it
  compares against were selected for being flattering.
