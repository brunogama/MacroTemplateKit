# Scripts

This directory contains small helper scripts to make local development match CI.

## bootstrap.sh

Installs required tooling via Homebrew:

```bash
Scripts/bootstrap.sh
```

## ci-local.sh

Runs the same checks enforced on pull requests:

```bash
Scripts/ci-local.sh
```

## Release automation

Release helpers are designed for the Changelog and Release workflows:

- `prepare-release.sh` calculates the next version and updates reviewed metadata.
- `build-release-xcframework.sh` builds, packages, and consumer-tests the pinned
  universal macOS artifact.
- `render-binary-manifest.sh` inserts the published asset checksum into the
  detached tag manifest.
- `check-release-metadata.sh` and `test-release-automation.sh` enforce metadata
  consistency in CI.
