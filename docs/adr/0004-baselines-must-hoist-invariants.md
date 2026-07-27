# Benchmark baselines must hoist loop invariants

**Status:** accepted — measured

Every performance ratio this project publishes divides by a hand-rolled `structural`
pipeline written and maintained in this repository. Nobody had ever attacked it. This is the
record of doing so.

## What was wrong

`StructuralCaseFactoryPipeline` and `StructuralPipeline` rebuild expansion-invariant nodes
inside their per-item loop: the `static` modifier list, both parentheses, the wildcard and
colon tokens, the call's argument list, the return type. None of these vary across the items
being generated. A macro author writing the same code by hand would build them once.

Hoisting them — with no other change — makes the baseline substantially faster:

| workload | structural | structural-interned | speedup from hoisting alone |
|---|---|---|---|
| generate (256) | 5690 µs | 4811 µs | 1.18× |
| case-factory (256) | 3718 µs | 2319 µs | **1.60×** |

`case-factory` benefits far more because its invariant set is larger: the entire argument
list and return clause are constant across cases, whereas `generate` varies its accessor
bodies per property.

## Effect on the published claim

`min` over 3 runs, 2000+ iterations each:

| workload | vs `structural` | vs `structural-interned` |
|---|---|---|
| generate | 0.63–0.65× | **0.75–0.78×** |
| case-factory | 0.57–0.60× | **0.94–0.96×** |

(The previously published figures were 0.59–0.64× and 0.59–0.62×, taken from `p50` on a
noisier machine. The left column above is the same comparison re-measured on `min`; the
change between them is measurement noise, not a correction. The correction is the move to
the right-hand column.)

On `case-factory` the library's advantage was almost entirely the baseline failing to hoist.
Against a competent baseline it is at parity.

## How this was missed

The interned variant already existed, as `InternedStructuralPipeline`, named `mtk-micro`.
Two things hid it:

1. **It was evaluated as an implementation, not as a baseline.**
   `docs/superpowers/specs/2026-07-14-parse-backed-renderer-design.md` records it as
   "Approach B: interned structural — 0.77× → 0.88× — Rejected, under bar, fades with size."
   It was measured, judged too weak to *adopt*, and filed away. The same margin that
   disqualifies a technique as an implementation is what qualifies it as the thing to be
   measured against. Nobody turned the question around.
2. **Its name said `mtk-`.** Everything in the registry prefixed `mtk-` reads as a variant of
   the library under test, not as a rival to it. It is now `structural-interned`.

## Decisions

- `structural-interned` is added for both workloads and is the baseline the README quotes.
  `structural` is retained, because the gap between the two is itself the finding.
- A benchmark baseline is not a strawman to be beaten; it is an adversary. Adding one is
  incomplete until someone has tried to make it faster. Any future workload ships with a
  hoisted baseline from the start.
- Prefer `min` for cross-run comparison here. On a non-quiet machine `p50` swung by more than
  the entire effect being measured (structural at 256 properties: 7948 µs → 12946 µs between
  two runs), while `min` held to within 2%.

## Resolved: the trivia bias was real, small, and hid a worse problem

The section below was written when the trivia gap was unmeasured. It has since been measured,
and both of its claims were wrong.

`StructuralCaseFactoryPipeline` and its hoisted variant now attach trivia matching `mtk` byte
for byte. A control pipeline, `interned-notrivia`, keeps the old no-trivia construction so
both can be measured **in the same process** — which turned out to matter more than the
correction itself. At sizes 16/64/256, `min` over 3 runs:

| | 16 | 64 | 256 |
|---|---|---|---|
| `interned-notrivia` | 139.2 | 538.6 | 2166 |
| `structural-interned` (trivia) | 140.6 | 546.3 | 2249 |
| cost of trivia | +1.0% | +1.4% | +3.8% |

**On `case-factory`, trivia costs 1–4% — not enough to move that conclusion.** On the other
two workloads it is worth considerably more, because they carry more whitespace per generated
declaration. With every baseline matched:

| workload | trivia-free baseline | trivia-matched baseline |
|---|---|---|
| generate | 0.77× | **0.74×** |
| case-factory | 1.00–1.02× | 1.00–1.02× |
| case-path | 0.75× | **0.67–0.69×** |

So the prediction below — that a trivia-matched baseline "would be slower and would widen the
margin" — was right, and the initial `case-factory`-only measurement was the misleading one.
Writing the effect off as negligible after measuring it on the single workload where it *is*
negligible was the same mistake as publishing a favourable number from one session: a real
measurement, generalised past what it covered.

This correction makes the library look better, which is exactly why it is stated at this
length.

**The measurement noise is the real finding.** Running the correction surfaced that
`case-factory` absolutes drift ~10% between sessions for *identical* code: `mtk` at size 16
read 125.9 µs in one session and 140.8 µs in another with no change to its source. Within a
session the ordering is stable — across 5 consecutive runs at size 64, `interned-notrivia` <
`structural-interned` < `mtk` held in 4 of 5 — but across sessions it is not.

Re-measured with everything in one process, `case-factory` is:

| | vs `structural-interned` |
|---|---|
| previously published | 0.94–0.96× |
| **measured in-session** | **1.00–1.06×** |

**MacroTemplateKit is slightly *slower* than a hoisted hand-rolled baseline on this workload.**
The earlier figure was session-favourable noise, published because it was collected in a
session that happened to favour it and never re-run in the same process as its baseline.

`generate` and `case-path` reproduced their published figures in the same session, so the
effect is specific to `case-factory` — the workload with the smallest per-item work, where a
10% drift swamps the difference being measured. (Both have since moved again, for the
unrelated trivia reason above.)

### Methodology consequences

- **Never compare across sessions.** Only ratios computed from pipelines measured in the same
  process are meaningful. Every table must be produced by one invocation.
- **Do not claim a difference smaller than ~5%** on `case-factory`-shaped workloads. It is
  below this harness's demonstrated stability.
- Keep `interned-notrivia` in the registry. It is the control that makes the trivia claim
  falsifiable rather than asserted.
- Measure a bias on every workload before deciding it is negligible. Whitespace volume scales
  with declaration shape, so a single-workload sample said 1–4% where the true range is 1–8%.

## Original text: known remaining bias, uncorrected

The structural baselines attach no trivia: they produce
`staticfuncmakeCase0(_value:String)->Fixture2{...}`. The equivalence gate compares token
streams, which strips trivia, so it is blind to this. Whitespace is bytes to write and tokens
to allocate, so the baselines do slightly less work than the pipeline they are compared
against.

This bias runs *against* MacroTemplateKit — a trivia-matched baseline would be slower and
would widen the margin — which is precisely why it survived unnoticed for so long. It is left
in place and documented rather than corrected, because a change that improves our own numbers
warrants more scrutiny than one that worsens them, and the published figures are conservative
as they stand. `--workloads trivia` prints the raw output of every pipeline.

Correcting it is open work. It could plausibly move `case-factory` off parity, so it should
be done by someone willing to publish whichever direction it lands.
