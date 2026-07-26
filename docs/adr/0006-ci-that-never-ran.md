# The CI was disabled, and every green signal was stale

**Status:** accepted — fixed

This repository has seven workflow files, a six-job PR gate, a `pr-ready`
aggregator that fails if any check fails, and a merge gate ([ADR 0005](0005-render-engine-merge-gate-v2.md))
whose clause 3 requires the benchmark equivalence check to pass. None of it had
run since 2026-07-14.

```console
$ gh api repos/brunogama/MacroTemplateKit/actions/permissions
{"enabled":false,"sha_pinning_required":false}
```

GitHub Actions was **disabled at the repository level**. Workflow files are
inert config when that flag is off — no run is queued, no failure is reported,
and `gh run list` keeps returning the last runs from before it was turned off,
which read like current state.

## What this explains

- The `v0.1.0` tag was pushed and no Release workflow fired. This was recorded
  at the time as "the tag is on the remote, Actions is enabled, but no run
  appeared" — the middle clause was an assumption, never checked, and wrong.
- An entire release cycle of work on `perf/render-engine` was never compiled by
  anything but a local machine.
- `Examples/` had 57 call sites across 24 files that had not compiled since
  `Renderer.render` began throwing. CI would not have caught this either, since
  they were not a build target, but nothing contradicted the belief that CI was
  watching.

## Three failures stacked, and each one hid the next

1. **Actions disabled.** Nothing ran.
2. **`on: push: branches: [main]`.** Even with Actions on, no push to a feature
   branch triggered anything. Work was only checked once a PR was opened, and
   this branch never had one.
3. **The equivalence check exited 0 on failure.** It printed `❌` and carried
   on, so even a run that executed it would have gone green on a mismatch. ADR
   0005 clause 3 gated merges on a check that reported nothing.

Fixing any one of these alone would have left the other two in place, still
producing a green tick that meant nothing. That is the property worth naming:
each layer's silence was indistinguishable from success.

## Decisions

- Actions is re-enabled, and `allowed_actions` is `all` (the workflows use
  `actions/checkout` and `softprops/action-gh-release`).
- CI triggers on `branches: ['**']`. A feature branch that compiles nowhere is
  not a feature branch anyone can review.
- The benchmark binary exits non-zero when equivalence fails. Verified in both
  directions rather than assumed — forcing the flag on exits 1, a clean run
  exits 0.
- The `Benchmarks` package is built by CI. It is a separate SwiftPM package and
  had no coverage at all, so the pipelines every published figure comes from
  could stop compiling unnoticed.
- Manifest parity is checked (`Scripts/check-manifests.sh`). SwiftPM reads
  `Package@swift-6.0.swift` and ignores `Package.swift` on any Swift 6
  toolchain, so the two had already drifted.

## Subsequent resolution

The CI repair deliberately left the formatter failure visible: at that point,
`swift-format lint --strict` reported **4196 violations on `main`**. The tree has
since been formatted separately with swift-format's default two-space style,
and the unchanged `format-check` command now passes across `Sources/` and
`Tests/`.

Keeping the check red until the code earned it back preserved the useful signal:
a known-red check is information, while a check deleted to make the board green
is not.
