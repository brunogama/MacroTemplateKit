# Toolchain Compilation-Cache Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Measure whether Swift's CAS compilation caching eliminates the cross-process repeat macro expansions found in issue #22, and publish the findings as a DocC article for macro authors.

**Architecture:** A spike pins the exact caching flags supported by the local Swift 6.4 toolchain and writes them to `Phase0/cas-flags.env`. A matrix runner (`Scripts/cas-eval.sh`) reuses the Phase-0 probe fixture and PROBE-diagnostic parsing to run {cache off, on} × {cold, warm-repeat, incremental, no-op}, classifying every PROBE line as a real expansion (fresh pid) or a cache-replayed diagnostic (pid seen in an earlier build). Results feed a DocC article where every claim traces to a measured cell.

**Tech Stack:** bash + python3 (analyzer), SwiftPM, the existing `Phase0/` package (`ProbeMacros` plugin + `ProbeClient` fixture), DocC.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-13-toolchain-cache-eval-design.md`. Prior art: `Scripts/lifetime-probe.sh` (style to follow), issue #22 (findings to reference, never reopen).
- The fixture is reused **verbatim**: 120 unique `@Probed` structs + 120 identical `#probeMark()` across 12 files in `Phase0/Sources/ProbeClient/`. Do not modify fixture files.
- Regression anchor: a cache-off full-module build must reproduce **360 expansions / 13 plugin processes** (from #22). If it doesn't, stop — the rig is broken.
- PROBE line format (already emitted by `ProbeMacros`): `PROBE kind=<member|expr> pid=<int> seq=<int> active=<int> input=<hex>`. Build logs echo each diagnostic more than once; always dedupe on the full tuple before counting.
- Every numeric claim in the DocC article must come from a cell of `Phase0/cas-eval-results.md` or from issue #22. No numbers from documentation or folklore.
- All matrix cells run 3×, medians reported.
- Branch: `eval/toolchain-cache` (never commit to main).

---

### Task 0: Commit the Phase-0 baseline and open the tracking issue

The eval builds on uncommitted Phase-0 artifacts; they must land first so later diffs are reviewable.

**Files:**
- Commit (already exist, uncommitted): `Phase0/` (Package.swift, Package.resolved, Sources/ — NOT `.build/`), `Scripts/lifetime-probe.sh`, `CONTEXT.md`, `docs/adr/0001-opt-in-expansion-caching-with-declared-read-set.md`
- Create: `Phase0/.gitignore`

**Interfaces:**
- Produces: a clean working tree on branch `eval/toolchain-cache`; tracking issue number `$ISSUE` used in later commit messages.

- [ ] **Step 1: Create branch and Phase0/.gitignore**

```bash
cd "$(git rev-parse --show-toplevel)"
git checkout -b eval/toolchain-cache
printf '.build/\n' > Phase0/.gitignore
```

- [ ] **Step 2: Commit the baseline**

```bash
git add Phase0/.gitignore Phase0/Package.swift Phase0/Package.resolved Phase0/Sources Scripts/lifetime-probe.sh CONTEXT.md docs/adr/
git commit -m "chore: land Phase-0 measurement rig and vocabulary (issue #22)"
git status --porcelain   # expected: empty (docs/superpowers/ already committed)
```

- [ ] **Step 3: Open the tracking issue**

```bash
gh issue create --repo brunogama/MacroTemplateKit \
  --title "Evaluate toolchain compilation caching for macro expansion (follow-up to #22)" \
  --body "Per docs/superpowers/specs/2026-07-13-toolchain-cache-eval-design.md: spike CAS flag support on Swift 6.4, run the probe-instrumented A/B matrix, publish a DocC article 'Build performance for macro-heavy projects'. References #22 (closed by Gating Rule 1); does not reopen it."
```

Record the printed issue number; reference it in every later commit message as `(#N)`.

---

### Task 1: Spike — pin CAS caching flags on the local toolchain

**Files:**
- Create: `Phase0/cas-flags.env`
- Create: `Phase0/SPIKE.md`

**Interfaces:**
- Produces: `Phase0/cas-flags.env`, sourced by Task 2's script, with exactly three variables:
  - `CAS_SUPPORTED=1` or `0`
  - `CAS_BUILD_FLAGS="..."` — flags appended to `swift build` to enable caching (empty if unsupported)
  - `CAS_PATH_FLAG="..."` — flag(s) that take a CAS directory path appended immediately after (empty if unsupported)

- [ ] **Step 1: Enumerate candidate flags on this toolchain**

```bash
cd Phase0
swift build --help 2>&1 | grep -iE "cach|cas" || true
swift build --help-hidden 2>&1 | grep -iE -B1 -A2 "cach|cas" || true
swiftc --help-hidden 2>&1 | grep -iE -B1 -A2 "cache-compile-job|cas-path|explicit-module" || true
```

- [ ] **Step 2: Try candidate invocations in order; first success wins**

Candidate A (SwiftPM-native, if Step 1 showed a caching option — use the exact spelling printed there):

```bash
CAS=$(mktemp -d); touch Sources/ProbeClient/*.swift
swift build --target ProbeClient <spelling-from-step-1> 2>&1 | tail -5
```

Candidate B (driver-level flags through SwiftPM):

```bash
CAS=$(mktemp -d); touch Sources/ProbeClient/*.swift
swift build --target ProbeClient \
  -Xswiftc -explicit-module-build \
  -Xswiftc -cache-compile-job \
  -Xswiftc -cas-path -Xswiftc "$CAS" 2>&1 | tail -20
```

**Success criterion (all three required):** (1) build exits 0; (2) a second identical build after `touch Sources/ProbeClient/*.swift` is measurably faster or its log shows cache-hit/replay markers; (3) the second build's log still contains PROBE lines (replayed) OR shows explicit "replaced/cached" job notices. **Failure criterion:** all candidates either error out, or the second build shows zero evidence of caching (same wall-clock, all-fresh pids).

- [ ] **Step 3: Write cas-flags.env and SPIKE.md**

On success (fill with the exact working spelling):

```bash
cat > cas-flags.env <<'EOF'
CAS_SUPPORTED=1
CAS_BUILD_FLAGS="-Xswiftc -explicit-module-build -Xswiftc -cache-compile-job"
CAS_PATH_FLAG="-Xswiftc -cas-path -Xswiftc"
EOF
```

On failure:

```bash
cat > cas-flags.env <<'EOF'
CAS_SUPPORTED=0
CAS_BUILD_FLAGS=""
CAS_PATH_FLAG=""
EOF
```

`SPIKE.md` records: toolchain version (`swift --version`), every candidate tried verbatim, its outcome (exit code, wall-clock of both builds, presence of PROBE lines / cache markers in run 2), and the conclusion. This file is the evidence base for the article's "how to enable" or "not yet available" section.

- [ ] **Step 4: Commit**

```bash
git add Phase0/cas-flags.env Phase0/SPIKE.md
git commit -m "spike: pin CAS compilation-caching flags for Swift 6.4 (#$ISSUE)"
```

**If `CAS_SUPPORTED=0`:** Tasks 2 and 3 are SKIPPED. Task 4 uses its "unsupported" variant. Note this in the task report.

---

### Task 2: `Scripts/cas-eval.sh` — matrix runner and analyzer

**Files:**
- Create: `Scripts/cas-eval.sh` (mode 755)

**Interfaces:**
- Consumes: `Phase0/cas-flags.env` (Task 1), PROBE line format (Global Constraints).
- Produces: `Scripts/cas-eval.sh` with env-var controls `CAS_EVAL_RUNS` (default 3) and `CAS_EVAL_CELLS` (comma list filter, e.g. `off-cold`); TSV rows `cell<TAB>run<TAB>wall_s<TAB>real<TAB>replayed<TAB>processes` on stdout plus a median summary table. Task 3 redirects this output to `Phase0/cas-eval-results.md`.

- [ ] **Step 1: Write the script**

```bash
#!/bin/bash
# CAS compilation-caching evaluation matrix (spec: docs/superpowers/specs/
# 2026-07-13-toolchain-cache-eval-design.md). Reuses the Phase-0 fixture and
# PROBE diagnostics. Cells: {off,on} x {cold, warmrepeat, incremental, noop}.
# "cold" = all fixture sources touched + fresh CAS dir (dependency artifacts
# in .build are kept: we measure macro/module work, not swift-syntax builds).
# Run on an idle machine; medians of CAS_EVAL_RUNS (default 3) are reported.
set -euo pipefail
cd "$(dirname "$0")/../Phase0"
source cas-flags.env
if [ "${CAS_SUPPORTED}" != "1" ]; then
  echo "CAS unsupported per SPIKE.md; nothing to run."; exit 0
fi

RUNS="${CAS_EVAL_RUNS:-3}"
ONLY="${CAS_EVAL_CELLS:-}"
LOG_DIR="${TMPDIR:-/tmp}/phase0-cas-eval"
rm -rf "$LOG_DIR"; mkdir -p "$LOG_DIR"
KNOWN_PIDS="$LOG_DIR/known-pids"; : > "$KNOWN_PIDS"
TSV="$LOG_DIR/cells.tsv"; : > "$TSV"
CAS_DIR="$LOG_DIR/cas"

run_build() { # $1=cache $2=log ; echoes wall seconds
  local flags=()
  if [ "$1" = "on" ]; then
    # shellcheck disable=SC2206  # intentional word-splitting of flag strings
    flags=($CAS_BUILD_FLAGS $CAS_PATH_FLAG "$CAS_DIR")
  fi
  local t0 t1
  t0=$(python3 -c 'import time; print(time.time())')
  swift build --target ProbeClient "${flags[@]+"${flags[@]}"}" > "$2" 2>&1
  t1=$(python3 -c 'import time; print(time.time())')
  python3 -c "print(f'{$t1-$t0:.2f}')"
}

prep() { # $1=scenario
  case "$1" in
    cold)        touch Sources/ProbeClient/*.swift; rm -rf "$CAS_DIR"; mkdir -p "$CAS_DIR" ;;
    warmrepeat)  touch Sources/ProbeClient/*.swift ;;              # keep CAS
    incremental) touch Sources/ProbeClient/Gen1.swift ;;
    noop)        : ;;
  esac
}

analyze() { # $1=log ; appends fresh pids to KNOWN_PIDS; echoes "real replayed procs"
  python3 - "$1" "$KNOWN_PIDS" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
known = set(open(sys.argv[2]).read().split())
probes = sorted(set(re.findall(
    r'PROBE kind=(\w+) pid=(\d+) seq=(\d+) active=(\d+) input=([0-9a-f]+)', text)))
pids = {p[1] for p in probes}
fresh_pids = pids - known
real = sum(1 for p in probes if p[1] in fresh_pids)
replayed = len(probes) - real
with open(sys.argv[2], 'a') as f:
    for p in sorted(fresh_pids): f.write(p + "\n")
print(real, replayed, len(fresh_pids))
PY
}

for cache in off on; do
  for scenario in cold warmrepeat incremental noop; do
    cell="$cache-$scenario"
    if [ -n "$ONLY" ] && ! grep -q "$cell" <<< "$ONLY"; then continue; fi
    for run in $(seq 1 "$RUNS"); do
      prep "$scenario"
      log="$LOG_DIR/$cell-$run.log"
      wall=$(run_build "$cache" "$log")
      read -r real replayed procs <<< "$(analyze "$log")"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cell" "$run" "$wall" "$real" "$replayed" "$procs" | tee -a "$TSV"
      if [ "$cell" = "off-cold" ] && { [ "$real" -ne 360 ] || [ "$procs" -ne 13 ]; }; then
        echo "REGRESSION: off-cold expected 360 expansions/13 processes, got $real/$procs" >&2
        exit 1
      fi
    done
  done
done

echo
echo "== medians =="
python3 - "$TSV" <<'PY'
import sys, statistics, collections
rows = [l.split('\t') for l in open(sys.argv[1]).read().splitlines() if l]
cells = collections.defaultdict(list)
for cell, run, wall, real, replayed, procs in rows:
    cells[cell].append((float(wall), int(real), int(replayed), int(procs)))
print(f"{'cell':<16}{'wall_s':>8}{'real':>7}{'replayed':>10}{'procs':>7}")
for cell, rs in cells.items():
    med = lambda i: statistics.median(r[i] for r in rs)
    print(f"{cell:<16}{med(0):>8.2f}{med(1):>7.0f}{med(2):>10.0f}{med(3):>7.0f}")
PY
echo "Logs in $LOG_DIR"
```

- [ ] **Step 2: Self-test — regression cell only**

```bash
chmod +x Scripts/cas-eval.sh
CAS_EVAL_CELLS=off-cold CAS_EVAL_RUNS=1 Scripts/cas-eval.sh
```

Expected: one TSV row `off-cold  1  <wall>  360  0  13` and exit 0. (First-ever run has an empty known-pids file, so all pids are fresh → replayed=0.)

- [ ] **Step 3: Self-test — unsupported path**

```bash
cd Phase0 && cp cas-flags.env cas-flags.env.bak
printf 'CAS_SUPPORTED=0\nCAS_BUILD_FLAGS=""\nCAS_PATH_FLAG=""\n' > cas-flags.env
../Scripts/cas-eval.sh   # expected: "CAS unsupported per SPIKE.md; nothing to run." exit 0
mv cas-flags.env.bak cas-flags.env && cd ..
```

- [ ] **Step 4: Commit**

```bash
git add Scripts/cas-eval.sh
git commit -m "feat: add CAS-eval matrix runner with expansion-vs-replay attribution (#$ISSUE)"
```

---

### Task 3: Run the matrix and record results

**Files:**
- Create: `Phase0/cas-eval-results.md`

**Interfaces:**
- Consumes: `Scripts/cas-eval.sh` (Task 2).
- Produces: `Phase0/cas-eval-results.md` — the sole data source for Task 4's numbers.

- [ ] **Step 1: Full matrix run on an idle machine**

```bash
Scripts/cas-eval.sh 2>&1 | tee /tmp/cas-eval-run.txt
```

Expected: 8 cells × 3 runs of TSV rows, then the median table; exit 0; the off-cold regression gate passes.

- [ ] **Step 2: Write cas-eval-results.md**

Structure (fill every value from the run output; no other sources):

```markdown
# CAS-eval matrix results
Toolchain: <swift --version line 1>. Date: <date>. Runs per cell: 3 (medians).

<median table verbatim from script output>

## Findings
1. Rebuild dedup: on-incremental real expansions = <N> vs off-incremental <M> → <eliminated | persists>.
2. Intra-build dedup: on-cold real expansions = <N> (off-cold 360) → compile-vs-emit-module duplication <persists | eliminated>.
3. Wall-clock: <per-scenario deltas, seconds and %>.
4. Replay behavior: replayed column <nonzero → diagnostics replayed | all zero → diagnostics not replayed; attribution fell back to expansion-count deltas (analyzer caveat)>.
```

- [ ] **Step 3: Commit**

```bash
git add Phase0/cas-eval-results.md
git commit -m "docs: record CAS-eval matrix results (#$ISSUE)"
```

---

### Task 4: DocC article — "Build performance for macro-heavy projects"

**Files:**
- Create: `Sources/MacroTemplateKit/Documentation.docc/BuildPerformance.md`

**Interfaces:**
- Consumes: `Phase0/cas-eval-results.md` (Task 3), `Phase0/SPIKE.md` (Task 1), issue #22's verdict comment (stage-cost table).

- [ ] **Step 1: Write the article**

Sections, in order (each numeric claim cites its source in prose, e.g. "measured in the CAS-eval matrix, cold cell"):

1. `# Build performance for macro-heavy projects` — one-paragraph framing: macros re-expand more than users think.
2. `## What macro expansion costs` — the stage table from issue #22 (56–524 µs per declaration; render 60–66%) and the process findings (expansion twice per clean build: compile + emit-module jobs; full re-expansion per incremental rebuild; one plugin process per frontend job).
3. `## Why MacroTemplateKit has no built-in cache` — one paragraph: measured Recoverable Time was negative in-process (issue #22, Gating Rule 1); link the issue.
4. **If `CAS_SUPPORTED=1`:** `## What compilation caching does about it` — the median table and Findings 1–4 from `cas-eval-results.md`, translated to prose. `## Enabling it` — the exact working invocation from SPIKE.md, for SwiftPM; note Xcode availability only if SPIKE.md verified it.
   **If `CAS_SUPPORTED=0`:** `## Toolchain caching status` — what was tried (from SPIKE.md), that it is not usable on this toolchain today, and what to watch for in release notes (CAS/compilation-caching flags becoming non-experimental).
5. `## Limitations` — cold builds still expand everything; editing the macro plugin invalidates everything; caching maturity varies by toolchain version.

- [ ] **Step 2: Validate**

```bash
swift build 2>&1 | tail -3                     # docc catalog addition must not break the build
grep -c "issue #22\|#22" Sources/MacroTemplateKit/Documentation.docc/BuildPerformance.md  # >= 2
```

- [ ] **Step 3: Commit**

```bash
git add Sources/MacroTemplateKit/Documentation.docc/BuildPerformance.md
git commit -m "docs: add build-performance article for macro-heavy projects (#$ISSUE)"
```

---

### Task 5: Close the loop on the tracking issue

**Files:** none (GitHub only)

- [ ] **Step 1: Summarize on the tracking issue**

```bash
gh issue comment $ISSUE --repo brunogama/MacroTemplateKit --body "<3-6 lines: spike outcome, matrix headline numbers (or unsupported short-circuit), link to Phase0/cas-eval-results.md and the DocC article path on branch eval/toolchain-cache>"
```

Do not close the issue — it closes when the branch merges.
