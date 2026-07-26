#!/usr/bin/env bash
# Builds the package with warnings treated as errors.
#
# Usage: Scripts/build.sh [swift build args...]
#   Scripts/build.sh                 # debug
#   Scripts/build.sh -c release      # release
#
# Swift 6.2+ selects Package@swift-6.2.swift, whose target-scoped warning
# controls avoid forwarding `-warnings-as-errors` into swift-syntax. Older
# toolchains select the 5.10/6.0 manifests and still use `-Xswiftc`; their
# default native build system accepts that flag combination. This avoids the
# deprecated explicit `--build-system native` override on current toolchains.
set -euo pipefail

cd "$(dirname "$0")/.."

if swift package dump-package 2>/dev/null | grep -q '"treatAllWarnings"'; then
	set -x
	Scripts/swift-package.sh build "$@"
else
	set -x
	Scripts/swift-package.sh build -Xswiftc -warnings-as-errors "$@"
fi
