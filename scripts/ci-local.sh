#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> MacroTemplateKit local CI"
echo

if ! command -v swift-format >/dev/null 2>&1; then
	echo "error: swift-format is not installed." >&2
	echo "Run: scripts/bootstrap.sh" >&2
	exit 1
fi

if ! command -v swiftlint >/dev/null 2>&1; then
	echo "error: swiftlint is not installed." >&2
	echo "Run: scripts/bootstrap.sh" >&2
	exit 1
fi

echo "==> Format (strict)"
swift-format lint --strict --recursive Sources/ Tests/

echo
echo "==> SwiftLint (strict)"
swiftlint lint --strict Sources/ Tests/

echo
echo "==> Build (warnings as errors)"
swift build -Xswiftc -warnings-as-errors

echo
echo "==> Test (parallel)"
swift test --parallel

echo
echo "==> OK"
