#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> MacroTemplateKit bootstrap"
echo "Repo: $ROOT_DIR"
echo

if ! command -v brew >/dev/null 2>&1; then
	echo "error: Homebrew is required to install dev tools (brew)." >&2
	echo "Install: https://brew.sh" >&2
	exit 1
fi

echo "==> Installing/updating required tools"
brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
brew list swift-format >/dev/null 2>&1 || brew install swift-format
brew list danger/tap/danger-swift >/dev/null 2>&1 || brew install danger/tap/danger-swift

echo
echo "==> Tool versions"
swift --version
swiftlint version
swift-format --version
danger-swift --version

echo
echo "==> Done"
echo "Next: scripts/ci-local.sh"
