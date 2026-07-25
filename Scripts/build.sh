#!/usr/bin/env bash
# Builds the package with warnings treated as errors.
#
# Usage: Scripts/build.sh [swift build args...]
#   Scripts/build.sh                 # debug
#   Scripts/build.sh -c release      # release
#
# Why this exists rather than a bare `swift build -Xswiftc -warnings-as-errors`:
#
# `-Xswiftc` applies to every target in the graph, dependencies included.
# swift-syntax compiles its version-shim targets with `-suppress-warnings`, and
# `-warnings-as-errors -suppress-warnings` is a hard driver error:
#
#     error: conflicting options '-warnings-as-errors' and '-suppress-warnings'
#
# Under the `native` (llbuild) build system this does not surface, which is why
# CI has been green while the same command fails locally: Swift 6.2 changed the
# default build system to `swiftbuild`, and CI pins Xcode 16.2 (Swift 6.0), where
# `native` is still the default. The failure is a toolchain-version difference,
# not a local misconfiguration and not a defect in this package's code.
#
# So: ask for `native` explicitly when the toolchain offers it, so local and CI
# agree. `native` is marked deprecated as of Swift 6.2. When it is removed this
# script is the single place to change, and the fix at that point is to stop
# using `-Xswiftc` and scope warnings-as-errors to our own targets with
# SE-0443's `.treatAllWarnings(as: .error)` in swiftSettings, which requires
# swift-tools-version 6.2 in the manifests.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_SYSTEM_ARGS=()
if swift package --help 2>&1 | grep -q "native  *- Native Build System"; then
  BUILD_SYSTEM_ARGS=(--build-system native)
fi

set -x
swift build "${BUILD_SYSTEM_ARGS[@]}" -Xswiftc -warnings-as-errors "$@"
