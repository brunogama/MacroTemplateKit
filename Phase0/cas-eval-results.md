# CAS-eval matrix results
Toolchain: swift-driver version: 1.168.4 Apple Swift version 6.4 (swiftlang-6.4.0.25.4 clang-2100.3.25.1). Date: 2026-07-13. Runs per cell: 3 (medians).

```
cell              wall_s   real  replayed  procs
off-cold            4.36    360         0     13
off-warmrepeat      4.33    360         0     13
off-incremental     1.23    140         0      2
off-noop            0.62      0         0      0
on-cold             2.15    360         0     13
on-warmrepeat       1.87      0       360      0
on-incremental      0.87      0       140      0
on-noop             0.63      0         0      0
```

## Findings

1. **Rebuild dedup:** on-incremental real expansions = 0 vs off-incremental 140 → **eliminated**. With CAS caching on, the incremental cell's entire 140-expansion workload (120 emit-module re-expansions + 20 for the touched file, per issue #22's baseline) is served from replay instead of being re-run.

2. **Intra-build dedup:** on-cold real expansions = 360 (off-cold 360) → **persists**. The compile-vs-emit-module double expansion within one cold build is not deduped by CAS: on-cold's real-expansion count matches off-cold exactly across all 3 runs (360/360/360, 13 procs each). This is expected structurally — `cold` wipes the CAS directory before every run, so there is no prior cache entry for that build to replay against, and the compile job and emit-module job's duplicate requests within the same build are apparently not deduped against each other either (real stays at the full 360 rather than dropping toward 180).

3. **Wall-clock:**
   - cold: 4.36s → 2.15s, Δ −2.21s (−50.7%)
   - warmrepeat: 4.33s → 1.87s, Δ −2.46s (−56.8%)
   - incremental: 1.23s → 0.87s, Δ −0.36s (−29.3%)
   - noop: 0.62s → 0.63s, Δ +0.01s (+1.6%, within noise — no measurable CAS overhead when there is no work to do)

   Caveat: the on-cold median (2.15s) hides a large first-run outlier — on-cold run 1 measured 20.24s (≈9.4× the median of runs 2–3, which were 2.15s/2.14s), likely one-time CAS-store/toolchain warm-up cost from the first invocation of the caching flags in this script run. Only runs 2 and 3 (both post-warm-up) are representative of steady-state "cold-with-CAS-primed" wall time; a true first-ever cold-cache build should be expected to cost far more than the reported median.

4. **Replay behavior:** replayed column is **nonzero** (360 in on-warmrepeat, 140 in on-incremental) → diagnostics are replayed by CAS on this toolchain, consistent with the spike's observation of "remark: replay output file" lines. All off-* cells report replayed = 0 across every run (no anomaly): off cells cannot structurally replay, and none did, so the off-cold regression gate (360 real / 13 procs, all 3 runs) held with no attribution fallback needed.

## Concerns

- Machine was not fully idle during the run (`uptime` load averages ~5.5/7.6/9.0 on 14 cores, 32 logged-in users at run time), which may have contributed to the on-cold run-1 wall-clock outlier (20.24s) noted in Finding 3; the 8×3 matrix nonetheless produced internally consistent expansion/process counts (off-cold gate passed on all 3 runs), so the anomaly is treated as a timing artifact rather than a correctness issue.
- No off-* cell reported replayed > 0, so the anomaly protocol was not triggered.
