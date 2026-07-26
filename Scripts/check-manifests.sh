#!/usr/bin/env bash
# Verifies that every version-specific manifest contains the same package graph.
# Package@swift-6.2.swift may append target-scoped warning controls after the
# shared manifest; no other divergence is allowed.
set -euo pipefail

cd "$(dirname "$0")/.."

common_manifest="$(mktemp)"
manifest_60="$(mktemp)"
manifest_62="$(mktemp)"
cleanup() {
	rm -f "$common_manifest" "$manifest_60" "$manifest_62"
}
trap cleanup EXIT

tail -n +2 Package.swift >"$common_manifest"
tail -n +2 Package@swift-6.0.swift >"$manifest_60"
awk '
  /^\/\/ Swift 6\.2 scopes warning controls/ { exit }
  NR > 1 { print }
' Package@swift-6.2.swift >"$manifest_62"

if ! diff -u "$common_manifest" "$manifest_60"; then
	echo "::error::Package@swift-6.0.swift diverges from Package.swift below line 1."
	exit 1
fi

if ! diff -u "$common_manifest" "$manifest_62"; then
	echo "::error::Package@swift-6.2.swift diverges before its warning-control appendix."
	exit 1
fi

echo "Manifests are in sync."
