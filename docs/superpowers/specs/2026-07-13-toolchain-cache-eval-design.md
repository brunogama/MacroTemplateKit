# Toolchain compilation-cache evaluation for macro expansion — design

Date: 2026-07-13
Status: approved (brainstorming session)
Context: follows issue #22 (Phase-0 verdict: Gating Rule 1, no in-plugin cache).
Vocabulary: `CONTEXT.md`. Prior decisions: `docs/adr/0001-opt-in-expansion-caching-with-declared-read-set.md`.

## Problem

Issue #22's Lifetime Probe proved the repeat-expansion waste in macro-heavy
builds is real but lives **across plugin process boundaries**: every attached
macro expands twice per clean build (compile job + emit-module job), and every
incremental rebuild re-expands all of a module's member macros in fresh
processes. An in-plugin cache cannot reach any of it (hence the #22 verdict).
The layer that can is the toolchain's content-addressed compilation caching
(CAS: explicit modules + cached compile jobs). Whether it actually eliminates
this waste — and how a macro-heavy project turns it on — is unmeasured and
undocumented.

## Deliverables

1. `Scripts/cas-eval.sh` — a probe-instrumented A/B matrix runner reusing the
   Phase-0 fixture (`Phase0/` package: 120 unique `@Probed` structs + 120
   identical `#probeMark()` across 12 files) and its PROBE-diagnostic parsing.
2. A DocC article in `Sources/MacroTemplateKit/Documentation.docc`:
   **"Build performance for macro-heavy projects"** — measured guidance for
   macro authors and their users.
3. A new GitHub issue tracking this work, referencing (not reopening) #22.

## Measurement design

**Spike gate (step zero).** Verify the local Swift 6.4 toolchain can cache
plugin-bearing compile jobs: pin the exact flag spelling (swift-driver CAS
flags for SwiftPM builds; Xcode equivalent noted if documented), run one
cached build of the fixture, confirm cache hits occur at all. If flags are
missing or macro jobs are ineligible for caching, the project short-circuits:
the docs article becomes "not yet available on current toolchains, here is
what to watch for," and the matrix below is skipped. That outcome is a
success, not a failure.

**Matrix.** 2 × 4 cells, each run 3× with medians reported:

| axis | values |
|---|---|
| caching | off, on |
| scenario | cold (all fixture sources invalidated + fresh CAS; dependency artifacts kept, since the measurand is macro/module work, not swift-syntax rebuilds) · warm-repeat (all sources invalidated, kept CAS — the shared-CI-cache scenario) · incremental (touch 1 of 12 files) · no-op |

Each cell records wall-clock, deduped PROBE lines, and plugin process count.

**Expansion-vs-replay attribution.** CAS replays cached diagnostics when it
skips a job, which would poison naive expansion counting. The probe embeds the
plugin pid in every PROBE message, so the analyzer classifies each line: pid
spawned during this build → real expansion; pid from a previous build → replayed
output, expansion skipped. Per cell this yields `real expansions`,
`replayed`, `wall-clock`.

**Findings the matrix must answer.**
1. Rebuild dedup: with caching on, does the incremental scenario's
   120-expansion emit-module re-run disappear?
2. Intra-build dedup: in the cold-with-cache cell, does the
   compile-vs-emit-module double expansion persist (expected yes — two jobs,
   two cache keys)? This bounds what caching can ever give a cold build.
3. What are the wall-clock deltas per scenario — is the win worth the setup?

## Docs article structure

1. Why macros cost build time (stage numbers from #22).
2. Why MacroTemplateKit deliberately has no in-plugin cache (one paragraph,
   link to #22).
3. What toolchain compilation caching does about it (matrix numbers).
4. How to enable it (spike-verified flags, SwiftPM and Xcode).
5. Honest limitations: cold builds, cache invalidation when the macro plugin
   itself rebuilds, toolchain maturity.

Every claim traces to a measured cell or a linked issue.

## Risks and handling

- **Flags absent/broken** → spike gate converts project to the shorter
  "not yet available" article (see above).
- **CAS doesn't replay warning diagnostics** → replayed column reads zero
  while totals drop; analyzer detects and flags this, falls back to
  wall-clock + expansion-count deltas.
- **Timing noise** → 3 runs per cell, median, machine-idle protocol in the
  script header.

## Testing

- `cas-eval.sh` asserts its cache-off cells reproduce #22's known fixture
  counts (360 expansions, 13 processes for a full-module build) — a built-in
  regression check on the rig itself.
- The article's enable-instructions are validated by running them verbatim in
  the spike.

## Out of scope

- Reopening in-plugin caching (closed by #22's Gating Rule).
- Building any caching tool or upstream toolchain contribution.
- Pre-expansion/codegen workflows (considered and set aside during
  brainstorming: they trade away macro ergonomics).
